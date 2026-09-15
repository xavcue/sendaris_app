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

const projectId = 'sendaris-dysregulation-rules-test';

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
    fechaCreacion: new Date('2026-09-15T12:00:00Z'),
    activo: true,
  });

  return reference;
}

function validDysregulationData({
  time,
  durationMinutes,
  intensity,
  context,
  observation,
  eventDate = new Date('2026-09-15T00:00:00Z'),
  episodeDate = new Date('2026-09-15T00:00:00Z'),
  overrides = {},
  dataOverrides = {},
} = {}) {
  const episodeData = {
    fecha: episodeDate,
    ...dataOverrides,
  };

  if (time !== undefined) {
    episodeData.hora = time;
  }

  if (durationMinutes !== undefined) {
    episodeData.duracionMin = durationMinutes;
  }

  if (intensity !== undefined) {
    episodeData.intensidad = intensity;
  }

  if (context !== undefined) {
    episodeData.contexto = context;
  }

  if (observation !== undefined) {
    episodeData.observacion = observation;
  }

  return {
    tipoRegistro: 'desregulacion',
    fechaEvento: eventDate,
    fechaCreacion: new Date('2026-09-15T20:00:00Z'),
    fechaActualizacion: new Date('2026-09-15T20:00:00Z'),
    uidOperacion: 'usuario-a',
    datos: episodeData,
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
  'el propietario puede registrar un episodio de desregulación válido',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/desregulacion-1`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validDysregulationData(),
      ),
    );
  },
);

test(
  'los campos descriptivos opcionales pueden omitirse',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/desregulacion-minima`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validDysregulationData(),
      ),
    );
  },
);

test(
  'se permiten hora duración intensidad contexto y observación válidos',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/desregulacion-completa`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validDysregulationData({
          time: '14:30',
          durationMinutes: 12,
          intensity: 'media',
          context: 'Durante una actividad cotidiana',
          observation: 'Registro ficticio descriptivo.',
          eventDate:
            new Date('2026-09-15T14:30:00Z'),
        }),
      ),
    );
  },
);

test(
  'se permite una duración igual a cero',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/duracion-cero`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validDysregulationData({
          durationMinutes: 0,
        }),
      ),
    );
  },
);

test(
  'se permiten exclusivamente las tres intensidades descriptivas definidas',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const intensities = [
      'baja',
      'media',
      'alta',
    ];

    for (const intensity of intensities) {
      const reference = doc(
        db,
        `usuarios/usuario-a/seguimientos/${anonymousId}/registros/intensidad-${intensity}`,
      );

      await assertSucceeds(
        setDoc(
          reference,
          validDysregulationData({
            intensity,
          }),
        ),
      );
    }
  },
);

test(
  'se rechaza una fecha que no sea timestamp',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/fecha-invalida`,
    );

    await assertFails(
      setDoc(
        reference,
        validDysregulationData({
          dataOverrides: {
            fecha: '2026-09-15',
          },
        }),
      ),
    );
  },
);

test(
  'sin hora se rechaza fechaEvento diferente de datos.fecha',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/fecha-no-coincide`,
    );

    await assertFails(
      setDoc(
        reference,
        validDysregulationData({
          eventDate:
            new Date('2026-09-16T00:00:00Z'),
        }),
      ),
    );
  },
);

test(
  'se rechaza una hora con formato inválido',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/hora-invalida`,
    );

    await assertFails(
      setDoc(
        reference,
        validDysregulationData({
          time: '25:90',
          eventDate:
            new Date('2026-09-15T14:30:00Z'),
        }),
      ),
    );
  },
);

test(
  'se rechaza una duración negativa',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/duracion-negativa`,
    );

    await assertFails(
      setDoc(
        reference,
        validDysregulationData({
          durationMinutes: -1,
        }),
      ),
    );
  },
);

test(
  'se rechaza una duración que no sea un entero',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/duracion-invalida`,
    );

    await assertFails(
      setDoc(
        reference,
        validDysregulationData({
          dataOverrides: {
            duracionMin: '12',
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza una intensidad fuera del catálogo',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/intensidad-invalida`,
    );

    await assertFails(
      setDoc(
        reference,
        validDysregulationData({
          intensity: 'severa',
        }),
      ),
    );
  },
);

test(
  'se rechaza un contexto vacío cuando está presente',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/contexto-vacio`,
    );

    await assertFails(
      setDoc(
        reference,
        validDysregulationData({
          context: '',
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
        validDysregulationData({
          observation: '',
        }),
      ),
    );
  },
);

test(
  'se rechazan campos causales clínicos o identificadores fuera del alcance',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const forbiddenFields = {
      causa: 'dato no permitido',
      causaInferida: 'dato no permitido',
      diagnostico: 'dato no permitido',
      recomendacion: 'dato no permitido',
      interpretacionClinica: 'dato no permitido',
      severidad: 'alta',
      nombreNino: 'dato no permitido',
    };

    for (const [field, value] of Object.entries(
      forbiddenFields,
    )) {
      const reference = doc(
        db,
        `usuarios/usuario-a/seguimientos/${anonymousId}/registros/campo-${field}`,
      );

      await assertFails(
        setDoc(
          reference,
          validDysregulationData({
            dataOverrides: {
              [field]: value,
            },
          }),
        ),
      );
    }
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
        validDysregulationData({
          overrides: {
            nombreNino: 'dato no permitido',
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
        validDysregulationData({
          overrides: {
            uidOperacion: 'usuario-b',
          },
        }),
      ),
    );
  },
);

test(
  'otro usuario no puede registrar desregulación en un perfil ajeno',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/desregulacion-ajena`,
    );

    await assertFails(
      setDoc(
        reference,
        validDysregulationData({
          overrides: {
            uidOperacion: 'usuario-b',
          },
        }),
      ),
    );
  },
);

test(
  'un usuario no autenticado no puede registrar desregulación',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/desregulacion-sin-auth`,
    );

    await assertFails(
      setDoc(
        reference,
        validDysregulationData(),
      ),
    );
  },
);

test(
  'no se puede registrar desregulación cuando el perfil está inactivo',
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
        validDysregulationData(),
      ),
    );
  },
);

test(
  'el propietario puede consultar un episodio de desregulación persistido',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/desregulacion-readable`,
    );

    await setDoc(
      reference,
      validDysregulationData({
        time: '14:30',
        durationMinutes: 12,
        intensity: 'media',
        context: 'Actividad cotidiana',
        observation:
          'Registro ficticio para prueba.',
        eventDate:
          new Date('2026-09-15T14:30:00Z'),
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
      'desregulacion',
    );

    assert.equal(
      snapshot.data().datos.hora,
      '14:30',
    );

    assert.equal(
      snapshot.data().datos.duracionMin,
      12,
    );

    assert.equal(
      snapshot.data().datos.intensidad,
      'media',
    );

    assert.equal(
      snapshot.data().datos.contexto,
      'Actividad cotidiana',
    );

    assert.equal(
      snapshot.data().datos.observacion,
      'Registro ficticio para prueba.',
    );
  },
);

test(
  'un registro de desregulación no puede modificarse ni eliminarse',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/desregulacion-inmutable`,
    );

    await setDoc(
      reference,
      validDysregulationData({
        intensity: 'media',
      }),
    );

    await assertFails(
      updateDoc(
        reference,
        {
          'datos.intensidad': 'alta',
        },
      ),
    );

    await assertFails(
      deleteDoc(reference),
    );
  },
);