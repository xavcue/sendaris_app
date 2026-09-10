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

const projectId = 'sendaris-sleep-rules-test';

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
    fechaCreacion: new Date('2026-09-09T12:00:00Z'),
    activo: true,
  });

  return reference;
}

function validSleepData({
  startTime = '22:00',
  endTime = '06:00',
  durationMinutes = 480,
  observation,
  eventDate = new Date('2026-09-09T22:00:00Z'),
  sleepDate = new Date('2026-09-09T00:00:00Z'),
  overrides = {},
  dataOverrides = {},
} = {}) {
  const sleepData = {
    fecha: sleepDate,
    horaInicio: startTime,
    horaFin: endTime,
    duracionMin: durationMinutes,
    ...dataOverrides,
  };

  if (observation !== undefined) {
    sleepData.observacion = observation;
  }

  return {
    tipoRegistro: 'sueno',
    fechaEvento: eventDate,
    fechaCreacion: new Date('2026-09-10T10:00:00Z'),
    fechaActualizacion: new Date('2026-09-10T10:00:00Z'),
    uidOperacion: 'usuario-a',
    datos: sleepData,
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

  return {
    db,
    anonymousId,
  };
}

test(
  'el propietario puede registrar un sueño válido',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/sueno-1`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validSleepData(),
      ),
    );
  },
);

test(
  'permite un registro de sueño con observación descriptiva',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/sueno-observacion`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validSleepData({
          observation:
            'Se registró un despertar durante la mañana.',
        }),
      ),
    );
  },
);

test(
  'se rechaza una hora de inicio inválida',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/inicio-invalido`,
    );

    await assertFails(
      setDoc(
        reference,
        validSleepData({
          startTime: '25:00',
        }),
      ),
    );
  },
);

test(
  'se rechaza una hora de finalización inválida',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/fin-invalido`,
    );

    await assertFails(
      setDoc(
        reference,
        validSleepData({
          endTime: '06:90',
        }),
      ),
    );
  },
);

test(
  'se rechazan horas de inicio y finalización iguales',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/horas-iguales`,
    );

    await assertFails(
      setDoc(
        reference,
        validSleepData({
          startTime: '22:00',
          endTime: '22:00',
          durationMinutes: 1,
        }),
      ),
    );
  },
);

test(
  'se rechaza una duración igual o menor que cero',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/duracion-cero`,
    );

    await assertFails(
      setDoc(
        reference,
        validSleepData({
          durationMinutes: 0,
        }),
      ),
    );
  },
);

test(
  'se rechaza una duración de 24 horas o más',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/duracion-excesiva`,
    );

    await assertFails(
      setDoc(
        reference,
        validSleepData({
          durationMinutes: 1440,
        }),
      ),
    );
  },
);

test(
  'se rechaza una observación vacía cuando está presente',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/observacion-vacia`,
    );

    await assertFails(
      setDoc(
        reference,
        validSleepData({
          observation: '',
        }),
      ),
    );
  },
);

test(
  'se rechazan campos adicionales dentro de datos',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/campo-extra-datos`,
    );

    await assertFails(
      setDoc(
        reference,
        validSleepData({
          dataOverrides: {
            calidadSueno: 'buena',
          },
        }),
      ),
    );
  },
);

test(
  'se rechazan campos adicionales en el nivel superior',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/campo-extra-superior`,
    );

    await assertFails(
      setDoc(
        reference,
        validSleepData({
          overrides: {
            nombreNino:
              'Dato no permitido',
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza un uidOperacion diferente al propietario',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/uid-invalido`,
    );

    await assertFails(
      setDoc(
        reference,
        validSleepData({
          overrides: {
            uidOperacion:
              'usuario-b',
          },
        }),
      ),
    );
  },
);

test(
  'otro usuario no puede registrar sueño en un perfil ajeno',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/sueno-ajeno`,
    );

    await assertFails(
      setDoc(
        reference,
        validSleepData({
          overrides: {
            uidOperacion:
              'usuario-b',
          },
        }),
      ),
    );
  },
);

test(
  'un usuario no autenticado no puede registrar sueño',
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

    const unauthenticatedDb = testEnv
      .unauthenticatedContext()
      .firestore();

    const reference = doc(
      unauthenticatedDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/sueno-sin-auth`,
    );

    await assertFails(
      setDoc(
        reference,
        validSleepData(),
      ),
    );
  },
);

test(
  'no se puede registrar sueño cuando el perfil está inactivo',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/perfil-inactivo`,
    );

    await assertFails(
      setDoc(
        reference,
        validSleepData(),
      ),
    );
  },
);

test(
  'el propietario puede consultar un registro de sueño persistido',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/sueno-readable`,
    );

    await setDoc(
      reference,
      validSleepData({
        observation:
          'Registro ficticio para prueba.',
      }),
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
      'sueno',
    );

    assert.equal(
      snapshot.data().datos.horaInicio,
      '22:00',
    );

    assert.equal(
      snapshot.data().datos.horaFin,
      '06:00',
    );

    assert.equal(
      snapshot.data().datos.duracionMin,
      480,
    );
  },
);

test(
  'un registro de sueño no puede modificarse ni eliminarse',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/sueno-inmutable`,
    );

    await setDoc(
      reference,
      validSleepData(),
    );

    await assertFails(
      updateDoc(
        reference,
        {
          'datos.duracionMin': 60,
        },
      ),
    );

    await assertFails(
      deleteDoc(reference),
    );
  },
);