import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/account_duplicate_session_release.dart';
import 'package:sendaris/app/session/account_session_exit_coordinator.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';

final class _FakeIdentity implements AccountIdentitySource {
  _FakeIdentity(this._userId);

  String? _userId;

  final _changes = StreamController<String?>.broadcast(sync: true);

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

final class _FakeExitTarget implements AccountSessionExitTarget {
  _FakeExitTarget(this.identity);

  final _FakeIdentity identity;

  int signOutCalls = 0;
  bool fail = false;
  Future<void> Function()? onSignOut;

  @override
  String? get currentUserId => identity.currentUserId;

  @override
  Future<void> signOut() async {
    signOutCalls++;

    if (fail) {
      throw StateError('Firebase signOut failed');
    }

    final action = onSignOut;

    if (action != null) {
      await action();
    } else {
      identity.changeTo(null);
    }
  }
}

void main() {
  late _FakeIdentity primaryIdentity;
  late _FakeIdentity secondaryIdentity;

  late _FakeExitTarget primaryTarget;
  late _FakeExitTarget secondaryTarget;

  late AccountSessionSelectionController selection;
  late AccountDuplicateSessionRelease release;

  setUp(() {
    // A ya esta conservada para biometria
    // en el contexto secundario.
    //
    // Se acaba de iniciar A tambien mediante
    // credenciales en el contexto principal.
    primaryIdentity = _FakeIdentity('uid-a');
    secondaryIdentity = _FakeIdentity('uid-a');

    primaryTarget = _FakeExitTarget(primaryIdentity);
    secondaryTarget = _FakeExitTarget(secondaryIdentity);

    selection = AccountSessionSelectionController(
      primary: primaryIdentity,
      secondary: secondaryIdentity,
    );

    release = AccountDuplicateSessionRelease(
      selection: selection,
      linkedSlot: FirebaseAccountSlot.secondary,
      primary: primaryTarget,
      secondary: secondaryTarget,
    );
  });

  tearDown(() async {
    release.dispose();
    selection.dispose();

    await primaryIdentity.dispose();
    await secondaryIdentity.dispose();
  });

  Future<bool> releasePrimary() {
    return release.release(FirebaseAccountSlot.primary, 'uid-a');
  }

  group('AccountDuplicateSessionRelease', () {
    test('libera el duplicado y conserva A vinculada', () async {
      expect(await releasePrimary(), isTrue);

      expect(primaryTarget.signOutCalls, 1);
      expect(primaryIdentity.currentUserId, isNull);

      expect(secondaryTarget.signOutCalls, 0);
      expect(secondaryIdentity.currentUserId, 'uid-a');
      expect(selection.value, isFalse);
    });

    test('funciona tambien cuando A esta en primary', () async {
      release.dispose();

      release = AccountDuplicateSessionRelease(
        selection: selection,
        linkedSlot: FirebaseAccountSlot.primary,
        primary: primaryTarget,
        secondary: secondaryTarget,
      );

      final result = await release.release(
        FirebaseAccountSlot.secondary,
        'uid-a',
      );

      expect(result, isTrue);

      expect(primaryIdentity.currentUserId, 'uid-a');
      expect(primaryTarget.signOutCalls, 0);

      expect(secondaryIdentity.currentUserId, isNull);
      expect(secondaryTarget.signOutCalls, 1);
    });

    test('rechaza cerrar el contexto reservado', () async {
      final result = await release.release(
        FirebaseAccountSlot.secondary,
        'uid-a',
      );

      expect(result, isFalse);
      expect(primaryTarget.signOutCalls, 0);
      expect(secondaryTarget.signOutCalls, 0);
    });

    test('rechaza identificadores incorrectos', () async {
      for (final userId in <String>['', 'uid-b', ' uid-a', 'uid-a ']) {
        final result = await release.release(
          FirebaseAccountSlot.primary,
          userId,
        );

        expect(result, isFalse);
      }

      expect(primaryTarget.signOutCalls, 0);
      expect(secondaryTarget.signOutCalls, 0);
    });

    test('no cierra B si A esta vinculada', () async {
      primaryIdentity.changeTo('uid-b');

      final result = await release.release(
        FirebaseAccountSlot.primary,
        'uid-a',
      );

      expect(result, isFalse);
      expect(primaryIdentity.currentUserId, 'uid-b');
      expect(primaryTarget.signOutCalls, 0);
      expect(secondaryIdentity.currentUserId, 'uid-a');
    });

    test('rechaza una identidad reservada distinta', () async {
      secondaryIdentity.changeTo('uid-c');

      expect(await releasePrimary(), isFalse);

      expect(primaryTarget.signOutCalls, 0);
      expect(secondaryTarget.signOutCalls, 0);
    });

    test('un fallo de Firebase no modifica A', () async {
      primaryTarget.fail = true;

      expect(await releasePrimary(), isFalse);

      expect(primaryTarget.signOutCalls, 1);
      expect(primaryIdentity.currentUserId, 'uid-a');
      expect(secondaryIdentity.currentUserId, 'uid-a');
      expect(selection.value, isFalse);
    });

    test('no permite liberaciones simultaneas', () async {
      final pending = Completer<void>();

      primaryTarget.onSignOut = () async {
        await pending.future;
        primaryIdentity.changeTo(null);
      };

      final first = releasePrimary();

      expect(release.isBusy, isTrue);

      final second = await releasePrimary();

      expect(second, isFalse);
      expect(primaryTarget.signOutCalls, 1);

      pending.complete();

      expect(await first, isTrue);
      expect(release.isBusy, isFalse);
    });

    test('detecta A -> C -> A en la cuenta reservada', () async {
      final pending = Completer<void>();

      primaryTarget.onSignOut = () async {
        await pending.future;
        primaryIdentity.changeTo(null);
      };

      final operation = releasePrimary();

      secondaryIdentity.changeTo('uid-c');
      secondaryIdentity.changeTo('uid-a');

      pending.complete();

      expect(await operation, isFalse);

      // La cuenta vinculada nunca se desconecto.
      expect(secondaryTarget.signOutCalls, 0);
      expect(secondaryIdentity.currentUserId, 'uid-a');
      expect(selection.value, isFalse);
    });

    test('detecta A -> C -> A en el duplicado', () async {
      final pending = Completer<void>();

      primaryTarget.onSignOut = () async {
        await pending.future;
        primaryIdentity.changeTo(null);
      };

      final operation = releasePrimary();

      primaryIdentity.changeTo('uid-c');
      primaryIdentity.changeTo('uid-a');

      pending.complete();

      expect(await operation, isFalse);
      expect(secondaryIdentity.currentUserId, 'uid-a');
      expect(selection.value, isFalse);
    });

    test('rechaza una nueva identidad tras desconectar', () async {
      final pending = Completer<void>();

      primaryTarget.onSignOut = () async {
        primaryIdentity.changeTo(null);

        await pending.future;

        primaryIdentity.changeTo('uid-a');
        primaryIdentity.changeTo(null);
      };

      final operation = releasePrimary();

      pending.complete();

      expect(await operation, isFalse);
      expect(secondaryIdentity.currentUserId, 'uid-a');
    });

    test('dispose invalida una liberacion pendiente', () async {
      final pending = Completer<void>();

      primaryTarget.onSignOut = () async {
        await pending.future;
        primaryIdentity.changeTo(null);
      };

      final operation = releasePrimary();

      release.dispose();
      pending.complete();

      expect(await operation, isFalse);
      expect(secondaryIdentity.currentUserId, 'uid-a');
      expect(selection.value, isFalse);
    });
  });
}
