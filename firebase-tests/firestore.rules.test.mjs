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