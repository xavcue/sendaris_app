import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_active_session_checkpoint.dart';
import 'package:sendaris/app/session/account_scoped_session_timeout_store.dart';
import 'package:sendaris/app/session/account_session_exit_coordinator.dart';
import 'package:sendaris/app/session/account_session_persistence_journal.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';

final class _TestIdentity implements AccountIdentitySource {
  _TestIdentity(this._userId);

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

final class _TestExitTarget implements AccountSessionExitTarget {
  _TestExitTarget(this.identity);

  final _TestIdentity identity;

  int signOutCalls = 0;

  @override
  String? get currentUserId => identity.currentUserId;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    identity.changeTo(null);
  }
}

final class _TestSessionStorage implements AccountSessionKeyValueStorage {
  final Map<String, String> values = <String, String>{};

  Completer<void>? holdPrimaryWrite;
  Completer<void>? primaryWriteStarted;

  Completer<void>? holdActiveRemoval;
  Completer<void>? activeRemovalStarted;

  bool failActiveRemoval = false;

  @override
  Future<String?> getString(String key) async {
    return values[key];
  }

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
    if (key == 'sendaris.session.dual.active.v1') {
      if (failActiveRemoval) {
        throw StateError('Fallo simulado al invalidar la sesion.');
      }

      final hold = holdActiveRemoval;

      if (hold != null) {
        final started = activeRemovalStarted;

        if (started != null && !started.isCompleted) {
          started.complete();
        }

        await hold.future;
      }
    }

    values.remove(key);
  }
}

