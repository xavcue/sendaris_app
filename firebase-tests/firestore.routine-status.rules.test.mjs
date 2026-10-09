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

async function createRoutine({
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

async function prepareContext() {
  const db = testEnv.authenticatedContext('usuario-a').firestore();

  const anonymousId =
    '550e8400-e29b-41d4-a716-446655440000';

  await createActiveTrackingProfile({
    db,
    uid: 'usuario-a',
    anonymousId,
  });

  await createRoutine({
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
  'el propietario puede registrar un estado válido para una rutina existente',
  async () => {
    const { db, anonymousId } =
      await prepareContext();

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
      await prepareContext();

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
      await prepareContext();

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
      await prepareContext();

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
      await prepareContext();

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
  'se rechaza un estado cuando la rutina fue eliminada',
  async () => {
    const { db, anonymousId } =
      await prepareContext();

    const routineReference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-test`,
    );

    await assertSucceeds(
      deleteDoc(routineReference),
    );

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/rutina-eliminada`,
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
    const ownerDb = testEnv.authenticatedContext('usuario-a').firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db: ownerDb,
      uid: 'usuario-a',
      anonymousId,
    });

    await createRoutine({
      db: ownerDb,
      uid: 'usuario-a',
      anonymousId,
    });

    const otherDb = testEnv.authenticatedContext('usuario-b').firestore();

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
  'otro usuario no puede eliminar un estado de rutina ajeno',
  async () => {
    const ownerDb = testEnv.authenticatedContext('usuario-a').firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db: ownerDb,
      uid: 'usuario-a',
      anonymousId,
    });

    await createRoutine({
      db: ownerDb,
      uid: 'usuario-a',
      anonymousId,
    });

    const ownerReference = doc(
      ownerDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-protegido`,
    );

    await setDoc(
      ownerReference,
      validRoutineStatusData(),
    );

    const otherDb = testEnv.authenticatedContext('usuario-b').firestore();

    const otherReference = doc(
      otherDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-protegido`,
    );

    await assertFails(
      deleteDoc(otherReference),
    );
  },
);

test(
  'no se puede registrar un estado cuando el seguimiento está inactivo',
  async () => {
    const { db, anonymousId } =
      await prepareContext();

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
      await prepareContext();

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
      await prepareContext();

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
      await prepareContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-readable`,
    );

    await setDoc(
      reference,
      validRoutineStatusData(),
    );

    const snapshot = await assertSucceeds(
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
  'el propietario puede eliminar los estados asociados y después la rutina',
  async () => {
    const { db, anonymousId } =
      await prepareContext();

    const firstStatusReference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-cascada-1`,
    );

    const secondStatusReference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-cascada-2`,
    );

    const routineReference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/rutinas/rutina-test`,
    );

    await setDoc(
      firstStatusReference,
      validRoutineStatusData(),
    );

    await setDoc(
      secondStatusReference,
      validRoutineStatusData({
        status: 'modificada',
      }),
    );

    await assertSucceeds(
      deleteDoc(firstStatusReference),
    );

    await assertSucceeds(
      deleteDoc(secondStatusReference),
    );

    await assertSucceeds(
      deleteDoc(routineReference),
    );

    const firstSnapshot = await getDoc(
      firstStatusReference,
    );

    const secondSnapshot = await getDoc(
      secondStatusReference,
    );

    const routineSnapshot = await getDoc(
      routineReference,
    );

    assert.equal(
      firstSnapshot.exists(),
      false,
    );

    assert.equal(
      secondSnapshot.exists(),
      false,
    );

    assert.equal(
      routineSnapshot.exists(),
      false,
    );
  },
);

test(
  'el propietario puede actualizar el estado y la observación',
  async () => {
    const { db, anonymousId } =
      await prepareContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-editable`,
    );

    await setDoc(
      reference,
      validRoutineStatusData(),
    );

    await assertSucceeds(
      updateDoc(
        reference,
        {
          'datos.estado': 'modificada',
          'datos.observacion':
            'Actividad ajustada durante la edición.',
          fechaActualizacion:
            new Date('2026-09-06T19:00:00Z'),
        },
      ),
    );

    const snapshot = await getDoc(reference);

    assert.equal(
      snapshot.data().datos.estado,
      'modificada',
    );

    assert.equal(
      snapshot.data().datos.observacion,
      'Actividad ajustada durante la edición.',
    );

    assert.deepEqual(
      snapshot.data().fechaCreacion.toDate(),
      new Date('2026-09-06T18:00:00Z'),
    );
  },
);

test(
  'el propietario puede cambiar la fecha de un estado existente',
  async () => {
    const { db, anonymousId } =
      await prepareContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-fecha-editable`,
    );

    await setDoc(
      reference,
      validRoutineStatusData(),
    );

    const newDate =
      new Date('2026-09-07T00:00:00Z');

    await assertSucceeds(
      updateDoc(
        reference,
        {
          fechaEvento: newDate,
          'datos.fecha': newDate,
          fechaActualizacion:
            new Date('2026-09-06T19:00:00Z'),
        },
      ),
    );

    const snapshot = await getDoc(reference);

    assert.deepEqual(
      snapshot.data().fechaEvento.toDate(),
      newDate,
    );

    assert.deepEqual(
      snapshot.data().datos.fecha.toDate(),
      newDate,
    );
  },
);

