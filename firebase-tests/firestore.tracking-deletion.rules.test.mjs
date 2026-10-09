import fs from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  deleteDoc,
  doc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'sendaris-tracking-deletion-rules-test';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId,
    firestore: {
      host: '127.0.0.1',
      port: 8080,
      rules: fs.readFileSync('../firestore.rules', 'utf8'),
    },
  });
});

beforeEach(async () => {
  await testEnv.clearFirestore();
});

after(async () => {
  await testEnv.cleanup();
});

function trackingPath({
  uid = 'usuario-a',
  anonymousId = 'seguimiento-a',
} = {}) {
  return `usuarios/${uid}/seguimientos/${anonymousId}`;
}

function recordPath({
  uid = 'usuario-a',
  anonymousId = 'seguimiento-a',
  recordId = 'registro-1',
} = {}) {
  return `${trackingPath({
    uid,
    anonymousId,
  })}/registros/${recordId}`;
}

function routinePath({
  uid = 'usuario-a',
  anonymousId = 'seguimiento-a',
  routineId = 'rutina-1',
} = {}) {
  return `${trackingPath({
    uid,
    anonymousId,
  })}/rutinas/${routineId}`;
}

async function seedTrackingTree() {
  await testEnv.withSecurityRulesDisabled(
    async (context) => {
      const db = context.firestore();

      await setDoc(
        doc(
          db,
          trackingPath(),
        ),
        {
          fechaCreacion: new Date(
            '2026-09-20T12:00:00Z',
          ),
          activo: true,
          numeroSeguimiento: 1,
        },
      );

      await setDoc(
        doc(
          db,
          recordPath(),
        ),
        {
          tipoRegistro: 'conducta',
          fechaEvento: new Date(
            '2026-09-20T13:00:00Z',
          ),
          fechaCreacion: new Date(
            '2026-09-20T13:05:00Z',
          ),
          fechaActualizacion: new Date(
            '2026-09-20T13:05:00Z',
          ),
          uidOperacion: 'usuario-a',
          datos: {
            fecha: new Date(
              '2026-09-20T00:00:00Z',
            ),
            categoria: 'conducta_repetitiva',
          },
        },
      );

      await setDoc(
        doc(
          db,
          routinePath(),
        ),
        {
          nombre: 'Rutina ficticia',
        },
      );
    },
  );
}

test(
  'el propietario puede crear un seguimiento con número técnico',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    await assertSucceeds(
      setDoc(
        doc(
          db,
          trackingPath(),
        ),
        {
          fechaCreacion: new Date(
            '2026-09-20T12:00:00Z',
          ),
          activo: true,
          numeroSeguimiento: 1,
        },
      ),
    );
  },
);

test(
  'un seguimiento anterior puede recibir su número técnico',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const reference = doc(
      db,
      trackingPath(),
    );

    await assertSucceeds(
      setDoc(
        reference,
        {
          fechaCreacion: new Date(
            '2026-09-20T12:00:00Z',
          ),
          activo: true,
        },
      ),
    );

    await assertSucceeds(
      updateDoc(
        reference,
        {
          numeroSeguimiento: 1,
        },
      ),
    );
  },
);

test(
  'el número técnico no puede modificarse después de asignarse',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const reference = doc(
      db,
      trackingPath(),
    );

    await setDoc(
      reference,
      {
        fechaCreacion: new Date(
          '2026-09-20T12:00:00Z',
        ),
        activo: true,
        numeroSeguimiento: 1,
      },
    );

    await assertFails(
      updateDoc(
        reference,
        {
          numeroSeguimiento: 2,
        },
      ),
    );
  },
);

test(
  'se rechaza un número técnico igual a cero',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    await assertFails(
      setDoc(
        doc(
          db,
          trackingPath(),
        ),
        {
          fechaCreacion: new Date(
            '2026-09-20T12:00:00Z',
          ),
          activo: true,
          numeroSeguimiento: 0,
        },
      ),
    );
  },
);

test(
  'el propietario puede eliminar uno de sus registros',
  async () => {
    await seedTrackingTree();

    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    await assertSucceeds(
      deleteDoc(
        doc(
          db,
          recordPath(),
        ),
      ),
    );
  },
);

test(
  'otro usuario no puede eliminar un registro ajeno',
  async () => {
    await seedTrackingTree();

    const db = testEnv
      .authenticatedContext('usuario-b')
      .firestore();

    await assertFails(
      deleteDoc(
        doc(
          db,
          recordPath(),
        ),
      ),
    );
  },
);

test(
  'el propietario puede eliminar una de sus rutinas',
  async () => {
    await seedTrackingTree();

    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    await assertSucceeds(
      deleteDoc(
        doc(
          db,
          routinePath(),
        ),
      ),
    );
  },
);

test(
  'otro usuario no puede eliminar una rutina ajena',
  async () => {
    await seedTrackingTree();

    const db = testEnv
      .authenticatedContext('usuario-b')
      .firestore();

    await assertFails(
      deleteDoc(
        doc(
          db,
          routinePath(),
        ),
      ),
    );
  },
);

test(
  'el propietario puede eliminar su seguimiento',
  async () => {
    await seedTrackingTree();

    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    await assertSucceeds(
      deleteDoc(
        doc(
          db,
          trackingPath(),
        ),
      ),
    );
  },
);

test(
  'otro usuario no puede eliminar un seguimiento ajeno',
  async () => {
    await seedTrackingTree();

    const db = testEnv
      .authenticatedContext('usuario-b')
      .firestore();

    await assertFails(
      deleteDoc(
        doc(
          db,
          trackingPath(),
        ),
      ),
    );
  },
);

test(
  'un usuario no autenticado no puede eliminar información',
  async () => {
    await seedTrackingTree();

    const db = testEnv
      .unauthenticatedContext()
      .firestore();

    await assertFails(
      deleteDoc(
        doc(
          db,
          recordPath(),
        ),
      ),
    );

    await assertFails(
      deleteDoc(
        doc(
          db,
          routinePath(),
        ),
      ),
    );

    await assertFails(
      deleteDoc(
        doc(
          db,
          trackingPath(),
        ),
      ),
    );
  },
);
