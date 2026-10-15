import assert from 'node:assert/strict';
import fs from 'node:fs';

import {
  after,
  before,
  beforeEach,
  test,
} from 'node:test';

import {
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  collection,
  deleteDoc,
  doc,
  onSnapshot,
  orderBy,
  query,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'demo-sendaris-observation-rules';

const timeoutMs = 15000;

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: fs.readFileSync(
        new URL('../firestore.rules', import.meta.url),
        'utf8',
      ),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv?.cleanup();
});

function verifiedDb(uid) {
  return testEnv.authenticatedContext(uid, {
    email: `${uid}@example.test`,
    email_verified: true,
  }).firestore();
}

function profilesQuery(db) {
  return query(
    collection(
      db,
      'usuarios/usuario-a/seguimientos',
    ),
    orderBy('fechaCreacion'),
  );
}

function observeConfirmedProfiles(db) {
  const received = [];

  let cursor = 0;
  let pending = null;
  let failure = null;

  function flush() {
    if (pending === null) {
      return;
    }

    if (failure !== null) {
      const waiter = pending;
      pending = null;

      clearTimeout(waiter.timer);
      waiter.reject(failure);
      return;
    }

    while (cursor < received.length) {
      const current = received[cursor++];

      if (pending.predicate(current)) {
        const waiter = pending;
        pending = null;

        clearTimeout(waiter.timer);
        waiter.resolve(current);
        return;
      }
    }
  }

  const unsubscribe = onSnapshot(
    profilesQuery(db),
    { includeMetadataChanges: true },
    (snapshot) => {
      if (
        snapshot.metadata.fromCache ||
        snapshot.metadata.hasPendingWrites
      ) {
        return;
      }

      received.push(
        snapshot.docs.map((document) => ({
          id: document.id,
          activo: document.data().activo,
        })),
      );

      flush();
    },
    (error) => {
      failure = error;
      flush();
    },
  );

  return {
    waitFor(predicate) {
      if (pending !== null) {
        throw new Error(
          'Ya existe una espera de observacion pendiente.',
        );
      }

      if (failure !== null) {
        return Promise.reject(failure);
      }

      return new Promise((resolve, reject) => {
        const waiter = {
          predicate,
          resolve,
          reject,
          timer: null,
        };

        waiter.timer = setTimeout(() => {
          if (pending === waiter) {
            pending = null;
          }

          reject(
            new Error(
              'Tiempo agotado esperando una instantanea confirmada.',
            ),
          );
        }, timeoutMs);

        pending = waiter;
        flush();
      });
    },

    close() {
      unsubscribe();

      if (pending !== null) {
        clearTimeout(pending.timer);
        pending = null;
      }
    },
  };
}

function expectObservationDenied(db) {
  return new Promise((resolve, reject) => {
    let completed = false;
    let unsubscribe = () => {};

    function finish(error = null) {
      if (completed) {
        return;
      }

      completed = true;
      clearTimeout(timer);
      unsubscribe();

      if (error !== null) {
        reject(error);
      } else {
        resolve();
      }
    }

    const timer = setTimeout(() => {
      finish(
        new Error(
          'No se recibio el rechazo esperado de Firestore.',
        ),
      );
    }, timeoutMs);

    unsubscribe = onSnapshot(
      profilesQuery(db),
      { includeMetadataChanges: true },
      (snapshot) => {
        if (snapshot.metadata.fromCache) {
          return;
        }

        finish(
          new Error(
            'Firestore permitio una observacion no autorizada.',
          ),
        );
      },
      (error) => {
        if (error.code === 'permission-denied') {
          finish();
        } else {
          finish(error);
        }
      },
    );
  });
}

test(
  'el propietario observa altas cambios y eliminaciones confirmadas',
  async () => {
    const db = verifiedDb('usuario-a');

    const reference = doc(
      db,
      'usuarios/usuario-a/seguimientos/perfil-prueba',
    );

    const observer = observeConfirmedProfiles(db);

    try {
      assert.deepEqual(
        await observer.waitFor(
          (profiles) => profiles.length === 0,
        ),
        [],
      );

      await setDoc(reference, {
        fechaCreacion: new Date(
          '2026-10-01T12:00:00Z',
        ),
        activo: true,
        numeroSeguimiento: 1,
      });

      assert.deepEqual(
        await observer.waitFor(
          (profiles) =>
            profiles.length === 1 &&
            profiles[0].activo === true,
        ),
        [
          {
            id: 'perfil-prueba',
            activo: true,
          },
        ],
      );

      await updateDoc(reference, {
        activo: false,
      });

      assert.deepEqual(
        await observer.waitFor(
          (profiles) =>
            profiles.length === 1 &&
            profiles[0].activo === false,
        ),
        [
          {
            id: 'perfil-prueba',
            activo: false,
          },
        ],
      );

      await deleteDoc(reference);

      assert.deepEqual(
        await observer.waitFor(
          (profiles) => profiles.length === 0,
        ),
        [],
      );
    } finally {
      observer.close();
    }
  },
);

test(
  'otro usuario no puede observar seguimientos ajenos',
  async () => {
    const db = verifiedDb('usuario-b');

    await expectObservationDenied(db);
  },
);

test(
  'una cuenta con correo no verificado no puede observar',
  async () => {
    const db = testEnv.authenticatedContext(
      'usuario-a',
      {
        email: 'usuario-a@example.test',
        email_verified: false,
      },
    ).firestore();

    await expectObservationDenied(db);
  },
);

test(
  'una sesion no autenticada no puede observar seguimientos',
  async () => {
    const db = testEnv.unauthenticatedContext().firestore();

    await expectObservationDenied(db);
  },
);