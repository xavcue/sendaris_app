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

const projectId = 'sendaris-feeding-rules-test';

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
    fechaCreacion: new Date('2026-09-10T12:00:00Z'),
    activo: true,
  });

  return reference;
}

function validFeedingData({
  category = 'almuerzo',
  observation,
  eventDate = new Date('2026-09-10T00:00:00Z'),
  feedingDate = new Date('2026-09-10T00:00:00Z'),
  overrides = {},
  dataOverrides = {},
} = {}) {
  const feedingData = {
    fecha: feedingDate,
    categoria: category,
    ...dataOverrides,
  };

  if (observation !== undefined) {
    feedingData.observacion = observation;
  }

  return {
    tipoRegistro: 'alimentacion',
    fechaEvento: eventDate,
    fechaCreacion: new Date('2026-09-10T20:00:00Z'),
    fechaActualizacion: new Date('2026-09-10T20:00:00Z'),
    uidOperacion: 'usuario-a',
    datos: feedingData,
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
  'el propietario puede registrar una alimentación válida',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/alimentacion-1`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validFeedingData(),
      ),
    );
  },
);

test(
  'se permiten exclusivamente las cinco categorías generales definidas',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const categories = [
      'desayuno',
      'refrigerio',
      'almuerzo',
      'merienda_cena',
      'otro',
    ];

    for (const category of categories) {
      const reference = doc(
        db,
        `usuarios/usuario-a/seguimientos/${anonymousId}/registros/${category}`,
      );

      await assertSucceeds(
        setDoc(
          reference,
          validFeedingData({
            category,
          }),
        ),
      );
    }
  },
);

test(
  'la observación puede omitirse',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/sin-observacion`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validFeedingData(),
      ),
    );
  },
);

test(
  'se permite una observación descriptiva no vacía',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/con-observacion`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validFeedingData({
          observation:
            'Comida realizada durante la rutina habitual.',
        }),
      ),
    );
  },
);

test(
  'se rechaza una categoría fuera del catálogo',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/categoria-invalida`,
    );

    await assertFails(
      setDoc(
        reference,
        validFeedingData({
          category: 'saludable',
        }),
      ),
    );
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
        validFeedingData({
          dataOverrides: {
            fecha: '2026-09-10',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/fecha-no-coincide`,
    );

    await assertFails(
      setDoc(
        reference,
        validFeedingData({
          eventDate:
            new Date('2026-09-11T00:00:00Z'),
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
        validFeedingData({
          observation: '',
        }),
      ),
    );
  },
);

test(
  'se rechazan campos nutricionales o clínicos fuera del alcance',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const forbiddenFields = {
      calorias: 500,
      nutrientes: 'proteinas',
      peso: 35,
      diagnostico: 'dato no permitido',
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
          validFeedingData({
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
        validFeedingData({
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
        validFeedingData({
          overrides: {
            uidOperacion: 'usuario-b',
          },
        }),
      ),
    );
  },
);

test(
  'otro usuario no puede registrar alimentación en un perfil ajeno',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/alimentacion-ajena`,
    );

    await assertFails(
      setDoc(
        reference,
        validFeedingData({
          overrides: {
            uidOperacion: 'usuario-b',
          },
        }),
      ),
    );
  },
);

test(
  'un usuario no autenticado no puede registrar alimentación',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/alimentacion-sin-auth`,
    );

    await assertFails(
      setDoc(
        reference,
        validFeedingData(),
      ),
    );
  },
);

test(
  'no se puede registrar alimentación cuando el perfil está inactivo',
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
        validFeedingData(),
      ),
    );
  },
);

test(
  'el propietario puede consultar un registro de alimentación persistido',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/alimentacion-readable`,
    );

    await setDoc(
      reference,
      validFeedingData({
        category: 'almuerzo',
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
      'alimentacion',
    );

    assert.equal(
      snapshot.data().datos.categoria,
      'almuerzo',
    );

    assert.equal(
      snapshot.data().datos.observacion,
      'Registro ficticio para prueba.',
    );
  },
);

test(
  'un registro de alimentación no puede modificarse ni eliminarse',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/alimentacion-inmutable`,
    );

    await setDoc(
      reference,
      validFeedingData(),
    );

    await assertFails(
      updateDoc(
        reference,
        {
          'datos.categoria':
              'desayuno',
        },
      ),
    );

    await assertFails(
      deleteDoc(reference),
    );
  },
);