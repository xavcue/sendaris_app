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

const projectId = 'sendaris-social-interaction-rules-test';

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
    fechaCreacion: new Date('2026-09-11T12:00:00Z'),
    activo: true,
  });

  return reference;
}

function validSocialInteractionData({
  category = 'intercambio_social',
  context,
  observation,
  eventDate = new Date('2026-09-11T00:00:00Z'),
  interactionDate = new Date('2026-09-11T00:00:00Z'),
  overrides = {},
  dataOverrides = {},
} = {}) {
  const interactionData = {
    fecha: interactionDate,
    categoria: category,
    ...dataOverrides,
  };

  if (context !== undefined) {
    interactionData.contexto = context;
  }

  if (observation !== undefined) {
    interactionData.observacion = observation;
  }

  return {
    tipoRegistro: 'interaccionSocial',
    fechaEvento: eventDate,
    fechaCreacion: new Date('2026-09-11T20:00:00Z'),
    fechaActualizacion: new Date('2026-09-11T20:00:00Z'),
    uidOperacion: 'usuario-a',
    datos: interactionData,
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
  'el propietario puede registrar una interacción social válida',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/interaccion-1`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validSocialInteractionData(),
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
      'inicio_interaccion',
      'respuesta_interaccion',
      'intercambio_social',
      'actividad_compartida',
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
          validSocialInteractionData({
            category,
          }),
        ),
      );
    }
  },
);

test(
  'contexto y observación pueden omitirse',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/sin-opcionales`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validSocialInteractionData(),
      ),
    );
  },
);

test(
  'se permite contexto y observación descriptivos no vacíos',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/con-opcionales`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validSocialInteractionData({
          context: 'Actividad recreativa',
          observation:
            'Registro ficticio descriptivo.',
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
        validSocialInteractionData({
          category: 'buena_interaccion',
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
        validSocialInteractionData({
          dataOverrides: {
            fecha: '2026-09-11',
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
        validSocialInteractionData({
          eventDate:
            new Date('2026-09-12T00:00:00Z'),
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
        validSocialInteractionData({
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
        validSocialInteractionData({
          observation: '',
        }),
      ),
    );
  },
);

test(
  'se rechazan campos clínicos o valorativos fuera del alcance',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const forbiddenFields = {
      puntuacion: 8,
      nivelSocial: 'alto',
      habilidadSocial: 'adecuada',
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
          validSocialInteractionData({
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
        validSocialInteractionData({
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
        validSocialInteractionData({
          overrides: {
            uidOperacion: 'usuario-b',
          },
        }),
      ),
    );
  },
);

test(
  'otro usuario no puede registrar interacción social en un perfil ajeno',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/interaccion-ajena`,
    );

    await assertFails(
      setDoc(
        reference,
        validSocialInteractionData({
          overrides: {
            uidOperacion: 'usuario-b',
          },
        }),
      ),
    );
  },
);

test(
  'un usuario no autenticado no puede registrar interacción social',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/interaccion-sin-auth`,
    );

    await assertFails(
      setDoc(
        reference,
        validSocialInteractionData(),
      ),
    );
  },
);

test(
  'no se puede registrar interacción social cuando el perfil está inactivo',
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
        validSocialInteractionData(),
      ),
    );
  },
);

test(
  'el propietario puede consultar una interacción social persistida',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/interaccion-readable`,
    );

    await setDoc(
      reference,
      validSocialInteractionData({
        category: 'actividad_compartida',
        context: 'Actividad recreativa',
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
      'interaccionSocial',
    );

    assert.equal(
      snapshot.data().datos.categoria,
      'actividad_compartida',
    );

    assert.equal(
      snapshot.data().datos.contexto,
      'Actividad recreativa',
    );

    assert.equal(
      snapshot.data().datos.observacion,
      'Registro ficticio para prueba.',
    );
  },
);

test(
  'un registro de interacción social no puede modificarse ni eliminarse',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/interaccion-inmutable`,
    );

    await setDoc(
      reference,
      validSocialInteractionData(),
    );

    await assertFails(
      updateDoc(
        reference,
        {
          'datos.categoria':
              'inicio_interaccion',
        },
      ),
    );

    await assertFails(
      deleteDoc(reference),
    );
  },
);