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
    const ownerDb = authenticatedDb('usuario-a');

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db: ownerDb,
      uid: 'usuario-a',
      anonymousId,
    });

    const otherDb = authenticatedDb('usuario-b');

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
    const ownerDb = authenticatedDb('usuario-a');

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
  'el propietario puede actualizar una interacción social válida',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/interaccion-actualizable`,
    );

    await setDoc(
      reference,
      validSocialInteractionData({
        context: 'Actividad inicial',
        observation: 'Registro inicial.',
      }),
    );

    await assertSucceeds(
      setDoc(
        reference,
        validSocialInteractionData({
          category: 'actividad_compartida',
          context: 'Actividad grupal',
          observation: 'Registro actualizado.',
          eventDate:
            new Date('2026-09-12T00:00:00Z'),
          interactionDate:
            new Date('2026-09-12T00:00:00Z'),
          overrides: {
            fechaActualizacion:
              new Date('2026-09-12T10:00:00Z'),
          },
        }),
      ),
    );

    const snapshot = await getDoc(reference);

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
      'Actividad grupal',
    );

    assert.equal(
      snapshot.data().datos.observacion,
      'Registro actualizado.',
    );

    assert.deepEqual(
      snapshot.data().fechaCreacion.toDate(),
      new Date('2026-09-11T20:00:00Z'),
    );

    assert.deepEqual(
      snapshot.data().fechaActualizacion.toDate(),
      new Date('2026-09-12T10:00:00Z'),
    );
  },
);

test(
  'las cinco categorías generales también son válidas al actualizar',
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

    for (const [index, category] of categories.entries()) {
      const reference = doc(
        db,
        `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-${category}`,
      );

      await setDoc(
        reference,
        validSocialInteractionData(),
      );

      await assertSucceeds(
        setDoc(
          reference,
          validSocialInteractionData({
            category,
            overrides: {
              fechaActualizacion:
                new Date(
                  `2026-09-12T10:0${index}:00Z`,
                ),
            },
          }),
        ),
      );
    }
  },
);

test(
  'una actualización puede retirar contexto y observación opcionales',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-sin-opcionales`,
    );

    await setDoc(
      reference,
      validSocialInteractionData({
        context: 'Actividad recreativa',
        observation: 'Registro inicial.',
      }),
    );

    await assertSucceeds(
      setDoc(
        reference,
        validSocialInteractionData({
          overrides: {
            fechaActualizacion:
              new Date('2026-09-12T10:00:00Z'),
          },
        }),
      ),
    );

    const snapshot = await getDoc(reference);

    assert.equal(
      'contexto' in snapshot.data().datos,
      false,
    );

    assert.equal(
      'observacion' in snapshot.data().datos,
      false,
    );
  },
);

