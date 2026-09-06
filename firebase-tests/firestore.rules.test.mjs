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

const projectId = 'sendaris-rules-test';

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

test('usuario autenticado puede crear su propio perfil anónimo válido', async () => {
  const db = testEnv
    .authenticatedContext('usuario-a')
    .firestore();

  const reference = doc(
    db,
    'usuarios/usuario-a/seguimientos/550e8400-e29b-41d4-a716-446655440000',
  );

  await assertSucceeds(
    setDoc(reference, {
      fechaCreacion: new Date('2026-09-03T12:00:00Z'),
      activo: true,
    }),
  );
});

test('usuario no autenticado no puede leer perfiles', async () => {
  const adminDb = testEnv
    .authenticatedContext('usuario-a')
    .firestore();

  const path =
    'usuarios/usuario-a/seguimientos/550e8400-e29b-41d4-a716-446655440000';

  await setDoc(doc(adminDb, path), {
    fechaCreacion: new Date('2026-09-03T12:00:00Z'),
    activo: true,
  });

  const unauthenticatedDb =
    testEnv.unauthenticatedContext().firestore();

  await assertFails(
    getDoc(doc(unauthenticatedDb, path)),
  );
});

test('un usuario no puede leer datos pertenecientes a otra cuenta', async () => {
  const ownerDb = testEnv
    .authenticatedContext('usuario-a')
    .firestore();

  const path =
    'usuarios/usuario-a/seguimientos/550e8400-e29b-41d4-a716-446655440000';

  await setDoc(doc(ownerDb, path), {
    fechaCreacion: new Date('2026-09-03T12:00:00Z'),
    activo: true,
  });

  const otherUserDb = testEnv
    .authenticatedContext('usuario-b')
    .firestore();

  await assertFails(
    getDoc(doc(otherUserDb, path)),
  );
});

test('un usuario no puede escribir dentro de la ruta de otra cuenta', async () => {
  const db = testEnv
    .authenticatedContext('usuario-b')
    .firestore();

  const reference = doc(
    db,
    'usuarios/usuario-a/seguimientos/550e8400-e29b-41d4-a716-446655440000',
  );

  await assertFails(
    setDoc(reference, {
      fechaCreacion: new Date('2026-09-03T12:00:00Z'),
      activo: true,
    }),
  );
});

test('un perfil con identificadores directos es rechazado', async () => {
  const db = testEnv
    .authenticatedContext('usuario-a')
    .firestore();

  const reference = doc(
    db,
    'usuarios/usuario-a/seguimientos/550e8400-e29b-41d4-a716-446655440000',
  );

  await assertFails(
    setDoc(reference, {
      fechaCreacion: new Date('2026-09-03T12:00:00Z'),
      activo: true,
      nombre: 'Dato prohibido',
    }),
  );
});

test('el propietario puede desactivar su perfil', async () => {
  const db = testEnv
    .authenticatedContext('usuario-a')
    .firestore();

  const reference = doc(
    db,
    'usuarios/usuario-a/seguimientos/550e8400-e29b-41d4-a716-446655440000',
  );

  await setDoc(reference, {
    fechaCreacion: new Date('2026-09-03T12:00:00Z'),
    activo: true,
  });

  await assertSucceeds(
    updateDoc(reference, {
      activo: false,
    }),
  );
});

test('la fecha de creación del perfil no puede modificarse', async () => {
  const db = testEnv
    .authenticatedContext('usuario-a')
    .firestore();

  const reference = doc(
    db,
    'usuarios/usuario-a/seguimientos/550e8400-e29b-41d4-a716-446655440000',
  );

  await setDoc(reference, {
    fechaCreacion: new Date('2026-09-03T12:00:00Z'),
    activo: true,
  });

  await assertFails(
    updateDoc(reference, {
      fechaCreacion: new Date('2026-09-04T12:00:00Z'),
    }),
  );
});

test('un perfil no puede eliminarse físicamente', async () => {
  const db = testEnv
    .authenticatedContext('usuario-a')
    .firestore();

  const reference = doc(
    db,
    'usuarios/usuario-a/seguimientos/550e8400-e29b-41d4-a716-446655440000',
  );

  await setDoc(reference, {
    fechaCreacion: new Date('2026-09-03T12:00:00Z'),
    activo: true,
  });

  await assertFails(
    deleteDoc(reference),
  );
});

test('las colecciones futuras continúan cerradas hasta definir su esquema', async () => {
  const db = testEnv
    .authenticatedContext('usuario-a')
    .firestore();

  const reference = doc(
    db,
    'usuarios/usuario-a/seguimientos/550e8400-e29b-41d4-a716-446655440000/registros/registro-1',
  );

  await assertFails(
    setDoc(reference, {
      tipoRegistro: 'conducta',
    }),
  );
});

