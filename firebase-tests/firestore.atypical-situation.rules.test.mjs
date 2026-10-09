import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import {
  after,
  before,
  beforeEach,
  test,
} from 'node:test';

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

const projectId =
  'sendaris-atypical-situation-rules-test';

const rulesPath = fileURLToPath(
  new URL(
    '../firestore.rules',
    import.meta.url,
  ),
);

let testEnv;

before(async () => {
  testEnv =
    await initializeTestEnvironment({
      projectId,
      firestore: {
        host: '127.0.0.1',
        port: 8080,
        rules: fs.readFileSync(
          rulesPath,
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

  await setDoc(
    reference,
    {
      fechaCreacion:
        new Date(
          '2026-09-06T12:00:00Z',
        ),
      activo:
        active,
    },
  );

  return reference;
}

function validAtypicalSituationData({
  uid = 'usuario-a',
  category = 'evento_inesperado',
  observation =
    'Se produjo un cambio no habitual.',
  eventDate =
    new Date(
      '2026-09-06T00:00:00Z',
    ),
  createdAt =
    new Date(
      '2026-09-06T18:00:00Z',
    ),
  updatedAt =
    new Date(
      '2026-09-06T18:00:00Z',
    ),
  overrides = {},
  dataOverrides = {},
} = {}) {
  return {
    tipoRegistro:
      'situacionAtipica',
    fechaEvento:
      eventDate,
    fechaCreacion:
      createdAt,
    fechaActualizacion:
      updatedAt,
    uidOperacion:
      uid,
    datos: {
      fecha:
        eventDate,
      categoriaGeneral:
        category,
      observacion:
        observation,
      ...dataOverrides,
    },
    ...overrides,
  };
}

async function prepareActiveContext() {
  const db = authenticatedDb('usuario-a');

  const anonymousId =
    '550e8400-e29b-41d4-a716-446655440000';

  await createTrackingProfile({
    db,
    uid:
      'usuario-a',
    anonymousId,
  });

  return {
    db,
    anonymousId,
  };
}

async function preparePersistedSituation({
  recordId = 'situacion-1',
} = {}) {
  const {
    db,
    anonymousId,
  } = await prepareActiveContext();

  const reference = doc(
    db,
    `usuarios/usuario-a/seguimientos/${anonymousId}/registros/${recordId}`,
  );

  await setDoc(
    reference,
    validAtypicalSituationData(),
  );

  return {
    db,
    anonymousId,
    reference,
  };
}

test(
  'el propietario puede registrar una situación válida',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/situacion-create`,
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
    const {
      db,
      anonymousId,
    } = await prepareActiveContext();

    const categories = [
      'cambio_entorno',
      'transicion_traslado',
      'evento_inesperado',
      'actividad_no_habitual',
      'cambio_horario',
      'interrupcion_externa',
      'otro',
    ];

    for (
      const [
        index,
        category,
      ] of categories.entries()
    ) {
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
  'se rechaza una categoría fuera del catálogo al crear',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/categoria-invalida`,
    );

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          category:
            'categoria_no_permitida',
        }),
      ),
    );
  },
);

test(
  'se rechaza una observación vacía al crear',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/observacion-vacia`,
    );

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          observation:
            '',
        }),
      ),
    );
  },
);

test(
  'se rechaza una fecha que no sea timestamp al crear',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/fecha-invalida`,
    );

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          dataOverrides: {
            fecha:
              '2026-09-06',
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza cuando fechaEvento no coincide con datos.fecha al crear',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/fecha-inconsistente`,
    );

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          eventDate:
            new Date(
              '2026-09-06T00:00:00Z',
            ),
          dataOverrides: {
            fecha:
              new Date(
                '2026-09-05T00:00:00Z',
              ),
          },
        }),
      ),
    );
  },
);

test(
  'se rechazan campos adicionales dentro de datos al crear',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/campo-extra-datos`,
    );

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          dataOverrides: {
            nombreNino:
              'Dato no permitido',
          },
        }),
      ),
    );
  },
);

test(
  'se rechazan campos adicionales en el nivel superior al crear',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/campo-extra-superior`,
    );

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          overrides: {
            identificadorDirecto:
              'Dato no permitido',
          },
        }),
      ),
    );
  },
);

