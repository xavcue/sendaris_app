import assert from 'node:assert/strict';
import test from 'node:test';

import {
  assessUnverifiedAccount,
  cleanupUnverifiedAccounts,
  DEFAULT_MAX_UNVERIFIED_AGE_HOURS,
  maskEmail,
  maskUid,
} from '../src/unverified_account_cleanup.mjs';

const NOW =
  new Date('2026-10-08T12:00:00.000Z');

function createPasswordUser({
  uid = 'uid-password-user-0001',
  email = 'usuario@example.com',
  emailVerified = false,
  ageHours = 24,
  providerData = [
    {
      providerId: 'password',
    },
  ],
  disabled = false,
  phoneNumber,
  tenantId,
  customClaims,
} = {}) {
  const creationTime = new Date(
    NOW.getTime() -
      ageHours * 60 * 60 * 1000,
  ).toISOString();

  return {
    uid,
    email,
    emailVerified,
    disabled,
    phoneNumber,
    tenantId,
    customClaims,
    providerData,
    metadata: {
      creationTime,
    },
  };
}

test(
  'una cuenta password no verificada con exactamente 24 horas es candidata',
  () => {
    const user = createPasswordUser({
      ageHours: 24,
    });

    const result = assessUnverifiedAccount(user, {
      now: NOW,
    });

    assert.equal(result.eligible, true);
    assert.equal(result.reason, 'eligible');
    assert.equal(result.ageHours, 24);
  },
);

test(
  'una cuenta no verificada con menos de 24 horas no es candidata',
  () => {
    const user = createPasswordUser({
      ageHours: 23.99,
    });

    const result = assessUnverifiedAccount(user, {
      now: NOW,
    });

    assert.equal(result.eligible, false);
    assert.equal(result.reason, 'too-young');
  },
);

test(
  'una cuenta verificada nunca es candidata aunque sea antigua',
  () => {
    const user = createPasswordUser({
      emailVerified: true,
      ageHours: 720,
    });

    const result = assessUnverifiedAccount(user, {
      now: NOW,
    });

    assert.equal(result.eligible, false);
    assert.equal(result.reason, 'email-verified');
  },
);

test(
  'una cuenta Google no verificada no es candidata',
  () => {
    const user = createPasswordUser({
      ageHours: 48,
      providerData: [
        {
          providerId: 'google.com',
        },
      ],
    });

    const result = assessUnverifiedAccount(user, {
      now: NOW,
    });

    assert.equal(result.eligible, false);
    assert.equal(
      result.reason,
      'not-password-only',
    );
  },
);

test(
  'una cuenta con password y Google vinculados no es candidata',
  () => {
    const user = createPasswordUser({
      ageHours: 48,
      providerData: [
        {
          providerId: 'password',
        },
        {
          providerId: 'google.com',
        },
      ],
    });

    const result = assessUnverifiedAccount(user, {
      now: NOW,
    });

    assert.equal(result.eligible, false);
    assert.equal(
      result.reason,
      'not-password-only',
    );
  },
);

test(
  'una cuenta deshabilitada se conserva por seguridad',
  () => {
    const user = createPasswordUser({
      ageHours: 48,
      disabled: true,
    });

    const result = assessUnverifiedAccount(user, {
      now: NOW,
    });

    assert.equal(result.eligible, false);
    assert.equal(result.reason, 'disabled-user');
  },
);

test(
  'una cuenta con custom claims se conserva por seguridad',
  () => {
    const user = createPasswordUser({
      ageHours: 48,
      customClaims: {
        admin: true,
      },
    });

    const result = assessUnverifiedAccount(user, {
      now: NOW,
    });

    assert.equal(result.eligible, false);

    assert.equal(
      result.reason,
      'custom-claims-present',
    );
  },
);