void main() {
  late _TestIdentity accountA;
  late _TestIdentity accountB;

  late _TestExitTarget targetA;
  late _TestExitTarget targetB;

  late _TestSessionStorage storage;

  late AccountSessionSelectionController selection;
  late AccountSessionPersistenceJournal journal;
  late AccountSessionExitCoordinator exit;

  late DateTime start;
  late DateTime now;

  SessionTimeoutRecord record(
    String userId, {
    DateTime? startedAt,
    DateTime? lastActivityAt,
  }) {
    return SessionTimeoutRecord(
      userId: userId,
      startedAt: startedAt ?? start,
      lastActivityAt: lastActivityAt ?? start,
    );
  }

  Future<void> selectAccount(FirebaseAccountSlot slot, String userId) async {
    final accepted = await selection.select(
      slot: slot,
      expectedUserId: userId,
      verifyAccess: () async => true,
    );

    expect(accepted, isTrue);
  }

  Future<void> saveAccount(FirebaseAccountSlot slot, String userId) async {
    final accepted = await journal.commitAuthorized(
      slot: slot,
      record: record(userId, startedAt: now, lastActivityAt: now),
    );

    expect(accepted, isTrue);
  }

  setUp(() {
    start = DateTime.utc(2026, 10, 21, 12);
    now = start;

    accountA = _TestIdentity('uid-a');
    accountB = _TestIdentity('uid-b');

    targetA = _TestExitTarget(accountA);
    targetB = _TestExitTarget(accountB);

    storage = _TestSessionStorage();

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

    exit = AccountSessionExitCoordinator(
      selection: selection,
      linkedSlot: FirebaseAccountSlot.primary,
      primary: targetA,
      secondary: targetB,
      beforeExit: (FirebaseAccountSlot slot, String userId) {
        return journal.revoke(slot: slot, userId: userId);
      },
    );
  });

  tearDown(() async {
    exit.dispose();
    journal.dispose();
    selection.dispose();

    await accountA.dispose();
    await accountB.dispose();
  });

  group('AUTH-03 B8.10B.4 - Cierre persistente', () {
    test('cerrar A borra su restauracion y conserva Firebase', () async {
      await selectAccount(FirebaseAccountSlot.primary, 'uid-a');

      await saveAccount(FirebaseAccountSlot.primary, 'uid-a');

      expect(await exit.closeActiveSession(), isTrue);

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.primary, isNull);

      expect(accountA.currentUserId, 'uid-a');

      expect(targetA.signOutCalls, 0);
      expect(targetB.signOutCalls, 0);
      expect(selection.value, isFalse);
    });

    test('cerrar B borra su restauracion y desconecta solo B', () async {
      await selectAccount(FirebaseAccountSlot.primary, 'uid-a');

      await saveAccount(FirebaseAccountSlot.primary, 'uid-a');

      selection.lock();

      now = start.add(const Duration(minutes: 1));

      await selectAccount(FirebaseAccountSlot.secondary, 'uid-b');

      await saveAccount(FirebaseAccountSlot.secondary, 'uid-b');

      expect(await exit.closeActiveSession(), isTrue);

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.secondary, isNull);

      // El registro de A no debe eliminarse
      // al cerrar una cuenta convencional.
      expect(snapshot.primary?.userId, 'uid-a');

      expect(accountA.currentUserId, 'uid-a');

      expect(accountB.currentUserId, isNull);

      expect(targetA.signOutCalls, 0);
      expect(targetB.signOutCalls, 1);
      expect(selection.value, isFalse);
    });

    test('una escritura pendiente no revive A tras cerrar', () async {
      await selectAccount(FirebaseAccountSlot.primary, 'uid-a');

      storage.holdPrimaryWrite = Completer<void>();
      storage.primaryWriteStarted = Completer<void>();

      final pendingCommit = journal.commitAuthorized(
        slot: FirebaseAccountSlot.primary,
        record: record('uid-a'),
      );

      await storage.primaryWriteStarted!.future;

      final pendingExit = exit.closeActiveSession();

      // El acceso privado se bloquea sin
      // esperar al almacenamiento.
      expect(selection.value, isFalse);

      storage.holdPrimaryWrite!.complete();

      expect(await pendingCommit, isFalse);
      expect(await pendingExit, isTrue);

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.primary, isNull);

      expect(accountA.currentUserId, 'uid-a');
    });

    test('un fallo al invalidar deja bloqueada la cuenta', () async {
      await selectAccount(FirebaseAccountSlot.secondary, 'uid-b');

      await saveAccount(FirebaseAccountSlot.secondary, 'uid-b');

      storage.failActiveRemoval = true;

      expect(await exit.closeActiveSession(), isFalse);

      expect(selection.value, isFalse);
      expect(exit.isBusy, isFalse);

      // No desconectar Firebase antes de confirmar
      // la invalidacion persistente.
      expect(accountB.currentUserId, 'uid-b');
      expect(targetB.signOutCalls, 0);
    });

    test('no admite dos cierres simultaneos', () async {
      await selectAccount(FirebaseAccountSlot.primary, 'uid-a');

      await saveAccount(FirebaseAccountSlot.primary, 'uid-a');

      storage.holdActiveRemoval = Completer<void>();
      storage.activeRemovalStarted = Completer<void>();

      final pendingExit = exit.closeActiveSession();

      await storage.activeRemovalStarted!.future;

      expect(selection.value, isFalse);
      expect(exit.isBusy, isTrue);

      expect(await exit.closeActiveSession(), isFalse);

      storage.holdActiveRemoval!.complete();

      expect(await pendingExit, isTrue);
      expect(exit.isBusy, isFalse);

      final snapshot = await journal.readSnapshot();

      expect(snapshot.active, isNull);
      expect(snapshot.primary, isNull);
    });

    test('si cambia el UID durante la limpieza no cierra otro', () async {
      await selectAccount(FirebaseAccountSlot.secondary, 'uid-b');

      await saveAccount(FirebaseAccountSlot.secondary, 'uid-b');

      storage.holdActiveRemoval = Completer<void>();
      storage.activeRemovalStarted = Completer<void>();

      final pendingExit = exit.closeActiveSession();

      await storage.activeRemovalStarted!.future;

      // Firebase cambia de identidad mientras
      // la limpieza del usuario anterior espera.
      accountB.changeTo('uid-c');

      storage.holdActiveRemoval!.complete();

      expect(await pendingExit, isFalse);

      expect(targetB.signOutCalls, 0);
      expect(accountB.currentUserId, 'uid-c');
      expect(accountA.currentUserId, 'uid-a');
      expect(selection.value, isFalse);
    });
  });
}
