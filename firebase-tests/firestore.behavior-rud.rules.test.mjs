import fs from 'node:fs';
import {
  after,
  before,
  beforeEach,
  test,
} from 'node:test';

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
} from 'firebase/firestore';

const projectId =
  'sendaris-behavior-rud-rules-test';

let testEnv;

before(async () => {
  testEnv =
    await initializeTestEnvironment({
      projectId,
      firestore: {
        host: '127.0.0.1',
        port: 8080,
        rules: fs.readFileSync(
          '../firestore.rules',
          'utf8',
        ),
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

async function createTrackingProfile({
  db,
  uid,
  anonymousId,
  active = true,
}) {
  const reference = doc(
    db,
    `usuarios/${uid}/seguimientos/${anonymousId}`,
  );

  await setDoc(reference, {
    fechaCreacion: new Date(
      '2026-09-20T12:00:00Z',
    ),
    activo: active,
  });

  return reference;
}

function behaviorData({
  uid = 'usuario-a',
  createdAt = new Date(
    '2026-09-20T18:00:00Z',
  ),
  updatedAt = new Date(
    '2026-09-20T18:00:00Z',
  ),
  eventDate = new Date(
    '2026-09-20T14:30:00Z',
  ),
  overrides = {},
  dataOverrides = {},
} = {}) {
  return {
    tipoRegistro: 'conducta',
    fechaEvento: eventDate,
    fechaCreacion: createdAt,
    fechaActualizacion: updatedAt,
    uidOperacion: uid,
    datos: {
      fecha: new Date(
        '2026-09-20T00:00:00Z',
      ),
      hora: '14:30',
      categoria:
        'conducta_repetitiva',
      duracionMin: 10,
      intensidad: 'media',
      contexto:
        'Actividad cotidiana ficticia',
      observacion:
        'Registro ficticio.',
      ...dataOverrides,
    },
    ...overrides,
  };
}

async function prepareBehavior({
  active = true,
  recordId = 'conducta-1',
} = {}) {
  const db = authenticatedDb('usuario-a');

  const anonymousId =
    '550e8400-e29b-41d4-a716-446655440000';

  await createTrackingProfile({
    db,
    uid: 'usuario-a',
    anonymousId,
    active,
  });

  const reference = doc(
    db,
    `usuarios/usuario-a/seguimientos/${anonymousId}/registros/${recordId}`,
  );

  await setDoc(
    reference,
    behaviorData(),
  );

  return {
    db,
    anonymousId,
    reference,
  };
}

test(
  'el propietario puede editar una conducta válida conservando su identidad',
  async () => {
    const {
      reference,
    } = await prepareBehavior();

    await assertSucceeds(
      setDoc(
        reference,
        behaviorData({
          updatedAt: new Date(
            '2026-09-21T20:00:00Z',
          ),
          eventDate: new Date(
            '2026-09-21T17:15:00Z',
          ),
          dataOverrides: {
            fecha: new Date(
              '2026-09-21T00:00:00Z',
            ),
            hora: '17:15',
            categoria:
              'iniciativa_social',
            duracionMin: 25,
            intensidad: 'alta',
            contexto:
              'Actividad compartida',
            observacion:
              'Registro actualizado.',
          },
        }),
      ),
    );

    const snapshot =
      await assertSucceeds(
        getDoc(reference),
      );

    const data = snapshot.data();

    if (data == null) {
      throw new Error(
        'El registro actualizado no existe.',
      );
    }

    if (
      data.tipoRegistro !== 'conducta'
    ) {
      throw new Error(
        'El tipo de registro cambió.',
      );
    }

    if (
      data.datos.categoria !==
      'iniciativa_social'
    ) {
      throw new Error(
        'La categoría no fue actualizada.',
      );
    }

    if (
      data.datos.duracionMin !== 25
    ) {
      throw new Error(
        'La duración no fue actualizada.',
      );
    }
  },
);

test(
  'la edición permite retirar campos opcionales de la conducta',
  async () => {
    const {
      reference,
    } = await prepareBehavior({
      recordId:
        'conducta-sin-opcionales',
    });

    await assertSucceeds(
      setDoc(reference, {
        tipoRegistro: 'conducta',
        fechaEvento: new Date(
          '2026-09-21T00:00:00Z',
        ),
        fechaCreacion: new Date(
          '2026-09-20T18:00:00Z',
        ),
        fechaActualizacion:
            new Date(
          '2026-09-21T20:00:00Z',
        ),
        uidOperacion: 'usuario-a',
        datos: {
          fecha: new Date(
            '2026-09-21T00:00:00Z',
          ),
          categoria:
              'evitacion_miedo',
        },
      }),
    );

    const snapshot =
        await getDoc(reference);

    const data = snapshot.data();

    if (data == null) {
      throw new Error(
        'El registro actualizado no existe.',
      );
    }

    if (
      'hora' in data.datos ||
      'duracionMin' in data.datos ||
      'intensidad' in data.datos ||
      'contexto' in data.datos ||
      'observacion' in data.datos
    ) {
      throw new Error(
        'Los campos opcionales no fueron retirados.',
      );
    }
  },
);

test(
  'una edición no puede cambiar el tipo de registro',
  async () => {
    const {
      reference,
    } = await prepareBehavior({
      recordId:
        'conducta-cambio-tipo',
    });

    await assertFails(
      setDoc(
        reference,
        behaviorData({
          updatedAt: new Date(
            '2026-09-21T20:00:00Z',
          ),
          overrides: {
            tipoRegistro: 'sueno',
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
      reference,
    } = await prepareBehavior({
      recordId:
        'conducta-cambio-creacion',
    });

    await assertFails(
      setDoc(
        reference,
        behaviorData({
          createdAt: new Date(
            '2026-09-21T18:00:00Z',
          ),
          updatedAt: new Date(
            '2026-09-21T20:00:00Z',
          ),
        }),
      ),
    );
  },
);

test(
  'una edición requiere una fecha de actualización posterior',
  async () => {
    const {
      reference,
    } = await prepareBehavior({
      recordId:
        'conducta-fecha-actualizacion',
    });

    await assertFails(
      setDoc(
        reference,
        behaviorData({
          updatedAt: new Date(
            '2026-09-19T18:00:00Z',
          ),
        }),
      ),
    );
  },
);

test(
  'una edición mantiene las validaciones de categoría y campos permitidos',
  async () => {
    const {
      reference,
    } = await prepareBehavior({
      recordId:
        'conducta-datos-invalidos',
    });

    await assertFails(
      setDoc(
        reference,
        behaviorData({
          updatedAt: new Date(
            '2026-09-21T20:00:00Z',
          ),
          dataOverrides: {
            categoria:
                'categoria_invalida',
          },
        }),
      ),
    );

    await assertFails(
      setDoc(
        reference,
        behaviorData({
          updatedAt: new Date(
            '2026-09-21T20:00:00Z',
          ),
          dataOverrides: {
            diagnostico:
                'Campo prohibido',
          },
        }),
      ),
    );
  },
);

test(
  'otro usuario no puede editar una conducta ajena',
  async () => {
    const {
      anonymousId,
    } = await prepareBehavior({
      recordId:
        'conducta-ajena',
    });

    const otherDb =
      authenticatedDb('usuario-b');

    const reference = doc(
      otherDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/conducta-ajena`,
    );

    await assertFails(
      setDoc(
        reference,
        behaviorData({
          uid: 'usuario-b',
          updatedAt: new Date(
            '2026-09-21T20:00:00Z',
          ),
        }),
      ),
    );
  },
);

test(
  'la edición de conducta requiere un seguimiento vigente',
  async () => {
    const {
      db,
      anonymousId,
      reference,
    } = await prepareBehavior({
      recordId:
        'conducta-seguimiento-inactivo',
    });

    const trackingReference =
        doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}`,
    );

    await setDoc(
      trackingReference,
      {
        fechaCreacion: new Date(
          '2026-09-20T12:00:00Z',
        ),
        activo: false,
      },
    );

    await assertFails(
      setDoc(
        reference,
        behaviorData({
          updatedAt: new Date(
            '2026-09-21T20:00:00Z',
          ),
        }),
      ),
    );
  },
);

test(
  'el propietario puede eliminar una conducta',
  async () => {
    const {
      reference,
    } = await prepareBehavior({
      recordId:
        'conducta-eliminar',
    });

    await assertSucceeds(
      deleteDoc(reference),
    );

    const snapshot =
        await getDoc(reference);

    if (snapshot.exists()) {
      throw new Error(
        'La conducta no fue eliminada.',
      );
    }
  },
);

test(
  'otro usuario no puede eliminar una conducta ajena',
  async () => {
    const {
      anonymousId,
    } = await prepareBehavior({
      recordId:
        'conducta-eliminar-ajena',
    });

    const otherDb =
      authenticatedDb('usuario-b');

    const reference = doc(
      otherDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/conducta-eliminar-ajena`,
    );

    await assertFails(
      deleteDoc(reference),
    );
  },
);