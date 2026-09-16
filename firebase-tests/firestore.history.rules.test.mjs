import fs from 'node:fs';
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
  collection,
  doc,
  getDocs,
  orderBy,
  query,
  setDoc,
} from 'firebase/firestore';

const projectId =
  'sendaris-history-rules-test';

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

function recordData({
  type = 'conducta',
  eventDate,
  operationUid = 'usuario-a',
}) {
  const timestamp =
    eventDate ??
    new Date(
      '2026-09-15T12:00:00Z',
    );

  return {
    tipoRegistro: type,
    fechaEvento: timestamp,
    fechaCreacion: new Date(
      '2026-09-15T18:00:00Z',
    ),
    fechaActualizacion: new Date(
      '2026-09-15T18:00:00Z',
    ),
    uidOperacion: operationUid,
    datos: {
      fecha: new Date(
        '2026-09-15T00:00:00Z',
      ),
    },
  };
}

async function seedTrackingData() {
  await testEnv.withSecurityRulesDisabled(
    async (context) => {
      const db = context.firestore();

      await setDoc(
        doc(
          db,
          'usuarios/usuario-a/seguimientos/perfil-a',
        ),
        {
          fechaCreacion: new Date(
            '2026-09-01T12:00:00Z',
          ),
          activo: true,
        },
      );

      await setDoc(
        doc(
          db,
          'usuarios/usuario-a/seguimientos/perfil-b',
        ),
        {
          fechaCreacion: new Date(
            '2026-09-02T12:00:00Z',
          ),
          activo: true,
        },
      );

      await setDoc(
        doc(
          db,
          'usuarios/usuario-b/seguimientos/perfil-b-usuario',
        ),
        {
          fechaCreacion: new Date(
            '2026-09-03T12:00:00Z',
          ),
          activo: true,
        },
      );

      await setDoc(
        doc(
          db,
          'usuarios/usuario-a/seguimientos/perfil-a/registros/registro-antiguo',
        ),
        recordData({
          type: 'conducta',
          eventDate: new Date(
            '2026-09-13T09:00:00Z',
          ),
        }),
      );

      await setDoc(
        doc(
          db,
          'usuarios/usuario-a/seguimientos/perfil-a/registros/registro-medio',
        ),
        recordData({
          type: 'sueno',
          eventDate: new Date(
            '2026-09-14T13:30:00Z',
          ),
        }),
      );

      await setDoc(
        doc(
          db,
          'usuarios/usuario-a/seguimientos/perfil-a/registros/registro-reciente',
        ),
        recordData({
          type: 'desregulacion',
          eventDate: new Date(
            '2026-09-15T16:45:00Z',
          ),
        }),
      );

      await setDoc(
        doc(
          db,
          'usuarios/usuario-a/seguimientos/perfil-b/registros/registro-perfil-b',
        ),
        recordData({
          type: 'alimentacion',
          eventDate: new Date(
            '2026-09-15T18:00:00Z',
          ),
        }),
      );

      await setDoc(
        doc(
          db,
          'usuarios/usuario-b/seguimientos/perfil-b-usuario/registros/registro-usuario-b',
        ),
        recordData({
          type: 'interaccionSocial',
          eventDate: new Date(
            '2026-09-15T19:00:00Z',
          ),
          operationUid:
              'usuario-b',
        }),
      );
    },
  );
}

function historyQuery({
  db,
  uid,
  anonymousId,
}) {
  return query(
    collection(
      db,
      `usuarios/${uid}/seguimientos/${anonymousId}/registros`,
    ),
    orderBy(
      'fechaEvento',
      'desc',
    ),
  );
}

test(
  'el propietario puede consultar su historial ordenado del más reciente al más antiguo',
  async () => {
    await seedTrackingData();

    const db = testEnv
      .authenticatedContext(
        'usuario-a',
      )
      .firestore();

    const snapshot =
      await assertSucceeds(
        getDocs(
          historyQuery({
            db,
            uid: 'usuario-a',
            anonymousId:
                'perfil-a',
          }),
        ),
      );

    expectDocumentIds(
      snapshot.docs,
      [
        'registro-reciente',
        'registro-medio',
        'registro-antiguo',
      ],
    );

    assert.deepEqual(
      snapshot.docs.map(
        (document) =>
            document.data()
              .tipoRegistro,
      ),
      [
        'desregulacion',
        'sueno',
        'conducta',
      ],
    );
  },
);

test(
  'la consulta de un perfil no mezcla registros de otro perfil del mismo usuario',
  async () => {
    await seedTrackingData();

    const db = testEnv
      .authenticatedContext(
        'usuario-a',
      )
      .firestore();

    const snapshot =
      await assertSucceeds(
        getDocs(
          historyQuery({
            db,
            uid: 'usuario-a',
            anonymousId:
                'perfil-a',
          }),
        ),
      );

    assert.equal(
      snapshot.docs.length,
      3,
    );

    assert.equal(
      snapshot.docs.some(
        (document) =>
            document.id ===
            'registro-perfil-b',
      ),
      false,
    );
  },
);

test(
  'el propietario puede consultar de forma independiente otro perfil propio',
  async () => {
    await seedTrackingData();

    const db = testEnv
      .authenticatedContext(
        'usuario-a',
      )
      .firestore();

    const snapshot =
      await assertSucceeds(
        getDocs(
          historyQuery({
            db,
            uid: 'usuario-a',
            anonymousId:
                'perfil-b',
          }),
        ),
      );

    expectDocumentIds(
      snapshot.docs,
      [
        'registro-perfil-b',
      ],
    );

    assert.equal(
      snapshot.docs[0].data()
        .tipoRegistro,
      'alimentacion',
    );
  },
);

test(
  'otro usuario no puede consultar el historial del propietario',
  async () => {
    await seedTrackingData();

    const otherDb = testEnv
      .authenticatedContext(
        'usuario-b',
      )
      .firestore();

    await assertFails(
      getDocs(
        historyQuery({
          db: otherDb,
          uid: 'usuario-a',
          anonymousId:
              'perfil-a',
        }),
      ),
    );
  },
);

test(
  'un usuario no autenticado no puede consultar el historial',
  async () => {
    await seedTrackingData();

    const unauthenticatedDb =
        testEnv
            .unauthenticatedContext()
            .firestore();

    await assertFails(
      getDocs(
        historyQuery({
          db: unauthenticatedDb,
          uid: 'usuario-a',
          anonymousId:
              'perfil-a',
        }),
      ),
    );
  },
);

test(
  'un historial sin registros se recupera como una colección vacía',
  async () => {
    await testEnv
        .withSecurityRulesDisabled(
          async (context) => {
            const db =
                context.firestore();

            await setDoc(
              doc(
                db,
                'usuarios/usuario-a/seguimientos/perfil-vacio',
              ),
              {
                fechaCreacion:
                    new Date(
                      '2026-09-15T12:00:00Z',
                    ),
                activo: true,
              },
            );
          },
        );

    const db = testEnv
      .authenticatedContext(
        'usuario-a',
      )
      .firestore();

    const snapshot =
      await assertSucceeds(
        getDocs(
          historyQuery({
            db,
            uid: 'usuario-a',
            anonymousId:
                'perfil-vacio',
          }),
        ),
      );

    assert.equal(
      snapshot.empty,
      true,
    );

    assert.equal(
      snapshot.docs.length,
      0,
    );
  },
);

function expectDocumentIds(
  documents,
  expectedIds,
) {
  assert.deepEqual(
    documents.map(
      (document) => document.id,
    ),
    expectedIds,
  );
}