test(
  'dry-run encuentra candidatos pero nunca ejecuta deleteUser',
  async () => {
    const candidate = createPasswordUser({
      uid: 'candidate-user-00000001',
      email: 'candidato@example.com',
      ageHours: 30,
    });

    const verified = createPasswordUser({
      uid: 'verified-user-00000002',
      email: 'verificado@example.com',
      emailVerified: true,
      ageHours: 100,
    });

    const auth = new FakeAuth([
      [candidate],
      [verified],
    ]);

    const logs = [];

    const summary =
      await cleanupUnverifiedAccounts({
        auth,
        dryRun: true,
        now: NOW,
        logger: (message) => logs.push(message),
      });

    assert.equal(summary.scanned, 2);
    assert.equal(summary.candidates, 1);
    assert.equal(summary.deleted, 0);

    assert.deepEqual(auth.deletedUids, []);

    assert.equal(
      auth.listUsersCalls.length,
      2,
    );

    assert.equal(
      logs.some(
        (message) =>
          message.includes('[DRY-RUN]'),
      ),
      true,
    );
  },
);

test(
  'apply vuelve a consultar y no elimina si el correo fue verificado',
  async () => {
    const originalCandidate =
      createPasswordUser({
        uid: 'race-user-000000000001',
        email: 'race@example.com',
        ageHours: 30,
      });

    const refreshedUser = {
      ...originalCandidate,
      emailVerified: true,
    };

    const auth = new FakeAuth(
      [[originalCandidate]],
      {
        freshUsers: new Map([
          [
            originalCandidate.uid,
            refreshedUser,
          ],
        ]),
      },
    );

    const summary =
      await cleanupUnverifiedAccounts({
        auth,
        dryRun: false,
        now: NOW,
        logger: () => {},
      });

    assert.equal(summary.candidates, 1);
    assert.equal(summary.deleted, 0);

    assert.equal(
      summary.skippedAfterRecheck,
      1,
    );

    assert.deepEqual(auth.deletedUids, []);
  },
);

test(
  'apply elimina únicamente después de revalidar que sigue pendiente',
  async () => {
    const candidate = createPasswordUser({
      uid: 'delete-user-00000000001',
      email: 'eliminar@example.com',
      ageHours: 30,
    });

    const auth = new FakeAuth(
      [[candidate]],
      {
        freshUsers: new Map([
          [candidate.uid, candidate],
        ]),
      },
    );

    const summary =
      await cleanupUnverifiedAccounts({
        auth,
        dryRun: false,
        now: NOW,
        logger: () => {},
      });

    assert.equal(summary.candidates, 1);
    assert.equal(summary.deleted, 1);

    assert.equal(
      summary.skippedAfterRecheck,
      0,
    );

    assert.deepEqual(
      auth.deletedUids,
      [candidate.uid],
    );
  },
);

test(
  'la política predeterminada permanece fijada en 24 horas',
  () => {
    assert.equal(
      DEFAULT_MAX_UNVERIFIED_AGE_HOURS,
      24,
    );
  },
);

test(
  'los logs enmascaran correo y UID',
  () => {
    assert.equal(
      maskEmail('cuencafernando26@gmail.com'),
      'c***@gmail.com',
    );

    assert.equal(
      maskUid(
        '2pbHZtG8HWO4VYJbpY4xydg57ly2',
      ),
      '2pbH...7ly2',
    );
  },
);

class FakeAuth {
  constructor(
    pages,
    {
      freshUsers = new Map(),
    } = {},
  ) {
    this.pages = pages;
    this.freshUsers = freshUsers;

    this.deletedUids = [];
    this.listUsersCalls = [];
  }

  async listUsers(maxResults, pageToken) {
    this.listUsersCalls.push({
      maxResults,
      pageToken,
    });

    const pageIndex =
      pageToken == null
        ? 0
        : Number(pageToken);

    const users =
      this.pages[pageIndex] ?? [];

    const nextPageIndex =
      pageIndex + 1;

    const hasNextPage =
      nextPageIndex < this.pages.length;

    return {
      users,
      pageToken: hasNextPage
        ? String(nextPageIndex)
        : undefined,
    };
  }

  async getUser(uid) {
    if (this.freshUsers.has(uid)) {
      return this.freshUsers.get(uid);
    }

    for (const page of this.pages) {
      const user = page.find(
        (candidate) =>
          candidate.uid === uid,
      );

      if (user) {
        return user;
      }
    }

    const error =
      new Error('User not found.');

    error.code = 'auth/user-not-found';

    throw error;
  }

  async deleteUser(uid) {
    this.deletedUids.push(uid);
  }
}