test(
  'se rechaza actualizar sin avanzar fechaActualizacion',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-fecha-igual`,
    );

    await setDoc(
      reference,
      validSocialInteractionData(),
    );

    await assertFails(
      setDoc(
        reference,
        validSocialInteractionData({
          category: 'inicio_interaccion',
        }),
      ),
    );
  },
);

test(
  'se rechaza actualizar con una fechaActualizacion anterior',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-fecha-anterior`,
    );

    await setDoc(
      reference,
      validSocialInteractionData(),
    );

    await assertFails(
      setDoc(
        reference,
        validSocialInteractionData({
          overrides: {
            fechaActualizacion:
              new Date('2026-09-11T19:59:59Z'),
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza modificar fechaCreacion durante una actualización',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-creacion`,
    );

    await setDoc(
      reference,
      validSocialInteractionData(),
    );

    await assertFails(
      setDoc(
        reference,
        validSocialInteractionData({
          overrides: {
            fechaCreacion:
              new Date('2026-09-12T09:00:00Z'),
            fechaActualizacion:
              new Date('2026-09-12T10:00:00Z'),
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza cambiar tipoRegistro durante una actualización',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-tipo`,
    );

    await setDoc(
      reference,
      validSocialInteractionData(),
    );

    await assertFails(
      setDoc(
        reference,
        validSocialInteractionData({
          overrides: {
            tipoRegistro: 'alimentacion',
            fechaActualizacion:
              new Date('2026-09-12T10:00:00Z'),
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza cambiar uidOperacion durante una actualización',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-uid`,
    );

    await setDoc(
      reference,
      validSocialInteractionData(),
    );

    await assertFails(
      setDoc(
        reference,
        validSocialInteractionData({
          overrides: {
            uidOperacion: 'usuario-b',
            fechaActualizacion:
              new Date('2026-09-12T10:00:00Z'),
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza una categoría inválida durante una actualización',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-categoria-invalida`,
    );

    await setDoc(
      reference,
      validSocialInteractionData(),
    );

    await assertFails(
      setDoc(
        reference,
        validSocialInteractionData({
          category: 'buena_interaccion',
          overrides: {
            fechaActualizacion:
              new Date('2026-09-12T10:00:00Z'),
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza una actualización cuando fechaEvento no coincide con datos.fecha',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-fechas-no-coinciden`,
    );

    await setDoc(
      reference,
      validSocialInteractionData(),
    );

    await assertFails(
      setDoc(
        reference,
        validSocialInteractionData({
          eventDate:
            new Date('2026-09-12T00:00:00Z'),
          interactionDate:
            new Date('2026-09-13T00:00:00Z'),
          overrides: {
            fechaActualizacion:
              new Date('2026-09-13T10:00:00Z'),
          },
        }),
      ),
    );
  },
);

test(
  'se rechazan campos adicionales durante una actualización',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const topLevelReference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-extra-superior`,
    );

    await setDoc(
      topLevelReference,
      validSocialInteractionData(),
    );

    await assertFails(
      setDoc(
        topLevelReference,
        validSocialInteractionData({
          overrides: {
            fechaActualizacion:
              new Date('2026-09-12T10:00:00Z'),
            nombreNino: 'dato no permitido',
          },
        }),
      ),
    );

    const dataReference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-extra-datos`,
    );

    await setDoc(
      dataReference,
      validSocialInteractionData(),
    );

    await assertFails(
      setDoc(
        dataReference,
        validSocialInteractionData({
          overrides: {
            fechaActualizacion:
              new Date('2026-09-12T10:00:00Z'),
          },
          dataOverrides: {
            puntuacion: 8,
          },
        }),
      ),
    );
  },
);

test(
  'no se puede actualizar interacción social cuando el perfil está inactivo',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-perfil-inactivo`,
    );

    await setDoc(
      reference,
      validSocialInteractionData(),
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
      setDoc(
        reference,
        validSocialInteractionData({
          category: 'actividad_compartida',
          overrides: {
            fechaActualizacion:
              new Date('2026-09-12T10:00:00Z'),
          },
        }),
      ),
    );
  },
);

test(
  'otro usuario no puede actualizar una interacción social ajena',
  async () => {
    const ownerDb = authenticatedDb('usuario-a');

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db: ownerDb,
      uid: 'usuario-a',
      anonymousId,
    });

    const ownerReference = doc(
      ownerDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-ajeno`,
    );

    await setDoc(
      ownerReference,
      validSocialInteractionData(),
    );

    const otherDb = authenticatedDb('usuario-b');

    const otherReference = doc(
      otherDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-ajeno`,
    );

    await assertFails(
      setDoc(
        otherReference,
        validSocialInteractionData({
          overrides: {
            uidOperacion: 'usuario-b',
            fechaActualizacion:
              new Date('2026-09-12T10:00:00Z'),
          },
        }),
      ),
    );
  },
);

test(
  'un usuario no autenticado no puede actualizar una interacción social',
  async () => {
    const ownerDb = authenticatedDb('usuario-a');

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createActiveTrackingProfile({
      db: ownerDb,
      uid: 'usuario-a',
      anonymousId,
    });

    const ownerReference = doc(
      ownerDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-sin-auth`,
    );

    await setDoc(
      ownerReference,
      validSocialInteractionData(),
    );

    const unauthenticatedDb = testEnv
      .unauthenticatedContext()
      .firestore();

    const unauthenticatedReference = doc(
      unauthenticatedDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/update-sin-auth`,
    );

    await assertFails(
      setDoc(
        unauthenticatedReference,
        validSocialInteractionData({
          overrides: {
            fechaActualizacion:
              new Date('2026-09-12T10:00:00Z'),
          },
        }),
      ),
    );
  },
);

test(
  'el propietario puede eliminar una interacción social persistida',
  async () => {
    const { db, anonymousId } =
      await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/interaccion-eliminable`,
    );

    await setDoc(
      reference,
      validSocialInteractionData(),
    );

    await assertSucceeds(
      deleteDoc(reference),
    );
  },
);