test('los datos autorizados pueden recuperarse íntegramente', async () => {
  const db = testEnv
    .authenticatedContext('usuario-a')
    .firestore();

  const path =
    'usuarios/usuario-a/seguimientos/550e8400-e29b-41d4-a716-446655440000';

  await setDoc(doc(db, path), {
    fechaCreacion: new Date('2026-09-03T12:00:00Z'),
    activo: true,
  });

  const snapshot = await assertSucceeds(
    getDoc(doc(db, path)),
  );

  assert.equal(snapshot.exists(), true);
  assert.equal(snapshot.data().activo, true);
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

function validBehaviorData({
  uid = 'usuario-a',
  overrides = {},
  behaviorOverrides = {},
} = {}) {
  return {
    tipoRegistro: 'conducta',
    fechaEvento: new Date('2026-09-05T14:30:00Z'),
    fechaCreacion: new Date('2026-09-05T18:00:00Z'),
    fechaActualizacion: new Date('2026-09-05T18:00:00Z'),
    uidOperacion: uid,
    datos: {
      fecha: new Date('2026-09-05T00:00:00Z'),
      categoria: 'conducta_repetitiva',
      hora: '14:30',
      duracionMin: 12,
      intensidad: 'media',
      contexto: 'Actividad cotidiana ficticia',
      observacion: 'Registro ficticio de prueba.',
      ...behaviorOverrides,
    },
    ...overrides,
  };
}

test(
  'el propietario puede crear una conducta válida en un seguimiento activo',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-1`,
    );

    await assertSucceeds(
      setDoc(
        reference,
        validBehaviorData(),
      ),
    );
  },
);

test(
  'una conducta puede omitir todos los campos descriptivos opcionales',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-2`,
    );

    await assertSucceeds(
      setDoc(reference, {
        tipoRegistro: 'conducta',
        fechaEvento: new Date(
          '2026-09-05T00:00:00Z',
        ),
        fechaCreacion: new Date(
          '2026-09-05T18:00:00Z',
        ),
        fechaActualizacion: new Date(
          '2026-09-05T18:00:00Z',
        ),
        uidOperacion: 'usuario-a',
        datos: {
          fecha: new Date(
            '2026-09-05T00:00:00Z',
          ),
          categoria: 'iniciativa_social',
        },
      }),
    );
  },
);

test(
  'otro usuario no puede crear conductas en un seguimiento ajeno',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-3`,
    );

    await assertFails(
      setDoc(
        reference,
        validBehaviorData({
          uid: 'usuario-b',
        }),
      ),
    );
  },
);

test(
  'no se puede crear una conducta sin un seguimiento existente',
  async () => {
    const db = testEnv
      .authenticatedContext('usuario-a')
      .firestore();

    const reference = doc(
      db,
      'usuarios/usuario-a/seguimientos/seguimiento-inexistente/registros/registro-4',
    );

    await assertFails(
      setDoc(
        reference,
        validBehaviorData(),
      ),
    );
  },
);

test(
  'no se puede crear una conducta en un seguimiento inactivo',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-5`,
    );

    await assertFails(
      setDoc(
        reference,
        validBehaviorData(),
      ),
    );
  },
);

test(
  'se rechaza una categoría de conducta fuera del catálogo',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-6`,
    );

    await assertFails(
      setDoc(
        reference,
        validBehaviorData({
          behaviorOverrides: {
            categoria: 'categoria_invalida',
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza una duración igual o menor que cero',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-7`,
    );

    await assertFails(
      setDoc(
        reference,
        validBehaviorData({
          behaviorOverrides: {
            duracionMin: 0,
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza una intensidad fuera del catálogo descriptivo',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-8`,
    );

    await assertFails(
      setDoc(
        reference,
        validBehaviorData({
          behaviorOverrides: {
            intensidad: 'critica',
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza una hora con formato inválido',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-9`,
    );

    await assertFails(
      setDoc(
        reference,
        validBehaviorData({
          behaviorOverrides: {
            hora: '27:90',
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza un uidOperacion diferente al usuario autenticado',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-10`,
    );

    await assertFails(
      setDoc(
        reference,
        validBehaviorData({
          uid: 'usuario-b',
        }),
      ),
    );
  },
);

test(
  'se rechazan campos adicionales no permitidos en una conducta',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-11`,
    );

    await assertFails(
      setDoc(
        reference,
        validBehaviorData({
          behaviorOverrides: {
            nombre: 'Identificador prohibido',
          },
        }),
      ),
    );
  },
);

test(
  'un registro de otro tipo continúa bloqueado',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-12`,
    );

    await assertFails(
      setDoc(
        reference,
        validBehaviorData({
          overrides: {
            tipoRegistro: 'sueno',
          },
        }),
      ),
    );
  },
);

test(
  'el propietario puede leer una conducta persistida',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-13`,
    );

    await setDoc(
      reference,
      validBehaviorData(),
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
      'conducta',
    );

    assert.equal(
      snapshot.data().datos.categoria,
      'conducta_repetitiva',
    );
  },
);

test(
  'otro usuario no puede leer una conducta ajena',
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

    const path =
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-14`;

    await setDoc(
      doc(ownerDb, path),
      validBehaviorData(),
    );

    const otherDb = testEnv
      .authenticatedContext('usuario-b')
      .firestore();

    await assertFails(
      getDoc(
        doc(otherDb, path),
      ),
    );
  },
);

test(
  'una conducta no puede eliminarse físicamente',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-15`,
    );

    await setDoc(
      reference,
      validBehaviorData(),
    );

    await assertFails(
      deleteDoc(reference),
    );
  },
);

test(
  'una conducta no puede modificarse todavía',
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
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/registro-16`,
    );

    await setDoc(
      reference,
      validBehaviorData(),
    );

    await assertFails(
      updateDoc(
        reference,
        {
          'datos.duracionMin': 20,
        },
      ),
    );
  },
);