test(
  'se rechaza un uidOperacion diferente al propietario al crear',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareActiveContext();

    const reference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/uid-invalido`,
    );

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
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
  'otro usuario no puede registrar situaciones en un seguimiento ajeno',
  async () => {
    const ownerDb = authenticatedDb('usuario-a');

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createTrackingProfile({
      db:
        ownerDb,
      uid:
        'usuario-a',
      anonymousId,
    });

    const otherDb = authenticatedDb('usuario-b');

    const reference = doc(
      otherDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/situacion-ajena`,
    );

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          uid:
            'usuario-b',
        }),
      ),
    );
  },
);

test(
  'un usuario no autenticado no puede registrar situaciones',
  async () => {
    const ownerDb = authenticatedDb('usuario-a');

    const anonymousId =
      '550e8400-e29b-41d4-a716-446655440000';

    await createTrackingProfile({
      db:
        ownerDb,
      uid:
        'usuario-a',
      anonymousId,
    });

    const unauthenticatedDb =
      testEnv
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
  'no se puede registrar una situación con el seguimiento inactivo',
  async () => {
    const {
      db,
      anonymousId,
    } = await prepareActiveContext();

    const profileReference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}`,
    );

    await updateDoc(
      profileReference,
      {
        activo:
          false,
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
    const {
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-readable',
    });

    const snapshot =
      await assertSucceeds(
        getDoc(
          reference,
        ),
      );

    assert.equal(
      snapshot.exists(),
      true,
    );

    assert.equal(
      snapshot.data().tipoRegistro,
      'situacionAtipica',
    );
  },
);

test(
  'el propietario puede editar fecha categoría y descripción',
  async () => {
    const {
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-edicion-valida',
    });

    const newDate =
      new Date(
        '2026-09-08T00:00:00Z',
      );

    await assertSucceeds(
      setDoc(
        reference,
        validAtypicalSituationData({
          eventDate:
            newDate,
          updatedAt:
            new Date(
              '2026-09-08T18:00:00Z',
            ),
          category:
            'cambio_horario',
          observation:
            'Se modificó el horario previsto.',
        }),
      ),
    );

    const snapshot =
      await assertSucceeds(
        getDoc(
          reference,
        ),
      );

    assert.equal(
      snapshot.data().datos.categoriaGeneral,
      'cambio_horario',
    );

    assert.equal(
      snapshot.data().datos.observacion,
      'Se modificó el horario previsto.',
    );

    assert.equal(
      snapshot.data().datos.fecha.toMillis(),
      newDate.getTime(),
    );
  },
);

test(
  'la edición permite cambiar la fecha manteniendo fechaEvento consistente',
  async () => {
    const {
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-cambio-fecha',
    });

    const newDate =
      new Date(
        '2026-09-10T00:00:00Z',
      );

    await assertSucceeds(
      setDoc(
        reference,
        validAtypicalSituationData({
          eventDate:
            newDate,
          updatedAt:
            new Date(
              '2026-09-10T18:00:00Z',
            ),
        }),
      ),
    );
  },
);

test(
  'la edición no permite cambiar tipoRegistro',
  async () => {
    const {
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-tipo-protegido',
    });

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          updatedAt:
            new Date(
              '2026-09-07T18:00:00Z',
            ),
          overrides: {
            tipoRegistro:
              'alimentacion',
          },
        }),
      ),
    );
  },
);

test(
  'la edición debe preservar fechaCreacion',
  async () => {
    const {
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-creacion-protegida',
    });

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          createdAt:
            new Date(
              '2026-09-07T10:00:00Z',
            ),
          updatedAt:
            new Date(
              '2026-09-07T18:00:00Z',
            ),
        }),
      ),
    );
  },
);

test(
  'la edición exige una fechaActualizacion posterior',
  async () => {
    const {
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-actualizacion-no-posterior',
    });

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          updatedAt:
            new Date(
              '2026-09-06T18:00:00Z',
            ),
        }),
      ),
    );
  },
);

test(
  'la edición rechaza fechaEvento cuando no es timestamp',
  async () => {
    const {
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-fecha-evento-invalida',
    });

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          updatedAt:
            new Date(
              '2026-09-07T18:00:00Z',
            ),
          overrides: {
            fechaEvento:
              '2026-09-07',
          },
        }),
      ),
    );
  },
);

test(
  'la edición rechaza una categoría fuera del catálogo',
  async () => {
    const {
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-categoria-edicion-invalida',
    });

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          updatedAt:
            new Date(
              '2026-09-07T18:00:00Z',
            ),
          category:
            'categoria_no_permitida',
        }),
      ),
    );
  },
);

test(
  'la edición rechaza una descripción vacía',
  async () => {
    const {
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-descripcion-edicion-vacia',
    });

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          updatedAt:
            new Date(
              '2026-09-07T18:00:00Z',
            ),
          observation:
            '',
        }),
      ),
    );
  },
);

test(
  'la edición rechaza fechaEvento diferente de datos.fecha',
  async () => {
    const {
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-fecha-edicion-inconsistente',
    });

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          eventDate:
            new Date(
              '2026-09-07T00:00:00Z',
            ),
          updatedAt:
            new Date(
              '2026-09-07T18:00:00Z',
            ),
          dataOverrides: {
            fecha:
              new Date(
                '2026-09-08T00:00:00Z',
              ),
          },
        }),
      ),
    );
  },
);

test(
  'la edición rechaza campos adicionales dentro de datos',
  async () => {
    const {
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-extra-datos-edicion',
    });

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          updatedAt:
            new Date(
              '2026-09-07T18:00:00Z',
            ),
          dataOverrides: {
            datoNoPermitido:
              true,
          },
        }),
      ),
    );
  },
);

test(
  'la edición rechaza campos adicionales en el nivel superior',
  async () => {
    const {
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-extra-superior-edicion',
    });

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          updatedAt:
            new Date(
              '2026-09-07T18:00:00Z',
            ),
          overrides: {
            datoNoPermitido:
              'valor',
          },
        }),
      ),
    );
  },
);

test(
  'la edición rechaza un uidOperacion diferente al propietario',
  async () => {
    const {
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-uid-edicion-invalido',
    });

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          updatedAt:
            new Date(
              '2026-09-07T18:00:00Z',
            ),
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
  'otro usuario no puede editar una situación ajena',
  async () => {
    const {
      anonymousId,
    } = await preparePersistedSituation({
      recordId:
        'situacion-edicion-ajena',
    });

    const otherDb = authenticatedDb('usuario-b');

    const reference = doc(
      otherDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/situacion-edicion-ajena`,
    );

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          uid:
            'usuario-b',
          updatedAt:
            new Date(
              '2026-09-07T18:00:00Z',
            ),
        }),
      ),
    );
  },
);

