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

const projectId = 'sendaris-routine-status-rules-test';

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
  anonymousId,
}) {
  const reference = doc(
    db,
    `usuarios/${uid}/seguimientos/${anonymousId}`,
  );

  await setDoc(reference, {
    fechaCreacion: new Date('2026-09-06T12:00:00Z'),
    activo: true,
  });

  return reference;
}

async function createActiveRoutine({
  db,
  uid,
  anonymousId,
  routineId = 'rutina-test',
}) {
  const reference = doc(
    db,
    `usuarios/${uid}/seguimientos/${anonymousId}/rutinas/${routineId}`,
  );

  await setDoc(reference, {
    nombre: 'Preparar mochila',
    recurrencia: 'diaria',
    activa: true,
  });

  return reference;
}

function validRoutineStatusData({
  routineId = 'rutina-test',
  status = 'completada',
  observation = 'Actividad realizada.',
  eventDate = new Date('2026-09-06T00:00:00Z'),
  overrides = {},
  dataOverrides = {},
} = {}) {
  const data = {
    fecha: eventDate,
    idRutina: routineId,
    estado: status,
    ...dataOverrides,
  };

  if (observation !== null) {
    data.observacion = observation;
  }

  return {
    tipoRegistro: 'estadoRutina',
    fechaEvento: eventDate,
    fechaCreacion: new Date('2026-09-06T18:00:00Z'),
    fechaActualizacion: new Date('2026-09-06T18:00:00Z'),
    uidOperacion: 'usuario-a',
    datos: data,
    ...overrides,
  };
}

async function prepareActiveContext() {
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

  await createActiveRoutine({
    db,
    uid: 'usuario-a',
    anonymousId,
  });

  return {
    db,
    anonymousId,
  };
}

test(
  'el propietario puede registrar un estado válido para una rutina activa',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-1`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validRoutineStatusData(),
      ),
    );
  },
);

test(
  'se permiten exclusivamente los cuatro estados funcionales definidos',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const statuses = [
      'completada',
      'modificada',
      'interrumpida',
      'no_realizada',
    ];

    for (const [index, status] of statuses.entries()) {
      const reference = doc(
        db,
        `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-${index}`,
      );

      await assertSucceeds(
        setDoc(
          reference,
          validRoutineStatusData({
            status,
          }),
        ),
      );
    }
  },
);

test(
  'la observación es opcional',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-sin-observacion`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validRoutineStatusData({
          observation: null,
        }),
      ),
    );
  },
);

test(
  'se rechaza un estado fuera del catálogo',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-invalido`,
    );

    await assertFails(
      setDoc(
        reference,
        validRoutineStatusData({
          status: 'parcialmente_realizada',
        }),
      ),
    );
  },
);

test(
  'se rechaza un estado asociado a una rutina inexistente',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/rutina-inexistente`,
    );

    await assertFails(
      setDoc(
        reference,
        validRoutineStatusData({
          routineId: 'rutina-que-no-existe',
        }),
      ),
    );
  },
);

test(
  'se rechaza un estado asociado a una rutina desactivada',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const routineReference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-test`,
    );

    await updateDoc(
      routineReference,
      {
        activa: false,
      },
    );

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/rutina-inactiva`,
    );

    await assertFails(
      setDoc(
        reference,
        validRoutineStatusData(),
      ),
    );
  },
);

test(
  'otro usuario no puede registrar estados en un seguimiento ajeno',
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

    await createActiveRoutine({
      db: ownerDb,
      uid: 'usuario-a',
      anonymousId,
    });

    const otherDb = testEnv
      .authenticatedContext('usuario-b')
      .firestore();

    const reference = doc(
      otherDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-ajeno`,
    );

    await assertFails(
      setDoc(
        reference,
        validRoutineStatusData({
          overrides: {
            uidOperacion: 'usuario-b',
          },
        }),
      ),
    );
  },
);

test(
  'no se puede registrar un estado cuando el seguimiento está inactivo',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const profileReference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}`,
    );

    await updateDoc(
      profileReference,
      {
        activo: false,
      },
    );

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/seguimiento-inactivo`,
    );

    await assertFails(
      setDoc(
        reference,
        validRoutineStatusData(),
      ),
    );
  },
);

test(
  'se rechazan campos adicionales dentro de los datos del estado',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/campo-extra`,
    );

    await assertFails(
      setDoc(
        reference,
        validRoutineStatusData({
          dataOverrides: {
            nombreNino: 'Dato no permitido',
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza cuando fechaEvento no coincide con datos.fecha',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/fecha-inconsistente`,
    );

    await assertFails(
      setDoc(
        reference,
        validRoutineStatusData({
          eventDate:
              new Date('2026-09-06T00:00:00Z'),
          dataOverrides: {
            fecha:
                new Date('2026-09-05T00:00:00Z'),
          },
        }),
      ),
    );
  },
);

test(
  'el propietario puede consultar un estado de rutina persistido',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-readable`,
    );

    await setDoc(
      reference,
      validRoutineStatusData(),
    );

    const snapshot =
        await assertSucceeds(
      getDoc(reference),
    );

    assert.equal(
      snapshot.exists(),
      true,
    );

    assert.equal(
      snapshot.data().tipoRegistro,
      'estadoRutina',
    );

    assert.equal(
      snapshot.data().datos.estado,
      'completada',
    );
  },
);

test(
  'un estado de rutina no puede modificarse ni eliminarse',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-inmutable`,
    );

    await setDoc(
      reference,
      validRoutineStatusData(),
    );

    await assertFails(
      updateDoc(
        reference,
        {
          'datos.estado': 'modificada',
        },
      ),
    );

    await assertFails(
      deleteDoc(reference),
    );
  },
);