import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_active_session_checkpoint.dart';
import 'package:sendaris/app/session/account_scoped_session_timeout_store.dart';
import 'package:sendaris/app/session/account_session_persistence_journal.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';

final class _MemoryStorage implements AccountSessionKeyValueStorage {
  final Map<String, String> values = <String, String>{};

  Completer<void>? holdPrimaryWrite;
  Completer<void>? primaryWriteStarted;

  bool failNextPrimaryWrite = false;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    if (key == 'sendaris.session.dual.primary.v1') {
      if (failNextPrimaryWrite) {
        failNextPrimaryWrite = false;
        throw StateError('Error simulado de almacenamiento.');
      }

      final hold = holdPrimaryWrite;

      if (hold != null) {
        final started = primaryWriteStarted;

        if (started != null && !started.isCompleted) {
          started.complete();
        }

        await hold.future;
      }
    }

    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

final class _FakeIdentity implements AccountIdentitySource {
  _FakeIdentity(this._userId);

  String? _userId;

  final StreamController<String?> _changes =
      StreamController<String?>.broadcast(sync: true);

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> get userIdChanges => _changes.stream;

  void changeTo(String? userId) {
    _userId = userId;
    _changes.add(userId);
  }

  Future<void> dispose() => _changes.close();
}

void main() {
  late _MemoryStorage storage;
  late _FakeIdentity accountA;
  late _FakeIdentity accountB;
  late AccountSessionSelectionController selection;
  late AccountSessionPersistenceJournal journal;

  late DateTime start;
  late DateTime now;

  SessionTimeoutRecord record(
    String userId, {
    DateTime? startedAt,
    DateTime? lastActivityAt,
    DateTime? backgroundAt,
  }) {
    return SessionTimeoutRecord(
      userId: userId,
      startedAt: startedAt ?? start,
      lastActivityAt: lastActivityAt ?? start,
      backgroundAt: backgroundAt,
    );
  }

  Future<void> authorizeA() async {
    final result = await selection.select(
      slot: FirebaseAccountSlot.primary,
      expectedUserId: 'uid-a',
      verifyAccess: () async => true,
    );

    expect(result, isTrue);
  }

  Future<void> authorizeB() async {
    accountB.changeTo('uid-b');

    final result = await selection.select(
      slot: FirebaseAccountSlot.secondary,
      expectedUserId: 'uid-b',
      verifyAccess: () async => true,
    );

    expect(result, isTrue);
  }

  setUp(() {
    start = DateTime.utc(2026, 10, 21, 12);
    now = start;

    storage = _MemoryStorage();

    accountA = _FakeIdentity('uid-a');
    accountB = _FakeIdentity(null);

    selection = AccountSessionSelectionController(
      primary: accountA,
      secondary: accountB,
    );

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
  });

  tearDown(() async {
    journal.dispose();
    selection.dispose();

    await accountA.dispose();
    await accountB.dispose();
  });

  group('AUTH-03 B8.10B.3 - Persistencia coordinada', () {
    test('no guarda una cuenta antes de autorizarla', () async {
      expect(
        await journal.commitAuthorized(
          slot: FirebaseAccountSlot.primary,
          record: record('uid-a'),
        ),
        isFalse,
      );

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.primary, isNull);
      expect(snapshot.secondary, isNull);
    });

    test('guarda A solo despues de la seleccion autorizada', () async {
      await authorizeA();

      expect(
        await journal.commitAuthorized(
          slot: FirebaseAccountSlot.primary,
          record: record('uid-a'),
        ),
        isTrue,
      );

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active?.slot, FirebaseAccountSlot.primary);
      expect(snapshot.active?.userId, 'uid-a');
      expect(snapshot.primary?.userId, 'uid-a');
      expect(snapshot.secondary, isNull);
    });

    test('cambiar a B conserva separados ambos registros', () async {
      await authorizeA();

      expect(
        await journal.commitAuthorized(
          slot: FirebaseAccountSlot.primary,
          record: record('uid-a'),
        ),
        isTrue,
      );

      selection.lock();
      await authorizeB();

      now = start.add(const Duration(minutes: 2));

      expect(
        await journal.commitAuthorized(
          slot: FirebaseAccountSlot.secondary,
          record: record('uid-b', startedAt: now, lastActivityAt: now),
        ),
        isTrue,
      );

      final snapshot = await journal.readSnapshot();

      expect(snapshot.primary?.userId, 'uid-a');
      expect(snapshot.secondary?.userId, 'uid-b');
      expect(snapshot.active?.slot, FirebaseAccountSlot.secondary);
      expect(snapshot.active?.userId, 'uid-b');
    });

    test('cerrar A no elimina la seleccion vigente de B', () async {
      await authorizeA();

      await journal.commitAuthorized(
        slot: FirebaseAccountSlot.primary,
        record: record('uid-a'),
      );

      selection.lock();
      await authorizeB();

      await journal.commitAuthorized(
        slot: FirebaseAccountSlot.secondary,
        record: record('uid-b'),
      );

      await journal.revoke(slot: FirebaseAccountSlot.primary, userId: 'uid-a');

      final snapshot = await journal.readSnapshot();

      expect(snapshot.primary, isNull);
      expect(snapshot.secondary?.userId, 'uid-b');
      expect(snapshot.active?.userId, 'uid-b');

      expect(selection.value, isTrue);
      expect(selection.selectedSlot, FirebaseAccountSlot.secondary);
    });

    test('cerrar A elimina su punto de restauracion', () async {
      await authorizeA();

      await journal.commitAuthorized(
        slot: FirebaseAccountSlot.primary,
        record: record('uid-a'),
      );

      selection.lock();

      await journal.revoke(slot: FirebaseAccountSlot.primary, userId: 'uid-a');

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.primary, isNull);

      // Revocar el acceso privado no desconecta Firebase.
      expect(accountA.currentUserId, 'uid-a');
    });

