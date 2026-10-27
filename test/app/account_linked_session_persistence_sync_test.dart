import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_active_session_checkpoint.dart';
import 'package:sendaris/app/session/account_linked_session_persistence_sync.dart';
import 'package:sendaris/app/session/account_scoped_session_timeout_store.dart';
import 'package:sendaris/app/session/account_session_persistence_journal.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/linked_account_session_lifecycle_controller.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';

final class _MemoryStorage implements AccountSessionKeyValueStorage {
  final Map<String, String> values = <String, String>{};

  Completer<void>? holdPrimaryWrite;
  Completer<void>? primaryWriteStarted;

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async {
    if (key == 'sendaris.session.dual.primary.v1') {
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

  // B8.10B.6:
  // La identidad simulada permanece constante
  // durante cada prueba.
  final String? _userId;

  final StreamController<String?> _changes =
      StreamController<String?>.broadcast(sync: true);

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> get userIdChanges => _changes.stream;

  Future<void> dispose() => _changes.close();
}

void main() {
  late DateTime now;

  late _MemoryStorage storage;
  late _FakeIdentity identityA;
  late _FakeIdentity identityB;

  late AccountSessionSelectionController selection;
  late LinkedAccountSessionLifecycleController lifecycle;
  late AccountSessionPersistenceJournal journal;
  late AccountLinkedSessionPersistenceSync sync;

  final start = DateTime.utc(2026, 10, 21, 12);

  Future<void> selectA() async {
    final accepted = await selection.select(
      slot: FirebaseAccountSlot.primary,
      expectedUserId: 'uid-a',
      verifyAccess: () async => true,
    );

    expect(accepted, isTrue);
  }

  Future<void> selectB() async {
    final accepted = await selection.select(
      slot: FirebaseAccountSlot.secondary,
      expectedUserId: 'uid-b',
      verifyAccess: () async => true,
    );

    expect(accepted, isTrue);
  }

  setUp(() {
    now = start;

    storage = _MemoryStorage();
    identityA = _FakeIdentity('uid-a');
    identityB = _FakeIdentity('uid-b');

    selection = AccountSessionSelectionController(
      primary: identityA,
      secondary: identityB,
    );

    lifecycle = LinkedAccountSessionLifecycleController(
      selection: selection,
      linkedSlot: FirebaseAccountSlot.primary,
      clock: () => now,
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

    sync = AccountLinkedSessionPersistenceSync(
      selection: selection,
      lifecycle: lifecycle,
      journal: journal,
      linkedSlot: () => FirebaseAccountSlot.primary,
      clock: () => now,
    );
  });

  tearDown(() async {
    sync.dispose();
    lifecycle.dispose();
    journal.dispose();
    selection.dispose();

    await identityA.dispose();
    await identityB.dispose();
  });

  group('AUTH-03 B8.10B.6 - Persistencia de A', () {
    test('no publica A antes de autorizarla', () async {
      expect(await sync.beginAuthorized(), isFalse);

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.primary, isNull);
    });

    test('publica A despues de la autorizacion', () async {
      await selectA();

      expect(await sync.beginAuthorized(), isTrue);

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active?.userId, 'uid-a');
      expect(snapshot.active?.slot, FirebaseAccountSlot.primary);
      expect(snapshot.primary?.userId, 'uid-a');
      expect(snapshot.primary?.startedAt, start);
    });

    test('no escribe cada pulsacion', () async {
      await selectA();
      expect(await sync.beginAuthorized(), isTrue);

      now = start.add(const Duration(seconds: 10));

      lifecycle.registerActivity();

      expect(await sync.persistActivity(), isFalse);

      var snapshot = await journal.readSnapshot();

      expect(snapshot.primary?.lastActivityAt, start);

      now = start.add(const Duration(seconds: 31));

      lifecycle.registerActivity();

      expect(await sync.persistActivity(), isTrue);

      snapshot = await journal.readSnapshot();

      expect(snapshot.primary?.lastActivityAt, now);
      expect(snapshot.primary?.startedAt, start);
    });

    test('minimizar conserva la marca de segundo plano', () async {
      await selectA();
      expect(await sync.beginAuthorized(), isTrue);

      now = start.add(const Duration(minutes: 1));

      lifecycle.enterBackground();

      expect(await sync.persistTransition(), isTrue);

      final snapshot = await journal.readSnapshot();

      expect(snapshot.primary?.backgroundAt, now);
      expect(snapshot.primary?.startedAt, start);
    });

    test('reanudar conserva el inicio absoluto', () async {
      await selectA();
      expect(await sync.beginAuthorized(), isTrue);

      now = start.add(const Duration(minutes: 1));

      lifecycle.enterBackground();

      expect(await sync.persistTransition(), isTrue);

      now = start.add(const Duration(minutes: 5));

      lifecycle.resume();

      expect(await sync.persistTransition(), isTrue);

      final snapshot = await journal.readSnapshot();

      expect(snapshot.primary?.backgroundAt, isNull);
      expect(snapshot.primary?.lastActivityAt, now);
      expect(snapshot.primary?.startedAt, start);
    });

    test('la actividad de B no actualiza la sesion A', () async {
      await selectA();
      expect(await sync.beginAuthorized(), isTrue);

      await selectB();

      now = start.add(const Duration(minutes: 1));

      expect(await sync.persistActivity(), isFalse);
      expect(await sync.persistTransition(), isFalse);

      final snapshot = await journal.readSnapshot();

      expect(snapshot.primary?.lastActivityAt, start);
    });

    test('una sesion A vencida no se actualiza', () async {
      await selectA();
      expect(await sync.beginAuthorized(), isTrue);

      now = start.add(SessionTimeoutPolicy.foregroundIdle);

      lifecycle.checkCurrentValidity();

      expect(selection.value, isFalse);
      expect(await sync.persistActivity(), isFalse);
      expect(await sync.persistTransition(), isFalse);
    });

    test('un cierre manual no permite revivir A', () async {
      await selectA();
      expect(await sync.beginAuthorized(), isTrue);

      selection.lock();

      await journal.revoke(slot: FirebaseAccountSlot.primary, userId: 'uid-a');

      now = start.add(const Duration(minutes: 1));

      expect(await sync.persistActivity(), isFalse);
      expect(await sync.persistTransition(), isFalse);

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.primary, isNull);
    });

    test('una escritura tardia no revive A cerrada', () async {
      await selectA();

      storage.holdPrimaryWrite = Completer<void>();
      storage.primaryWriteStarted = Completer<void>();

      final pendingBegin = sync.beginAuthorized();

      await storage.primaryWriteStarted!.future;

      selection.lock();

      final pendingRevoke = journal.revoke(
        slot: FirebaseAccountSlot.primary,
        userId: 'uid-a',
      );

      storage.holdPrimaryWrite!.complete();

      expect(await pendingBegin, isFalse);
      await pendingRevoke;

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.primary, isNull);
    });

    test('cambiar la vinculacion no concede acceso a B', () async {
      await selectA();
      expect(await sync.beginAuthorized(), isTrue);

      lifecycle.configureLinkedSlot(null);

      expect(await sync.persistActivity(), isFalse);
      expect(await sync.persistTransition(), isFalse);

      // El UID Firebase original sigue existiendo,
      // pero no basta para actualizar A.
      expect(identityA.currentUserId, 'uid-a');
    });
  });
}
