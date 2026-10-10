export const DEFAULT_MAX_UNVERIFIED_AGE_HOURS = 24;

const MILLISECONDS_PER_HOUR = 60 * 60 * 1000;
const MAX_USERS_PER_PAGE = 1000;

export function assessUnverifiedAccount(
  user,
  {
    now = new Date(),
    maxAgeHours = DEFAULT_MAX_UNVERIFIED_AGE_HOURS,
  } = {},
) {
  const nowMilliseconds = normalizeNow(now);

  if (!user || typeof user !== 'object') {
    return ineligible('invalid-user');
  }

  if (typeof user.uid !== 'string' || user.uid.trim().length === 0) {
    return ineligible('missing-uid');
  }

  if (typeof user.email !== 'string' || user.email.trim().length === 0) {
    return ineligible('missing-email');
  }

  if (user.emailVerified !== false) {
    return ineligible('email-verified');
  }

  if (user.disabled === true) {
    return ineligible('disabled-user');
  }

  if (
    typeof user.phoneNumber === 'string' &&
    user.phoneNumber.trim().length > 0
  ) {
    return ineligible('phone-number-present');
  }

  if (user.tenantId != null) {
    return ineligible('tenant-user');
  }

  if (
    user.customClaims &&
    typeof user.customClaims === 'object' &&
    Object.keys(user.customClaims).length > 0
  ) {
    return ineligible('custom-claims-present');
  }

  if (!isPasswordOnlyAccount(user)) {
    return ineligible('not-password-only');
  }

  const creationMilliseconds = parseCreationTime(user);

  if (creationMilliseconds == null) {
    return ineligible('invalid-creation-time');
  }

  const thresholdMilliseconds =
    maxAgeHours * MILLISECONDS_PER_HOUR;

  const ageMilliseconds =
    nowMilliseconds - creationMilliseconds;

  if (ageMilliseconds < thresholdMilliseconds) {
    return {
      eligible: false,
      reason: 'too-young',
      ageHours: ageMilliseconds / MILLISECONDS_PER_HOUR,
    };
  }

  return {
    eligible: true,
    reason: 'eligible',
    ageHours: ageMilliseconds / MILLISECONDS_PER_HOUR,
  };
}

export async function cleanupUnverifiedAccounts({
  auth,
  dryRun = true,
  now = new Date(),
  maxAgeHours = DEFAULT_MAX_UNVERIFIED_AGE_HOURS,
  logger = console,
}) {
  if (!auth) {
    throw new TypeError('Firebase Auth es obligatorio.');
  }

  const normalizedNow = new Date(normalizeNow(now));

  const summary = {
    dryRun,
    scanned: 0,
    candidates: 0,
    deleted: 0,
    skippedAfterRecheck: 0,
  };

  let pageToken;

  do {
    const page = await auth.listUsers(
      MAX_USERS_PER_PAGE,
      pageToken,
    );

    const users = Array.isArray(page.users)
      ? page.users
      : [];

    summary.scanned += users.length;

    for (const user of users) {
      const assessment = assessUnverifiedAccount(user, {
        now: normalizedNow,
        maxAgeHours,
      });

      if (!assessment.eligible) {
        continue;
      }

      summary.candidates++;

      logCandidate({
        logger,
        user,
        assessment,
        dryRun,
      });

      if (dryRun) {
        continue;
      }

      const freshUser = await safelyGetUser(
        auth,
        user.uid,
      );

      if (freshUser == null) {
        summary.skippedAfterRecheck++;

        writeLog(
          logger,
          `[SKIP] ${maskUid(user.uid)} ya no existe.`,
        );

        continue;
      }

      const freshAssessment = assessUnverifiedAccount(
        freshUser,
        {
          now: normalizedNow,
          maxAgeHours,
        },
      );

      if (!freshAssessment.eligible) {
        summary.skippedAfterRecheck++;

        writeLog(
          logger,
          `[SKIP] ${maskUid(user.uid)} cambió de estado `
            + `antes de la eliminación `
            + `(${freshAssessment.reason}).`,
        );

        continue;
      }

      try {
        await auth.deleteUser(user.uid);

        summary.deleted++;

        writeLog(
          logger,
          `[DELETE] ${maskUid(user.uid)} eliminado.`,
        );
      } catch (error) {
        if (isUserNotFoundError(error)) {
          summary.skippedAfterRecheck++;

          writeLog(
            logger,
            `[SKIP] ${maskUid(user.uid)} ya no existía `
              + 'al intentar eliminarlo.',
          );

          continue;
        }

        throw error;
      }
    }

    pageToken = page.pageToken;
  } while (pageToken);

  writeSummary(logger, summary);

  return summary;
}