test(
  'no se puede editar una situación cuando el seguimiento está inactivo',
  async () => {
    const {
      db,
      anonymousId,
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-edicion-inactiva',
    });

    const profileReference = doc(
      db,
      `usuarios/usuario-a/seguimientos/${anonymousId}`,
    );

    await updateDoc(
      profileReference,
      {
        activo:
          false,
      },
    );

    await assertFails(
      setDoc(
        reference,
        validAtypicalSituationData({
          updatedAt:
            new Date(
              '2026-09-07T18:00:00Z',
            ),
          category:
            'interrupcion_externa',
          observation:
            'Registro modificado.',
        }),
      ),
    );
  },
);

test(
  'el propietario puede eliminar una situación',
  async () => {
    const {
      reference,
    } = await preparePersistedSituation({
      recordId:
        'situacion-eliminar',
    });

    await assertSucceeds(
      deleteDoc(
        reference,
      ),
    );

    const snapshot =
      await assertSucceeds(
        getDoc(
          reference,
        ),
      );

    assert.equal(
      snapshot.exists(),
      false,
    );
  },
);

test(
  'otro usuario no puede eliminar una situación ajena',
  async () => {
    const {
      anonymousId,
    } = await preparePersistedSituation({
      recordId:
        'situacion-eliminar-ajena',
    });

    const otherDb = authenticatedDb('usuario-b');

    const reference = doc(
      otherDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/situacion-eliminar-ajena`,
    );

    await assertFails(
      deleteDoc(
        reference,
      ),
    );
  },
);

test(
  'un usuario no autenticado no puede eliminar una situación',
  async () => {
    const {
      anonymousId,
    } = await preparePersistedSituation({
      recordId:
        'situacion-eliminar-sin-auth',
    });

    const unauthenticatedDb =
      testEnv
        .unauthenticatedContext()
        .firestore();

    const reference = doc(
      unauthenticatedDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/situacion-eliminar-sin-auth`,
    );

    await assertFails(
      deleteDoc(
        reference,
      ),
    );
  },
);