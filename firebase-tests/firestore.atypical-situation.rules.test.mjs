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

const projectId = 'sendaris-atypical-situation-rules-test';

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

function validAtypicalSituationData({
  category = 'evento_inesperado',
  observation = 'Se produjo un cambio no habitual.',
  eventDate = new Date('2026-09-06T00:00:00Z'),
  overrides = {},
  dataOverrides = {},
} = {}) {
  return {
    tipoRegistro: 'situacionAtipica',
    fechaEvento: eventDate,
    fechaCreacion: new Date('2026-09-06T18:00:00Z'),
    fechaActualizacion: new Date('2026-09-06T18:00:00Z'),
    uidOperacion: 'usuario-a',
    datos: {
      fecha: eventDate,
      categoriaGeneral: category,
      observacion: observation,
      ...dataOverrides,
    },
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
  'el propietario puede registrar una situación válida',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/situacion-1`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validAtypicalSituationData(),
      ),
    );
  },
);

test(
  'se permiten exclusivamente las siete categorías definidas',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const categories = [
      'cambio_entorno',
      'transicion_traslado',
      'evento_inesperado',
      'actividad_no_habitual',
      'cambio_horario',
      'interrupcion_externa',
      'otro',
    ];

    for (const [index, category] of categories.entries()) {
      const reference = doc(
        db,
        `usuarios/usuario-a/seguimientos/${anonymousId}/registros/categoria-${index}`,
      );

      await assertSucceeds(
        setDoc(
          reference,
          validAtypicalSituationData({
            category,
          }),
        ),
      );
    }
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
        validAtypicalSituationData({
          category: 'categoria_no_permitida',
        }),
      ),
    );
  },
);

test(
  'se rechaza una observación vacía',
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
        validAtypicalSituationData({
          observation: '',
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
        validAtypicalSituationData({
          dataOverrides: {
            fecha: '2026-09-06',
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
        validAtypicalSituationData({
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
        validAtypicalSituationData({
          dataOverrides: {
            nombreNino: 'Dato no permitido',
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
        validAtypicalSituationData({
          overrides: {
            identificadorDirecto: 'Dato no permitido',
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
        validAtypicalSituationData({
          overrides: {
            uidOperacion: 'usuario-b',
          },
        }),
      ),
    );
  },
);

test(
  'otro usuario no puede registrar situaciones en un perfil ajeno',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/situacion-ajena`,
    );

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          overrides: {
            uidOperacion: 'usuario-b',
          },
        }),
      ),
    );
  },
);

test(
  'un usuario no autenticado no puede registrar situaciones',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/situacion-sin-auth`,
    );

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData(),
      ),
    );
  },
);

test(
  'no se puede registrar una situación cuando el perfil está inactivo',
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
        validAtypicalSituationData(),
      ),
    );
  },
);

test(
  'el propietario puede consultar una situación persistida',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/situacion-readable`,
    );

    await setDoc(
      reference,
      validAtypicalSituationData({
        category: 'cambio_entorno',
        observation:
          'La actividad se realizó en un lugar diferente.',
      }),
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
      'situacionAtipica',
    );

    assert.equal(
      snapshot.data().datos.categoriaGeneral,
      'cambio_entorno',
    );

    assert.equal(
      snapshot.data().datos.observacion,
      'La actividad se realizó en un lugar diferente.',
    );
  },
);

test(
  'una situación no puede modificarse ni eliminarse',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/situacion-inmutable`,
    );

    await setDoc(
      reference,
      validAtypicalSituationData(),
    );

    await assertFails(
      updateDoc(
        reference,
        {
          'datos.observacion':
            'Intento de modificación.',
        },
      ),
    );

    await assertFails(
      deleteDoc(reference),
    );
  },
);