function isPasswordOnlyAccount(user) {
  if (!Array.isArray(user.providerData)) {
    return false;
  }

  const providerIds = new Set(
    user.providerData
      .map((provider) => provider?.providerId)
      .filter(
        (providerId) =>
          typeof providerId === 'string' &&
          providerId.length > 0,
      ),
  );

  return (
    providerIds.size === 1 &&
    providerIds.has('password')
  );
}

function parseCreationTime(user) {
  const creationTime = user?.metadata?.creationTime;

  if (
    typeof creationTime !== 'string' ||
    creationTime.trim().length === 0
  ) {
    return null;
  }

  const milliseconds = Date.parse(creationTime);

  return Number.isFinite(milliseconds)
    ? milliseconds
    : null;
}

function normalizeNow(now) {
  const milliseconds =
    now instanceof Date
      ? now.getTime()
      : new Date(now).getTime();

  if (!Number.isFinite(milliseconds)) {
    throw new TypeError(
      'La fecha actual proporcionada no es válida.',
    );
  }

  return milliseconds;
}

function ineligible(reason) {
  return {
    eligible: false,
    reason,
    ageHours: null,
  };
}

async function safelyGetUser(auth, uid) {
  try {
    return await auth.getUser(uid);
  } catch (error) {
    if (isUserNotFoundError(error)) {
      return null;
    }

    throw error;
  }
}

function isUserNotFoundError(error) {
  return (
    error?.code === 'auth/user-not-found' ||
    error?.errorInfo?.code === 'auth/user-not-found'
  );
}

function logCandidate({
  logger,
  user,
  assessment,
  dryRun,
}) {
  const mode = dryRun
    ? 'DRY-RUN'
    : 'CANDIDATE';

  const ageHours = assessment.ageHours.toFixed(2);

  writeLog(
    logger,
    `[${mode}] ${maskEmail(user.email)} | `
      + `${maskUid(user.uid)} | `
      + `${ageHours} h sin verificar`,
  );
}

function writeSummary(logger, summary) {
  writeLog(
    logger,
    [
      '',
      'Resumen de limpieza:',
      `  Modo: ${summary.dryRun ? 'DRY-RUN' : 'APPLY'}`,
      `  Revisados: ${summary.scanned}`,
      `  Candidatos: ${summary.candidates}`,
      `  Eliminados: ${summary.deleted}`,
      `  Omitidos tras revalidación: ${summary.skippedAfterRecheck}`,
    ].join('\n'),
  );
}

function writeLog(logger, message) {
  if (typeof logger === 'function') {
    logger(message);

    return;
  }

  if (
    logger &&
    typeof logger.log === 'function'
  ) {
    logger.log(message);
  }
}

export function maskEmail(email) {
  if (
    typeof email !== 'string' ||
    !email.includes('@')
  ) {
    return '***';
  }

  const [localPart, domain] = email.split('@');

  const firstCharacter =
    localPart.length > 0
      ? localPart[0]
      : '*';

  return `${firstCharacter}***@${domain}`;
}

export function maskUid(uid) {
  if (
    typeof uid !== 'string' ||
    uid.length < 9
  ) {
    return '***';
  }

  return `${uid.slice(0, 4)}...${uid.slice(-4)}`;
}