    test('una escritura retrasada no revive una sesion cerrada', () async {
      await authorizeA();

      storage.holdPrimaryWrite = Completer<void>();
      storage.primaryWriteStarted = Completer<void>();

      final pendingCommit = journal.commitAuthorized(
        slot: FirebaseAccountSlot.primary,
        record: record('uid-a'),
      );

      await storage.primaryWriteStarted!.future;

      // El cierre bloquea inmediatamente la interfaz.
      selection.lock();

      // La eliminacion queda detras de la escritura
      // dentro de la misma cola de persistencia.
      final pendingRevoke = journal.revoke(
        slot: FirebaseAccountSlot.primary,
        userId: 'uid-a',
      );

      storage.holdPrimaryWrite!.complete();

      expect(await pendingCommit, isFalse);

      await pendingRevoke;

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.primary, isNull);
      expect(accountA.currentUserId, 'uid-a');
    });

    test('no permite extender la duracion absoluta', () async {
      await authorizeA();

      await journal.commitAuthorized(
        slot: FirebaseAccountSlot.primary,
        record: record('uid-a'),
      );

      now = start.add(const Duration(minutes: 10));

      expect(
        await journal.updateAuthorized(
          slot: FirebaseAccountSlot.primary,
          record: record('uid-a', startedAt: now, lastActivityAt: now),
        ),
        isFalse,
      );

      final snapshot = await journal.readSnapshot();

      expect(snapshot.primary?.startedAt, start);
      expect(snapshot.active?.userId, 'uid-a');
    });

    test('actualiza actividad sin cambiar la fecha inicial', () async {
      await authorizeA();

      await journal.commitAuthorized(
        slot: FirebaseAccountSlot.primary,
        record: record('uid-a'),
      );

      now = start.add(const Duration(minutes: 20));

      expect(
        await journal.updateAuthorized(
          slot: FirebaseAccountSlot.primary,
          record: record('uid-a', lastActivityAt: now),
        ),
        isTrue,
      );

      final snapshot = await journal.readSnapshot();

      expect(snapshot.primary?.startedAt, start);
      expect(snapshot.primary?.lastActivityAt, now);
      expect(snapshot.active?.userId, 'uid-a');
    });

    test('rechaza una sesion vencida antes de persistirla', () async {
      await authorizeA();

      now = start.add(SessionTimeoutPolicy.foregroundIdle);

      expect(
        await journal.commitAuthorized(
          slot: FirebaseAccountSlot.primary,
          record: record('uid-a'),
        ),
        isFalse,
      );

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.primary, isNull);
    });

    test('una escritura fallida no bloquea la cola posterior', () async {
      await authorizeA();

      storage.failNextPrimaryWrite = true;

      await expectLater(
        journal.commitAuthorized(
          slot: FirebaseAccountSlot.primary,
          record: record('uid-a'),
        ),
        throwsStateError,
      );

      var snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.primary, isNull);

      expect(
        await journal.commitAuthorized(
          slot: FirebaseAccountSlot.primary,
          record: record('uid-a'),
        ),
        isTrue,
      );

      snapshot = await journal.readSnapshot();

      expect(snapshot.active?.userId, 'uid-a');
      expect(snapshot.primary?.userId, 'uid-a');
    });

    test('la invalidacion global elimina los candidatos', () async {
      await authorizeA();

      await journal.commitAuthorized(
        slot: FirebaseAccountSlot.primary,
        record: record('uid-a'),
      );

      await journal.clearAll();

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.primary, isNull);
      expect(snapshot.secondary, isNull);
    });
  });
}