test(
  'el propietario puede asociar el estado a otra rutina existente',
  async () => {
    const { db, anonymousId } =
      await prepareContext();

    await createRoutine({
      db,
      uid: 'usuario-a',
      anonymousId,
      routineId: 'rutina-secundaria',
    });

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-rutina-editable`,
    );

    await setDoc(
      reference,
      validRoutineStatusData(),
    );

    await assertSucceeds(
      updateDoc(
        reference,
        {
          'datos.idRutina': 'rutina-secundaria',
          fechaActualizacion:
            new Date('2026-09-06T19:00:00Z'),
        },
      ),
    );

    const snapshot = await getDoc(reference);

    assert.equal(
      snapshot.data().datos.idRutina,
      'rutina-secundaria',
    );
  },
);

test(
  'se rechaza actualizar un estado hacia una rutina inexistente',
  async () => {
    const { db, anonymousId } =
      await prepareContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-rutina-inexistente-update`,
    );

    await setDoc(
      reference,
      validRoutineStatusData(),
    );

    await assertFails(
      updateDoc(
        reference,
        {
          'datos.idRutina': 'rutina-que-no-existe',
          fechaActualizacion:
            new Date('2026-09-06T19:00:00Z'),
        },
      ),
    );
  },
);

test(
  'se rechaza modificar la fecha de creación al actualizar',
  async () => {
    const { db, anonymousId } =
      await prepareContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-creacion-protegida`,
    );

    await setDoc(
      reference,
      validRoutineStatusData(),
    );

    await assertFails(
      updateDoc(
        reference,
        {
          fechaCreacion:
            new Date('2026-09-06T18:30:00Z'),
          fechaActualizacion:
            new Date('2026-09-06T19:00:00Z'),
        },
      ),
    );
  },
);

test(
  'se rechaza actualizar sin avanzar fechaActualizacion',
  async () => {
    const { db, anonymousId } =
      await prepareContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-sin-nueva-actualizacion`,
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
  },
);

test(
  'se rechaza un estado fuera del catálogo al actualizar',
  async () => {
    const { db, anonymousId } =
      await prepareContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-catalogo-update`,
    );

    await setDoc(
      reference,
      validRoutineStatusData(),
    );

    await assertFails(
      updateDoc(
        reference,
        {
          'datos.estado': 'parcialmente_realizada',
          fechaActualizacion:
            new Date('2026-09-06T19:00:00Z'),
        },
      ),
    );
  },
);

test(
  'se rechaza una fecha inconsistente al actualizar',
  async () => {
    const { db, anonymousId } =
      await prepareContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-fecha-inconsistente-update`,
    );

    await setDoc(
      reference,
      validRoutineStatusData(),
    );

    await assertFails(
      updateDoc(
        reference,
        {
          fechaEvento:
            new Date('2026-09-07T00:00:00Z'),
          fechaActualizacion:
            new Date('2026-09-06T19:00:00Z'),
        },
      ),
    );
  },
);

test(
  'no se puede actualizar un estado cuando el seguimiento está inactivo',
  async () => {
    const { db, anonymousId } =
      await prepareContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-seguimiento-inactivo-update`,
    );

    await setDoc(
      reference,
      validRoutineStatusData(),
    );

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

    await assertFails(
      updateDoc(
        reference,
        {
          'datos.estado': 'modificada',
          fechaActualizacion:
            new Date('2026-09-06T19:00:00Z'),
        },
      ),
    );
  },
);

test(
  'otro usuario no puede actualizar un estado de rutina ajeno',
  async () => {
    const ownerDb = testEnv.authenticatedContext('usuario-a').firestore();

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db: ownerDb,
      uid: 'usuario-a',
      anonymousId,
    });

    await createRoutine({
      db: ownerDb,
      uid: 'usuario-a',
      anonymousId,
    });

    const ownerReference = doc(
      ownerDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-update-protegido`,
    );

    await setDoc(
      ownerReference,
      validRoutineStatusData(),
    );

    const otherDb = testEnv.authenticatedContext('usuario-b').firestore();

    const otherReference = doc(
      otherDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-update-protegido`,
    );

    await assertFails(
      updateDoc(
        otherReference,
        {
          'datos.estado': 'modificada',
          fechaActualizacion:
            new Date('2026-09-06T19:00:00Z'),
        },
      ),
    );
  },
);

test(
  'el propietario puede eliminar un estado de rutina después de editarlo',
  async () => {
    const { db, anonymousId } =
      await prepareContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/estado-editado-eliminable`,
    );

    await setDoc(
      reference,
      validRoutineStatusData(),
    );

    await assertSucceeds(
      updateDoc(
        reference,
        {
          'datos.estado': 'modificada',
          fechaActualizacion:
            new Date('2026-09-06T19:00:00Z'),
        },
      ),
    );

    await assertSucceeds(
      deleteDoc(reference),
    );

    const snapshot = await getDoc(reference);

    assert.equal(
      snapshot.exists(),
      false,
    );
  },
);
