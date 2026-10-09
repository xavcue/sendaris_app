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
} from 'firebase/firestore';

const projectId = 'sendaris-sleep-rud-rules-test';

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

function authenticatedDb(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

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
    fechaCreacion: new Date('2026-09-20T12:00:00Z'),
    activo: true,
  });

  return reference;
}

function sleepData({
  uid = 'usuario-a',
  startTime = '22:00',
  endTime = '06:00',
  durationMinutes = 480,
  observation = 'Registro ficticio.',
  eventDate = new Date('2026-09-20T22:00:00Z'),
  sleepDate = new Date('2026-09-20T00:00:00Z'),
  createdAt = new Date('2026-09-21T10:00:00Z'),
  updatedAt = createdAt,
  overrides = {},
  dataOverrides = {},
} = {}) {
  const data = {
    fecha: sleepDate,
    horaInicio: startTime,
    horaFin: endTime,
    duracionMin: durationMinutes,
    ...dataOverrides,
  };

  if (observation !== undefined) {
    data.observacion = observation;
  }

  return {
    tipoRegistro: 'sueno',
    fechaEvento: eventDate,
    fechaCreacion: createdAt,
    fechaActualizacion: updatedAt,
    uidOperacion: uid,
    datos: data,
    ...overrides,
  };
}

async function prepareOwnerContext() {
  const db = authenticatedDb('usuario-a');

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

async function createInitialSleep({
  db,
  anonymousId,
  recordId = 'sueno-rud-1',
}) {
  const reference = doc(
    db,
    `usuarios/usuario-a/seguimientos/${anonymousId}/registros/${recordId}`,
  );

  await setDoc(
    reference,
    sleepData(),
  );

  return reference;
}

test(
  'el propietario puede editar un sueño válido conservando su identidad',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareOwnerContext();

    const reference = await createInitialSleep({
      db,
      anonymousId,
    });

    await assertSucceeds(
      setDoc(
        reference,
        sleepData({
          startTime: '23:00',
          endTime: '07:30',
          durationMinutes: 510,
          observation: 'Registro actualizado.',
          eventDate: new Date('2026-09-22T23:00:00Z'),
          sleepDate: new Date('2026-09-22T00:00:00Z'),
          createdAt: new Date('2026-09-21T10:00:00Z'),
          updatedAt: new Date('2026-09-23T09:00:00Z'),
        }),
      ),
    );
  },
);

test(
  'la edición permite retirar la observación opcional',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareOwnerContext();

    const reference = await createInitialSleep({
      db,
      anonymousId,
    });

    await assertSucceeds(
      setDoc(
        reference,
        sleepData({
          observation: undefined,
          createdAt: new Date('2026-09-21T10:00:00Z'),
          updatedAt: new Date('2026-09-22T10:00:00Z'),
        }),
      ),
    );
  },
);

test(
  'una edición no puede cambiar el tipo de registro',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareOwnerContext();

    const reference = await createInitialSleep({
      db,
      anonymousId,
    });

    await assertFails(
      setDoc(
        reference,
        sleepData({
          createdAt: new Date('2026-09-21T10:00:00Z'),
          updatedAt: new Date('2026-09-22T10:00:00Z'),
          overrides: {
            tipoRegistro: 'conducta',
          },
        }),
      ),
    );
  },
);

test(
  'una edición no puede cambiar la fecha de creación',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareOwnerContext();

    const reference = await createInitialSleep({
      db,
      anonymousId,
    });

    await assertFails(
      setDoc(
        reference,
        sleepData({
          createdAt: new Date('2026-09-22T10:00:00Z'),
          updatedAt: new Date('2026-09-23T10:00:00Z'),
        }),
      ),
    );
  },
);

test(
  'una edición requiere una fecha de actualización posterior',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareOwnerContext();

    const reference = await createInitialSleep({
      db,
      anonymousId,
    });

    await assertFails(
      setDoc(
        reference,
        sleepData({
          createdAt: new Date('2026-09-21T10:00:00Z'),
          updatedAt: new Date('2026-09-21T10:00:00Z'),
        }),
      ),
    );
  },
);

test(
  'una edición mantiene las validaciones de horas',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareOwnerContext();

    const invalidStartReference =
        await createInitialSleep({
      db,
      anonymousId,
      recordId: 'sueno-hora-inicio-invalida',
    });

    await assertFails(
      setDoc(
        invalidStartReference,
        sleepData({
          startTime: '25:00',
          createdAt: new Date('2026-09-21T10:00:00Z'),
          updatedAt: new Date('2026-09-22T10:00:00Z'),
        }),
      ),
    );

    const equalTimesReference =
        await createInitialSleep({
      db,
      anonymousId,
      recordId: 'sueno-horas-iguales',
    });

    await assertFails(
      setDoc(
        equalTimesReference,
        sleepData({
          startTime: '22:00',
          endTime: '22:00',
          durationMinutes: 1,
          createdAt: new Date('2026-09-21T10:00:00Z'),
          updatedAt: new Date('2026-09-22T10:00:00Z'),
        }),
      ),
    );
  },
);

test(
  'una edición mantiene las validaciones de duración y campos permitidos',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareOwnerContext();

    const invalidDurationReference =
        await createInitialSleep({
      db,
      anonymousId,
      recordId: 'sueno-duracion-invalida',
    });

    await assertFails(
      setDoc(
        invalidDurationReference,
        sleepData({
          durationMinutes: 0,
          createdAt: new Date('2026-09-21T10:00:00Z'),
          updatedAt: new Date('2026-09-22T10:00:00Z'),
        }),
      ),
    );

    const extraFieldReference =
        await createInitialSleep({
      db,
      anonymousId,
      recordId: 'sueno-campo-extra',
    });

    await assertFails(
      setDoc(
        extraFieldReference,
        sleepData({
          createdAt: new Date('2026-09-21T10:00:00Z'),
          updatedAt: new Date('2026-09-22T10:00:00Z'),
          dataOverrides: {
            calidadSueno: 'buena',
          },
        }),
      ),
    );
  },
);

test(
  'otro usuario no puede editar un sueño ajeno',
  async () => {
    const owner = await prepareOwnerContext();

    const reference = await createInitialSleep({
      db: owner.db,
      anonymousId: owner.anonymousId,
    });

    const otherDb = authenticatedDb('usuario-b');

    const otherReference = doc(
      otherDb,
      reference.path,
    );

    await assertFails(
      setDoc(
        otherReference,
        sleepData({
          uid: 'usuario-b',
          createdAt: new Date('2026-09-21T10:00:00Z'),
          updatedAt: new Date('2026-09-22T10:00:00Z'),
        }),
      ),
    );
  },
);

test(
  'el propietario puede eliminar un registro de sueño',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareOwnerContext();

    const reference = await createInitialSleep({
      db,
      anonymousId,
    });

    await assertSucceeds(
      deleteDoc(reference),
    );
  },
);

test(
  'otro usuario no puede eliminar un sueño ajeno',
  async () => {
    const owner = await prepareOwnerContext();

    const reference = await createInitialSleep({
      db: owner.db,
      anonymousId: owner.anonymousId,
    });

    const otherDb = authenticatedDb('usuario-b');

    const otherReference = doc(
      otherDb,
      reference.path,
    );

    await assertFails(
      deleteDoc(otherReference),
    );
  },
);