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
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const projectId =
  'sendaris-feeding-rud-rules-test';

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

  await setDoc(
    reference,
    {
      fechaCreacion: new Date(
        '2026-09-10T12:00:00Z',
      ),
      activo: active,
    },
  );

  return reference;
}

function validFeedingData({
  category = 'almuerzo',
  observation = 'Registro ficticio.',
  includeObservation = true,
  eventDate = new Date(
    '2026-09-10T00:00:00Z',
  ),
  feedingDate = new Date(
    '2026-09-10T00:00:00Z',
  ),
  createdAt = new Date(
    '2026-09-10T20:00:00Z',
  ),
  updatedAt = new Date(
    '2026-09-10T20:00:00Z',
  ),
  operationUid = 'usuario-a',
  type = 'alimentacion',
  overrides = {},
  dataOverrides = {},
} = {}) {
  const feedingData = {
    fecha: feedingDate,
    categoria: category,
    ...dataOverrides,
  };

  if (includeObservation) {
    feedingData.observacion = observation;
  }

  return {
    tipoRegistro: type,
    fechaEvento: eventDate,
    fechaCreacion: createdAt,
    fechaActualizacion: updatedAt,
    uidOperacion: operationUid,
    datos: feedingData,
    ...overrides,
  };
}

async function prepareOwnerContext() {
  const db = authenticatedDb('usuario-a');

  const anonymousId =
    '550e8400-e29b-41d4-a716-446655440000';

  const profileReference =
    await createTrackingProfile({
      db,
      uid: 'usuario-a',
      anonymousId,
    });

  const recordReference = doc(
    db,
    `usuarios/usuario-a/seguimientos/${anonymousId}/registros/alimentacion-1`,
  );

  await setDoc(
    recordReference,
    validFeedingData(),
  );

  return {
    db,
    anonymousId,
    profileReference,
    recordReference,
  };
}

test(
  'el propietario puede editar una alimentación válida preservando identidad y creación',
  async () => {
    const {
      recordReference,
    } = await prepareOwnerContext();

    await assertSucceeds(
      setDoc(
        recordReference,
        validFeedingData({
          category: 'desayuno',
          observation:
            'Observación actualizada.',
          eventDate: new Date(
            '2026-09-11T00:00:00Z',
          ),
          feedingDate: new Date(
            '2026-09-11T00:00:00Z',
          ),
          updatedAt: new Date(
            '2026-09-11T20:00:00Z',
          ),
        }),
      ),
    );
  },
);

test(
  'el propietario puede retirar la observación opcional al editar',
  async () => {
    const {
      recordReference,
    } = await prepareOwnerContext();

    await assertSucceeds(
      setDoc(
        recordReference,
        validFeedingData({
          includeObservation: false,
          updatedAt: new Date(
            '2026-09-10T21:00:00Z',
          ),
        }),
      ),
    );
  },
);

test(
  'no se puede cambiar el tipo de registro durante una edición',
  async () => {
    const {
      recordReference,
    } = await prepareOwnerContext();

    await assertFails(
      setDoc(
        recordReference,
        validFeedingData({
          type: 'conducta',
          updatedAt: new Date(
            '2026-09-10T21:00:00Z',
          ),
        }),
      ),
    );
  },
);

test(
  'no se puede modificar la fecha de creación',
  async () => {
    const {
      recordReference,
    } = await prepareOwnerContext();

    await assertFails(
      setDoc(
        recordReference,
        validFeedingData({
          createdAt: new Date(
            '2026-09-10T20:30:00Z',
          ),
          updatedAt: new Date(
            '2026-09-10T21:00:00Z',
          ),
        }),
      ),
    );
  },
);

test(
  'fechaActualizacion debe ser posterior a la anterior',
  async () => {
    const {
      recordReference,
    } = await prepareOwnerContext();

    await assertFails(
      setDoc(
        recordReference,
        validFeedingData({
          updatedAt: new Date(
            '2026-09-10T20:00:00Z',
          ),
        }),
      ),
    );
  },
);

test(
  'fechaEvento debe coincidir con datos.fecha durante una edición',
  async () => {
    const {
      recordReference,
    } = await prepareOwnerContext();

    await assertFails(
      setDoc(
        recordReference,
        validFeedingData({
          eventDate: new Date(
            '2026-09-11T00:00:00Z',
          ),
          feedingDate: new Date(
            '2026-09-12T00:00:00Z',
          ),
          updatedAt: new Date(
            '2026-09-10T21:00:00Z',
          ),
        }),
      ),
    );
  },
);

test(
  'no se puede guardar una categoría fuera del catálogo durante una edición',
  async () => {
    const {
      recordReference,
    } = await prepareOwnerContext();

    await assertFails(
      setDoc(
        recordReference,
        validFeedingData({
          category: 'saludable',
          updatedAt: new Date(
            '2026-09-10T21:00:00Z',
          ),
        }),
      ),
    );
  },
);

test(
  'no se permiten campos adicionales dentro de datos durante una edición',
  async () => {
    const {
      recordReference,
    } = await prepareOwnerContext();

    await assertFails(
      setDoc(
        recordReference,
        validFeedingData({
          updatedAt: new Date(
            '2026-09-10T21:00:00Z',
          ),
          dataOverrides: {
            calorias: 500,
          },
        }),
      ),
    );
  },
);

test(
  'uidOperacion debe continuar correspondiendo al propietario autenticado',
  async () => {
    const {
      recordReference,
    } = await prepareOwnerContext();

    await assertFails(
      setDoc(
        recordReference,
        validFeedingData({
          operationUid: 'usuario-b',
          updatedAt: new Date(
            '2026-09-10T21:00:00Z',
          ),
        }),
      ),
    );
  },
);

test(
  'no se puede editar alimentación cuando el seguimiento está inactivo',
  async () => {
    const {
      profileReference,
      recordReference,
    } = await prepareOwnerContext();

    await updateDoc(
      profileReference,
      {
        activo: false,
      },
    );

    await assertFails(
      setDoc(
        recordReference,
        validFeedingData({
          category: 'refrigerio',
          updatedAt: new Date(
            '2026-09-10T21:00:00Z',
          ),
        }),
      ),
    );
  },
);

test(
  'otro usuario no puede editar un registro de alimentación ajeno',
  async () => {
    const {
      anonymousId,
    } = await prepareOwnerContext();

    const otherDb =
      authenticatedDb('usuario-b');

    const reference = doc(
      otherDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/alimentacion-1`,
    );

    await assertFails(
      setDoc(
        reference,
        validFeedingData({
          operationUid: 'usuario-b',
          updatedAt: new Date(
            '2026-09-10T21:00:00Z',
          ),
        }),
      ),
    );
  },
);

test(
  'el propietario puede eliminar físicamente su registro de alimentación',
  async () => {
    const {
      recordReference,
    } = await prepareOwnerContext();

    await assertSucceeds(
      deleteDoc(
        recordReference,
      ),
    );
  },
);

test(
  'otro usuario no puede eliminar un registro de alimentación ajeno',
  async () => {
    const {
      anonymousId,
    } = await prepareOwnerContext();

    const otherDb =
      authenticatedDb('usuario-b');

    const reference = doc(
      otherDb,
      `usuarios/usuario-a/seguimientos/${anonymousId}/registros/alimentacion-1`,
    );

    await assertFails(
      deleteDoc(
        reference,
      ),
    );
  },
);