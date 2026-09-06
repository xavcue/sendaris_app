import fs from 'node:fs';
import { after, before, beforeEach, test } from 'node:test';
import assert from 'node:assert/strict';

import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

import {
  deleteDoc,
  doc,
  getDoc,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId = 'sendaris-routine-rules-test';

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

async function createActiveTrackingProfile({
  db,
  uid,
  anonymousId = '550e8400-e29b-41d4-a716-446655440000',
}) {
  const reference = doc(
    db,
    `usuarios/${uid}/seguimientos/${anonymousId}`,
  );

  await setDoc(reference, {
    fechaCreacion: new Date('2026-09-05T12:00:00Z'),
    activo: true,
  });

  return reference;
}

function validRoutineData({
  overrides = {},
} = {}) {
  return {
    nombre: 'Preparar mochila',
    descripcion: 'Revisar los materiales necesarios.',
    horaProgramada: '20:00',
    recurrencia: 'diaria',
    activa: true,
    ...overrides,
  };
}

test(
  'el propietario puede crear una rutina válida en un seguimiento activo',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db,
      uid: 'usuario-a',
      anonymousId,
    });

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-1`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validRoutineData(),
      ),
    );
  },
);

test(
  'una rutina puede omitir todos los campos opcionales',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db,
      uid: 'usuario-a',
      anonymousId,
    });

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-2`,
    );

    await assertSucceeds(
      setDoc(reference, {
        nombre: 'Cena',
        activa: true,
      }),
    );
  },
);

test(
  'otro usuario no puede crear rutinas en un seguimiento ajeno',
  async () => {
    const ownerDb = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db: ownerDb,
      uid: 'usuario-a',
      anonymousId,
    });

    const otherDb = testEnv
      .authenticatedContext('usuario-b')
      .firestore();

    const reference = doc(
      otherDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-3`,
    );

    await assertFails(
      setDoc(
        reference,
        validRoutineData(),
      ),
    );
  },
);

test(
  'no se puede crear una rutina sin seguimiento existente',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const reference = doc(
      db,
      'usuarios/usuario-a/seguimientos/seguimiento-inexistente/rutinas/rutina-4',
    );

    await assertFails(
      setDoc(
        reference,
        validRoutineData(),
      ),
    );
  },
);

test(
  'no se puede crear una rutina en un seguimiento inactivo',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    const profileReference =
      await createActiveTrackingProfile({
        db,
        uid: 'usuario-a',
        anonymousId,
      });

    await updateDoc(
      profileReference,
      {
        activo: false,
      },
    );

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-5`,
    );

    await assertFails(
      setDoc(
        reference,
        validRoutineData(),
      ),
    );
  },
);

test(
  'se rechaza una recurrencia fuera del catálogo',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db,
      uid: 'usuario-a',
      anonymousId,
    });

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-6`,
    );

    await assertFails(
      setDoc(
        reference,
        validRoutineData({
          overrides: {
            recurrencia: 'cada_dos_dias',
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza una hora programada inválida',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db,
      uid: 'usuario-a',
      anonymousId,
    });

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-7`,
    );

    await assertFails(
      setDoc(
        reference,
        validRoutineData({
          overrides: {
            horaProgramada: '27:80',
          },
        }),
      ),
    );
  },
);

test(
  'se rechazan campos adicionales no permitidos en una rutina',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db,
      uid: 'usuario-a',
      anonymousId,
    });

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-8`,
    );

    await assertFails(
      setDoc(
        reference,
        validRoutineData({
          overrides: {
            nombreNino: 'Dato prohibido',
          },
        }),
      ),
    );
  },
);

test(
  'el propietario puede consultar y modificar una rutina existente',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db,
      uid: 'usuario-a',
      anonymousId,
    });

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-9`,
    );

    await setDoc(
      reference,
      validRoutineData(),
    );

    await assertSucceeds(
      getDoc(reference),
    );

    await assertSucceeds(
      updateDoc(
        reference,
        {
          nombre: 'Preparar mochila escolar',
          horaProgramada: '19:30',
          recurrencia: 'semanal',
        },
      ),
    );

    const snapshot = await getDoc(reference);

    assert.equal(
      snapshot.data().nombre,
      'Preparar mochila escolar',
    );

    assert.equal(
      snapshot.data().horaProgramada,
      '19:30',
    );

    assert.equal(
      snapshot.data().recurrencia,
      'semanal',
    );
  },
);

test(
  'el propietario puede desactivar una rutina sin eliminarla',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db,
      uid: 'usuario-a',
      anonymousId,
    });

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-10`,
    );

    await setDoc(
      reference,
      validRoutineData(),
    );

    await assertSucceeds(
      updateDoc(
        reference,
        {
          activa: false,
        },
      ),
    );

    const snapshot = await assertSucceeds(
      getDoc(reference),
    );

    assert.equal(
      snapshot.exists(),
      true,
    );

    assert.equal(
      snapshot.data().activa,
      false,
    );
  },
);

test(
  'una rutina desactivada no puede reactivarse sin una historia que lo autorice',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db,
      uid: 'usuario-a',
      anonymousId,
    });

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-11`,
    );

    await setDoc(
      reference,
      validRoutineData(),
    );

    await updateDoc(
      reference,
      {
        activa: false,
      },
    );

    await assertFails(
      updateDoc(
        reference,
        {
          activa: true,
        },
      ),
    );
  },
);

test(
  'una rutina no puede eliminarse físicamente',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db,
      uid: 'usuario-a',
      anonymousId,
    });

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-12`,
    );

    await setDoc(
      reference,
      validRoutineData(),
    );

    await assertFails(
      deleteDoc(reference),
    );
  },
);

test(
  'otro usuario no puede leer ni modificar una rutina ajena',
  async () => {
    const ownerDb = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db: ownerDb,
      uid: 'usuario-a',
      anonymousId,
    });

    const ownerReference = doc(
      ownerDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-13`,
    );

    await setDoc(
      ownerReference,
      validRoutineData(),
    );

    const otherDb = testEnv
      .authenticatedContext('usuario-b')
      .firestore();

    const otherReference = doc(
      otherDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-13`,
    );

    await assertFails(
      getDoc(otherReference),
    );

    await assertFails(
      updateDoc(
        otherReference,
        {
          nombre: 'Cambio no autorizado',
        },
      ),
    );
  },
);