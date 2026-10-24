import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/account_session_exit_coordinator.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';

final class _FakeIdentitySource implements AccountIdentitySource {
  _FakeIdentitySource(this._userId);

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

final class _FakeExitTarget implements AccountSessionExitTarget {
  _FakeExitTarget(this.identity);

  final _FakeIdentitySource identity;

  int signOutCalls = 0;
  bool shouldFail = false;

  Future<void> Function()? beforeSignOut;

  @override
  String? get currentUserId => identity.currentUserId;

  @override
  Future<void> signOut() async {
    signOutCalls++;

    if (shouldFail) {
      throw StateError('Sign-out unavailable');
    }

    final action = beforeSignOut;

    if (action != null) {
      await action();
    }

    identity.changeTo(null);
  }
}

void main() {
  late _FakeIdentitySource primaryIdentity;
  late _FakeIdentitySource secondaryIdentity;

  late _FakeExitTarget primaryTarget;
  late _FakeExitTarget secondaryTarget;

  late AccountSessionSelectionController selection;
  late AccountSessionExitCoordinator coordinator;

  setUp(() {
    primaryIdentity = _FakeIdentitySource('uid-a');
    secondaryIdentity = _FakeIdentitySource('uid-b');

    primaryTarget = _FakeExitTarget(primaryIdentity);
    secondaryTarget = _FakeExitTarget(secondaryIdentity);

    selection = AccountSessionSelectionController(
      primary: primaryIdentity,
      secondary: secondaryIdentity,
    );

    coordinator = AccountSessionExitCoordinator(
      selection: selection,
      linkedSlot: FirebaseAccountSlot.primary,
      primary: primaryTarget,
      secondary: secondaryTarget,
    );
  });

  tearDown(() async {
    coordinator.dispose();
    selection.dispose();

    await primaryIdentity.dispose();
    await secondaryIdentity.dispose();
  });

  Future<bool> authorize(FirebaseAccountSlot slot, String expectedUserId) {
    return selection.select(
      slot: slot,
      expectedUserId: expectedUserId,
      verifyAccess: () async => true,
    );
  }

  group('AccountSessionExitCoordinator', () {
    test('la cuenta A conserva Firebase y la vinculacion', () async {
      expect(await authorize(FirebaseAccountSlot.primary, 'uid-a'), isTrue);

      expect(await coordinator.closeActiveSession(), isTrue);

      expect(primaryIdentity.currentUserId, 'uid-a');
      expect(primaryTarget.signOutCalls, 0);
      expect(secondaryIdentity.currentUserId, 'uid-b');

      expect(selection.value, isFalse);
      expect(selection.selectedSlot, isNull);
    });

    test('cerrar B desconecta solamente su contexto', () async {
      expect(await authorize(FirebaseAccountSlot.secondary, 'uid-b'), isTrue);

      expect(await coordinator.closeActiveSession(), isTrue);

      expect(secondaryTarget.signOutCalls, 1);
      expect(secondaryIdentity.currentUserId, isNull);

      expect(primaryIdentity.currentUserId, 'uid-a');
      expect(primaryTarget.signOutCalls, 0);
      expect(selection.value, isFalse);
    });

    test('permite utilizar B y despues C en el mismo contexto', () async {
      expect(await authorize(FirebaseAccountSlot.secondary, 'uid-b'), isTrue);

      expect(await coordinator.closeActiveSession(), isTrue);

      secondaryIdentity.changeTo('uid-c');

      expect(await authorize(FirebaseAccountSlot.secondary, 'uid-c'), isTrue);

      expect(await coordinator.closeActiveSession(), isTrue);

      expect(secondaryTarget.signOutCalls, 2);
      expect(secondaryIdentity.currentUserId, isNull);
      expect(primaryIdentity.currentUserId, 'uid-a');
    });

    test('no cierra una sesion sin autorizacion privada', () async {
      expect(await coordinator.closeActiveSession(), isFalse);

      expect(primaryTarget.signOutCalls, 0);
      expect(secondaryTarget.signOutCalls, 0);
      expect(selection.value, isFalse);
    });

    test('si Firebase cambio de identidad no cierra otra cuenta', () async {
      expect(await authorize(FirebaseAccountSlot.secondary, 'uid-b'), isTrue);

      secondaryIdentity.changeTo('uid-c');

      expect(await coordinator.closeActiveSession(), isFalse);

      expect(secondaryTarget.signOutCalls, 0);
      expect(secondaryIdentity.currentUserId, 'uid-c');
      expect(selection.value, isFalse);
    });

    test('un error al cerrar B no restablece el permiso', () async {
      expect(await authorize(FirebaseAccountSlot.secondary, 'uid-b'), isTrue);

      secondaryTarget.shouldFail = true;

      expect(await coordinator.closeActiveSession(), isFalse);

      expect(secondaryIdentity.currentUserId, 'uid-b');
      expect(primaryIdentity.currentUserId, 'uid-a');
      expect(selection.value, isFalse);
    });

    test('bloquea B antes de esperar la respuesta de Firebase', () async {
      expect(await authorize(FirebaseAccountSlot.secondary, 'uid-b'), isTrue);

      final pending = Completer<void>();

      secondaryTarget.beforeSignOut = () => pending.future;

      final operation = coordinator.closeActiveSession();

      expect(selection.value, isFalse);
      expect(coordinator.isBusy, isTrue);

      // Una segunda solicitud no puede iniciar
      // otro cierre simultaneo.
      expect(await coordinator.closeActiveSession(), isFalse);

      expect(secondaryTarget.signOutCalls, 1);

      pending.complete();

      expect(await operation, isTrue);
      expect(coordinator.isBusy, isFalse);
      expect(secondaryIdentity.currentUserId, isNull);
    });

    test('sin cuenta biometrica cierra la sesion convencional', () async {
      coordinator.dispose();

      coordinator = AccountSessionExitCoordinator(
        selection: selection,
        linkedSlot: null,
        primary: primaryTarget,
        secondary: secondaryTarget,
      );

      expect(await authorize(FirebaseAccountSlot.primary, 'uid-a'), isTrue);

      expect(await coordinator.closeActiveSession(), isTrue);

      expect(primaryTarget.signOutCalls, 1);
      expect(primaryIdentity.currentUserId, isNull);
    });

    test('la vinculacion puede estar en el contexto secundario', () async {
      coordinator.dispose();

      coordinator = AccountSessionExitCoordinator(
        selection: selection,
        linkedSlot: FirebaseAccountSlot.secondary,
        primary: primaryTarget,
        secondary: secondaryTarget,
      );

      expect(await authorize(FirebaseAccountSlot.secondary, 'uid-b'), isTrue);

      expect(await coordinator.closeActiveSession(), isTrue);

      expect(secondaryIdentity.currentUserId, 'uid-b');
      expect(secondaryTarget.signOutCalls, 0);

      expect(primaryIdentity.currentUserId, 'uid-a');
    });
  });
}
