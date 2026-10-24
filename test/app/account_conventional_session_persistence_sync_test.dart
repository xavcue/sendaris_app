import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/acknowledged_session_timeout_store.dart';
import 'package:sendaris/app/session/account_active_session_checkpoint.dart';
import 'package:sendaris/app/session/account_conventional_session_persistence_sync.dart';
import 'package:sendaris/app/session/account_scoped_session_timeout_store.dart';
import 'package:sendaris/app/session/account_session_persistence_journal.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';
import 'package:sendaris/app/session/session_timeout_store.dart';

final class _FakeIdentity implements AccountIdentitySource {
  _FakeIdentity(this._userId);

  final String? _userId;

  final StreamController<String?> _changes =
      StreamController<String?>.broadcast(sync: true);

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> get userIdChanges => _changes.stream;

  Future<void> dispose() => _changes.close();
}

final class _MemoryTimeoutStore implements SessionTimeoutStore {
  SessionTimeoutRecord? value;

  @override
  Future<SessionTimeoutRecord?> read() async => value;

  @override
  Future<void> write(SessionTimeoutRecord record) async {
    value = record;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

final class _MemoryKeyValueStorage implements AccountSessionKeyValueStorage {
  final Map<String, String> values = <String, String>{};

  bool failNextSecondaryWrite = false;

  @override
  Future<String?> getString(String key) async {
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    if (key == 'sendaris.session.dual.secondary.v1' && failNextSecondaryWrite) {
      failNextSecondaryWrite = false;

      throw StateError('Fallo simulado de persistencia secundaria.');
    }

    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

void main() {
  final start = DateTime.utc(2026, 10, 22, 12);

  late DateTime now;

  late _FakeIdentity accountA;
  late _FakeIdentity accountB;

  late AccountSessionSelectionController selection;

  late _MemoryTimeoutStore legacyStorage;
  late AcknowledgedSessionTimeoutStore acknowledged;

  late _MemoryKeyValueStorage storage;
  late AccountSessionPersistenceJournal journal;

  late AccountConventionalSessionPersistenceSync sync;

  SessionTimeoutRecord record(
    String userId, {
    DateTime? lastActivityAt,
    DateTime? backgroundAt,
  }) {
    return SessionTimeoutRecord(
      userId: userId,
      startedAt: start,
      lastActivityAt: lastActivityAt ?? start,
      backgroundAt: backgroundAt,
    );
  }

  Future<void> selectAccount(FirebaseAccountSlot slot, String userId) async {
    final granted = await selection.select(
      slot: slot,
      expectedUserId: userId,
      verifyAccess: () async => true,
    );

    expect(granted, isTrue);
  }

  Future<void> selectB() {
    return selectAccount(FirebaseAccountSlot.secondary, 'uid-b');
  }

  Future<void> selectA() {
    return selectAccount(FirebaseAccountSlot.primary, 'uid-a');
  }

  Future<void> writeB(SessionTimeoutRecord value) async {
    await acknowledged.write(value);
    await sync.waitForIdle();
  }

  setUp(() {
    now = start;

    accountA = _FakeIdentity('uid-a');
    accountB = _FakeIdentity('uid-b');

    selection = AccountSessionSelectionController(
      primary: accountA,
      secondary: accountB,
    );

    legacyStorage = _MemoryTimeoutStore();

    acknowledged = AcknowledgedSessionTimeoutStore(delegate: legacyStorage);

    storage = _MemoryKeyValueStorage();

    journal = AccountSessionPersistenceJournal(
      selection: selection,
      primary: AccountScopedSessionTimeoutStore(
        slot: FirebaseAccountSlot.primary,
        storage: storage,
      ),
      secondary: AccountScopedSessionTimeoutStore(
        slot: FirebaseAccountSlot.secondary,
        storage: storage,
      ),
      active: AccountActiveSessionCheckpointStore(storage: storage),
      clock: () => now,
    );

    sync = AccountConventionalSessionPersistenceSync(
      selection: selection,
      source: acknowledged,
      journal: journal,
      conventionalSlot: () => FirebaseAccountSlot.secondary,
    );
  });

  tearDown(() async {
    await sync.waitForIdle();

    sync.dispose();
    acknowledged.dispose();
    journal.dispose();
    selection.dispose();

    await accountA.dispose();
    await accountB.dispose();
  });

  group('AUTH-03 B8.10B.8 - Sincronizacion convencional', () {
    test('no publica B antes de autorizarla', () async {
      await writeB(record('uid-b'));

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.secondary, isNull);
    });

    test('una escritura previa se reconoce al autorizar B', () async {
      await writeB(record('uid-b'));

      await selectB();
      await sync.waitForIdle();

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active?.slot, FirebaseAccountSlot.secondary);
      expect(snapshot.active?.userId, 'uid-b');
      expect(snapshot.secondary?.userId, 'uid-b');
      expect(snapshot.secondary?.startedAt, start);
    });

    test(
      'una escritura confirmada despues de seleccionar B se guarda',
      () async {
        await selectB();

        await writeB(record('uid-b'));

        final snapshot = await journal.readSnapshot();

        expect(snapshot.active?.userId, 'uid-b');
        expect(snapshot.secondary?.userId, 'uid-b');
      },
    );

    test('actualiza actividad sin modificar el inicio absoluto', () async {
      await selectB();

      await writeB(record('uid-b'));

      now = start.add(const Duration(minutes: 20));

      await writeB(record('uid-b', lastActivityAt: now));

      final snapshot = await journal.readSnapshot();

      expect(snapshot.secondary?.startedAt, start);
      expect(snapshot.secondary?.lastActivityAt, now);
      expect(snapshot.active?.userId, 'uid-b');
    });

    test('conserva la fecha de segundo plano de B', () async {
      await selectB();

      await writeB(record('uid-b'));

      now = start.add(const Duration(minutes: 5));

      await writeB(record('uid-b', backgroundAt: now));

      final snapshot = await journal.readSnapshot();

      expect(snapshot.secondary?.startedAt, start);
      expect(snapshot.secondary?.lastActivityAt, start);
      expect(snapshot.secondary?.backgroundAt, now);
    });

    test('reanudar B conserva la duracion absoluta', () async {
      await selectB();

      await writeB(record('uid-b'));

      now = start.add(const Duration(minutes: 5));

      await writeB(record('uid-b', backgroundAt: now));

      now = start.add(const Duration(minutes: 10));

      await writeB(record('uid-b', lastActivityAt: now));

      final snapshot = await journal.readSnapshot();

      expect(snapshot.secondary?.backgroundAt, isNull);
      expect(snapshot.secondary?.lastActivityAt, now);
      expect(snapshot.secondary?.startedAt, start);
    });

    test('no confunde el acceso de A con el de B', () async {
      await selectA();

      await writeB(record('uid-b'));

      var snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.secondary, isNull);

      selection.lock();

      await selectB();
      await sync.waitForIdle();

      snapshot = await journal.readSnapshot();

      expect(snapshot.active?.slot, FirebaseAccountSlot.secondary);
      expect(snapshot.active?.userId, 'uid-b');
    });

    test('al activar B no elimina el registro de A', () async {
      await selectA();

      final savedA = await journal.commitAuthorized(
        slot: FirebaseAccountSlot.primary,
        record: record('uid-a'),
      );

      expect(savedA, isTrue);

      await writeB(record('uid-b'));

      selection.lock();

      await selectB();
      await sync.waitForIdle();

      final snapshot = await journal.readSnapshot();

      expect(snapshot.primary?.userId, 'uid-a');
      expect(snapshot.secondary?.userId, 'uid-b');

      expect(snapshot.active?.slot, FirebaseAccountSlot.secondary);
    });

    test('la actividad de A no renueva el registro de B', () async {
      await selectB();

      await writeB(record('uid-b'));

      selection.lock();

      await selectA();

      now = start.add(const Duration(minutes: 10));

      await writeB(record('uid-b', lastActivityAt: now));

      final snapshot = await journal.readSnapshot();

      expect(snapshot.secondary?.lastActivityAt, start);
      expect(snapshot.active?.userId, 'uid-b');
    });

    test('cerrar B impide persistir actividad posterior', () async {
      await selectB();

      await writeB(record('uid-b'));

      selection.lock();

      await journal.revoke(
        slot: FirebaseAccountSlot.secondary,
        userId: 'uid-b',
      );

      now = start.add(const Duration(minutes: 1));

      await writeB(record('uid-b', lastActivityAt: now));

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.secondary, isNull);
    });

    test('rechaza un UID diferente al seleccionado', () async {
      await selectB();

      await writeB(record('uid-c'));

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.secondary, isNull);
    });

    test('rechaza un candidato vencido', () async {
      await selectB();

      now = start.add(SessionTimeoutPolicy.foregroundIdle);

      await writeB(record('uid-b'));

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.secondary, isNull);
      expect(sync.restorationUnavailable, isTrue);
    });

    test('un fallo al guardar no concede restauracion', () async {
      await selectB();

      storage.failNextSecondaryWrite = true;

      await writeB(record('uid-b'));

      var snapshot = await journal.readSnapshot();

      expect(sync.restorationUnavailable, isTrue);
      expect(snapshot.active, isNull);
      expect(snapshot.secondary, isNull);

      // La sesion convencional mantiene sus propios
      // metadatos confirmados en el guard existente.
      expect(acknowledged.lastPersistedRecord?.userId, 'uid-b');

      now = start.add(const Duration(minutes: 1));

      await writeB(record('uid-b', lastActivityAt: now));

      snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.secondary, isNull);

      // Una autorizacion nueva permite comenzar
      // un intento nuevo de persistencia.
      selection.lock();

      await selectB();
      await sync.waitForIdle();

      snapshot = await journal.readSnapshot();

      expect(sync.restorationUnavailable, isFalse);
      expect(snapshot.active?.userId, 'uid-b');
    });
  });
}
