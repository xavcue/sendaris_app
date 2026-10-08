import {
  applicationDefault,
  initializeApp,
} from 'firebase-admin/app';

import { getAuth } from 'firebase-admin/auth';

import {
  cleanupUnverifiedAccounts,
  DEFAULT_MAX_UNVERIFIED_AGE_HOURS,
} from './unverified_account_cleanup.mjs';

const PROJECT_ID =
  process.env.FIREBASE_PROJECT_ID ??
  'sendaris-app-xavcue';

const APPLY_CONFIRMATION =
  'DELETE_UNVERIFIED_AFTER_24H';

const applyMode =
  process.argv.includes('--apply');

if (
  applyMode &&
  process.env.SENDARIS_ALLOW_ACCOUNT_DELETION !==
    APPLY_CONFIRMATION
) {
  console.error(
    [
      'Ejecución bloqueada.',
      '',
      'Para habilitar una eliminación real se requiere:',
      '',
      `SENDARIS_ALLOW_ACCOUNT_DELETION=${APPLY_CONFIRMATION}`,
      '',
      'Sin esta confirmación el proceso no puede borrar cuentas.',
    ].join('\n'),
  );

  process.exitCode = 1;
} else {
  await run();
}

async function run() {
  const mode = applyMode
    ? 'APPLY'
    : 'DRY-RUN';

  console.log('Sendaris - limpieza de registros pendientes');
  console.log(`Proyecto: ${PROJECT_ID}`);
  console.log(`Modo: ${mode}`);

  console.log(
    'Antigüedad mínima: '
      + `${DEFAULT_MAX_UNVERIFIED_AGE_HOURS} horas`,
  );

  console.log('');

  try {
    const app = initializeApp({
      credential: applicationDefault(),
      projectId: PROJECT_ID,
    });

    const auth = getAuth(app);

    await cleanupUnverifiedAccounts({
      auth,
      dryRun: !applyMode,
      maxAgeHours:
        DEFAULT_MAX_UNVERIFIED_AGE_HOURS,
      logger: console,
    });
  } catch (error) {
    console.error(
      'No fue posible ejecutar la limpieza de cuentas.',
    );

    console.error(error);

    process.exitCode = 1;
  }
}