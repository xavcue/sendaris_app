import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/account_biometric_access_coordinator.dart';
import 'package:sendaris/app/session/account_conventional_access_coordinator.dart';
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

final class _FakeSession implements AccountFirebaseSessionVerifier {
  _FakeSession(this.identity);

  final _FakeIdentity identity;

  int validationCalls = 0;

  @override
  String? get currentUserId => identity.currentUserId;

  @override
  Future<bool> validate({required String expectedUserId}) async {
    validationCalls++;

    return identity.currentUserId == expectedUserId;
  }
}

final class _FakeExit implements AccountSessionExitTarget {
  _FakeExit(this.identity);

  final _FakeIdentity identity;

  int signOutCalls = 0;

  Future<void> Function()? beforeSignOut;

  @override
  String? get currentUserId => identity.currentUserId;

  @override
  Future<void> signOut() async {
    signOutCalls++;

    final callback = beforeSignOut;

    if (callback != null) {
      await callback();
    }

    identity.changeTo(null);
  }
}

void main() {
  late _FakeIdentity primary;
  late _FakeIdentity secondary;

  late _FakeSession primarySession;
  late _FakeSession secondarySession;

  late _FakeExit primaryExit;
  late _FakeExit secondaryExit;

  late AccountSessionSelectionController selection;

  late AccountSessionExitCoordinator exit;
  late AccountConventionalAccessCoordinator conventional;

  setUp(() {
    primary = _FakeIdentity('uid-a');
    secondary = _FakeIdentity(null);

    primarySession = _FakeSession(primary);
    secondarySession = _FakeSession(secondary);

    primaryExit = _FakeExit(primary);
    secondaryExit = _FakeExit(secondary);

    selection = AccountSessionSelectionController(
      primary: primary,
      secondary: secondary,
    );

    exit = AccountSessionExitCoordinator(
      selection: selection,
      linkedSlot: null,
      primary: primaryExit,
      secondary: secondaryExit,
    );

    conventional = AccountConventionalAccessCoordinator(
      selection: selection,
      primarySession: primarySession,
      secondarySession: secondarySession,
    );
  });

  tearDown(() async {
    conventional.dispose();
    exit.dispose();
    selection.dispose();

    await primary.dispose();
    await secondary.dispose();
  });

  Future<bool> authorizeA() {
    return selection.select(
      slot: FirebaseAccountSlot.primary,
      expectedUserId: 'uid-a',
      verifyAccess: () async => true,
    );
  }

  group('Reconfiguracion de las sesiones', () {
    test('activar biometria no revoca el permiso de A', () async {
      expect(await authorizeA(), isTrue);

      exit.configureLinkedSlot(FirebaseAccountSlot.primary);

      conventional.configureLinkedAccount(
        linkedSlot: FirebaseAccountSlot.primary,
      );

      expect(selection.value, isTrue);
      expect(selection.selectedUserId, 'uid-a');

      expect(exit.linkedSlot, FirebaseAccountSlot.primary);

      expect(conventional.linkedSlot, FirebaseAccountSlot.primary);

      expect(primary.currentUserId, 'uid-a');
      expect(primaryExit.signOutCalls, 0);
      expect(secondaryExit.signOutCalls, 0);
    });

    test('cerrar A vinculada conserva su sesion Firebase', () async {
      expect(await authorizeA(), isTrue);

      exit.configureLinkedSlot(FirebaseAccountSlot.primary);

      conventional.configureLinkedAccount(
        linkedSlot: FirebaseAccountSlot.primary,
      );

      expect(await exit.closeActiveSession(), isTrue);

      expect(primary.currentUserId, 'uid-a');
      expect(primaryExit.signOutCalls, 0);
      expect(selection.value, isFalse);
    });

    test('desactivar biometria convierte A '
        'en una sesion convencional', () async {
      expect(await authorizeA(), isTrue);

      exit.configureLinkedSlot(FirebaseAccountSlot.primary);

      conventional.configureLinkedAccount(
        linkedSlot: FirebaseAccountSlot.primary,
      );

      // La desactivacion nativa se verifica
      // por separado antes de esta operacion.
      exit.configureLinkedSlot(null);

      conventional.configureLinkedAccount(linkedSlot: null);

      // La cuenta sigue abierta en Ajustes.
      expect(selection.value, isTrue);
      expect(primary.currentUserId, 'uid-a');

      // Ahora si debe utilizar el cierre
      // convencional cuando el usuario lo pida.
      expect(await exit.closeActiveSession(), isTrue);

      expect(primaryExit.signOutCalls, 1);
      expect(primary.currentUserId, isNull);

      expect(secondaryExit.signOutCalls, 0);
      expect(selection.value, isFalse);
    });

    test('tras vincular A puede autenticarse B '
        'en el contexto convencional', () async {
      exit.configureLinkedSlot(FirebaseAccountSlot.primary);

      conventional.configureLinkedAccount(
        linkedSlot: FirebaseAccountSlot.primary,
      );

      final granted = await conventional.signIn(
        slot: FirebaseAccountSlot.secondary,
        authenticate: () async {
          secondary.changeTo('uid-b');
          return true;
        },
      );

      expect(granted, isTrue);

      expect(selection.selectedSlot, FirebaseAccountSlot.secondary);

      expect(selection.selectedUserId, 'uid-b');

      expect(primary.currentUserId, 'uid-a');
      expect(secondary.currentUserId, 'uid-b');

      expect(primaryExit.signOutCalls, 0);
      expect(secondarySession.validationCalls, 1);
    });

    test('no reconfigura la salida '
        'durante un cierre pendiente', () async {
      secondary.changeTo('uid-b');

      expect(
        await selection.select(
          slot: FirebaseAccountSlot.secondary,
          expectedUserId: 'uid-b',
          verifyAccess: () async => true,
        ),
        isTrue,
      );

      final pending = Completer<void>();

      secondaryExit.beforeSignOut = () => pending.future;

      final operation = exit.closeActiveSession();

      expect(exit.isBusy, isTrue);

      expect(
        () => exit.configureLinkedSlot(FirebaseAccountSlot.primary),
        throwsStateError,
      );

      pending.complete();

      expect(await operation, isTrue);

      expect(exit.linkedSlot, isNull);
      expect(primary.currentUserId, 'uid-a');
      expect(primaryExit.signOutCalls, 0);
    });

    test('no reconfigura el ingreso convencional '
        'durante una autenticacion pendiente', () async {
      final pending = Completer<bool>();

      final operation = conventional.signIn(
        slot: FirebaseAccountSlot.secondary,
        authenticate: () => pending.future,
      );

      expect(conventional.isSigningIn, isTrue);

      expect(
        () => conventional.configureLinkedAccount(
          linkedSlot: FirebaseAccountSlot.primary,
        ),
        throwsStateError,
      );

      pending.complete(false);

      expect(await operation, isFalse);
      expect(conventional.linkedSlot, isNull);

      expect(primary.currentUserId, 'uid-a');
      expect(primaryExit.signOutCalls, 0);
    });
  });
}
