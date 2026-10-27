import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/account_biometric_access_coordinator.dart';
import 'package:sendaris/app/session/account_conventional_access_coordinator.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';

final class _IdentitySource implements AccountIdentitySource {
  _IdentitySource(this._userId);

  final StreamController<String?> _changes =
      StreamController<String?>.broadcast(sync: true);

  String? _userId;

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

final class _SessionVerifier implements AccountFirebaseSessionVerifier {
  _SessionVerifier(this.identity);

  final _IdentitySource identity;

  bool valid = true;
  int validationCalls = 0;

  Future<bool> Function()? validation;

  @override
  String? get currentUserId => identity.currentUserId;

  @override
  Future<bool> validate({required String expectedUserId}) async {
    validationCalls++;

    final result = validation == null ? valid : await validation!();

    return result && identity.currentUserId == expectedUserId;
  }
}

void main() {
  late _IdentitySource primary;
  late _IdentitySource secondary;

  late _SessionVerifier primaryVerifier;
  late _SessionVerifier secondaryVerifier;

  late AccountSessionSelectionController selection;
  late AccountConventionalAccessCoordinator coordinator;

  setUp(() {
    // A permanece en la instancia secundaria.
    // El contexto primario esta libre para B, C, D...
    primary = _IdentitySource(null);
    secondary = _IdentitySource('uid-a');

    primaryVerifier = _SessionVerifier(primary);
    secondaryVerifier = _SessionVerifier(secondary);

    selection = AccountSessionSelectionController(
      primary: primary,
      secondary: secondary,
    );

    coordinator = AccountConventionalAccessCoordinator(
      selection: selection,
      primarySession: primaryVerifier,
      secondarySession: secondaryVerifier,
    );
  });

  tearDown(() async {
    coordinator.dispose();
    selection.dispose();

    await primary.dispose();
    await secondary.dispose();
  });

  void configureLinkedAccount({DuplicateConventionalSessionRelease? release}) {
    coordinator.dispose();

    coordinator = AccountConventionalAccessCoordinator(
      selection: selection,
      primarySession: primaryVerifier,
      secondarySession: secondaryVerifier,
      linkedSlot: FirebaseAccountSlot.secondary,
      releaseDuplicateSession: release,
    );
  }

  Future<bool> signInB() {
    return coordinator.signIn(
      slot: FirebaseAccountSlot.primary,
      authenticate: () async {
        primary.changeTo('uid-b');
        return true;
      },
    );
  }

  Future<bool> signInAConventionally() {
    return coordinator.signIn(
      slot: FirebaseAccountSlot.primary,
      authenticate: () async {
        primary.changeTo('uid-a');
        return true;
      },
    );
  }

  group('AccountConventionalAccessCoordinator', () {
    test('autoriza B sin desconectar A', () async {
      expect(await signInB(), isTrue);

      expect(primary.currentUserId, 'uid-b');
      expect(secondary.currentUserId, 'uid-a');

      expect(selection.value, isTrue);
      expect(selection.selectedSlot, FirebaseAccountSlot.primary);
      expect(selection.selectedUserId, 'uid-b');
      expect(primaryVerifier.validationCalls, 1);
    });

    test('permite utilizar el contexto secundario '
        'si el principal conserva A', () async {
      primary.changeTo('uid-a');
      secondary.changeTo(null);

      final result = await coordinator.signIn(
        slot: FirebaseAccountSlot.secondary,
        authenticate: () async {
          secondary.changeTo('uid-b');
          return true;
        },
      );

      expect(result, isTrue);
      expect(primary.currentUserId, 'uid-a');
      expect(secondary.currentUserId, 'uid-b');

      expect(selection.selectedSlot, FirebaseAccountSlot.secondary);
    });

    test('no autoriza una sesion convencional '
        'restaurada automaticamente', () async {
      primary.changeTo('uid-b');

      var authenticationCalled = false;

      final result = await coordinator.signIn(
        slot: FirebaseAccountSlot.primary,
        authenticate: () async {
          authenticationCalled = true;
          return true;
        },
      );

      expect(result, isFalse);
      expect(authenticationCalled, isFalse);
      expect(selection.value, isFalse);
    });

    test('un login fallido no concede acceso', () async {
      final result = await coordinator.signIn(
        slot: FirebaseAccountSlot.primary,
        authenticate: () async => false,
      );

      expect(result, isFalse);
      expect(selection.value, isFalse);
      expect(primaryVerifier.validationCalls, 0);
    });

    test('Firebase debe validar la sesion', () async {
      primaryVerifier.valid = false;

      expect(await signInB(), isFalse);
      expect(primaryVerifier.validationCalls, 1);
      expect(selection.value, isFalse);
    });

    test('una excepcion mantiene el acceso bloqueado', () async {
      final result = await coordinator.signIn(
        slot: FirebaseAccountSlot.primary,
        authenticate: () async {
          throw StateError('Authentication unavailable');
        },
      );

      expect(result, isFalse);
      expect(selection.value, isFalse);
      expect(coordinator.isSigningIn, isFalse);
    });

    test('cancelar un login pendiente '
        'rechaza el resultado', () async {
      final pending = Completer<bool>();

      final operation = coordinator.signIn(
        slot: FirebaseAccountSlot.primary,
        authenticate: () => pending.future,
      );

      expect(coordinator.isSigningIn, isTrue);

      coordinator.cancelAndLock();

      primary.changeTo('uid-b');
      pending.complete(true);

      expect(await operation, isFalse);
      expect(selection.value, isFalse);
    });

    test('cancelar durante la validacion Firebase '
        'rechaza el acceso', () async {
      final pending = Completer<bool>();

      primaryVerifier.validation = () => pending.future;

      final operation = signInB();

      await Future<void>.delayed(Duration.zero);

      expect(coordinator.isSigningIn, isTrue);
      expect(selection.value, isFalse);

      coordinator.cancelAndLock();
      pending.complete(true);

      expect(await operation, isFalse);
      expect(selection.value, isFalse);
    });

    test('no admite solicitudes simultaneas', () async {
      final pending = Completer<bool>();

      final first = coordinator.signIn(
        slot: FirebaseAccountSlot.primary,
        authenticate: () => pending.future,
      );

      var secondCalled = false;

      final second = await coordinator.signIn(
        slot: FirebaseAccountSlot.primary,
        authenticate: () async {
          secondCalled = true;
          return true;
        },
      );

      expect(second, isFalse);
      expect(secondCalled, isFalse);

      pending.complete(false);

      expect(await first, isFalse);
      expect(coordinator.isSigningIn, isFalse);
    });

    test('revoca A antes de autenticar B', () async {
      final previousAccess = await selection.select(
        slot: FirebaseAccountSlot.secondary,
        expectedUserId: 'uid-a',
        verifyAccess: () async => true,
      );

      expect(previousAccess, isTrue);

      final pending = Completer<bool>();

      final operation = coordinator.signIn(
        slot: FirebaseAccountSlot.primary,
        authenticate: () => pending.future,
      );

      expect(selection.value, isFalse);
      expect(selection.selectedSlot, isNull);

      primary.changeTo('uid-b');
      pending.complete(true);

      expect(await operation, isTrue);
      expect(selection.selectedSlot, FirebaseAccountSlot.primary);
      expect(selection.selectedUserId, 'uid-b');
    });

    test('A puede ingresar con credenciales y '
        'recuperar su contexto reservado', () async {
      var releases = 0;

      configureLinkedAccount(
        release: (slot, expectedUserId) async {
          releases++;

          expect(slot, FirebaseAccountSlot.primary);
          expect(expectedUserId, 'uid-a');
          expect(primary.currentUserId, 'uid-a');

          primary.changeTo(null);

          return true;
        },
      );

      expect(await signInAConventionally(), isTrue);

      expect(releases, 1);
      expect(primary.currentUserId, isNull);
      expect(secondary.currentUserId, 'uid-a');

      expect(selection.value, isTrue);
      expect(selection.selectedSlot, FirebaseAccountSlot.secondary);
      expect(selection.selectedUserId, 'uid-a');

      // Ambas sesiones fueron verificadas remotamente.
      expect(primaryVerifier.validationCalls, 1);
      expect(secondaryVerifier.validationCalls, 2);
    });

    test('sin liberacion del duplicado '
        'no autoriza A', () async {
      configureLinkedAccount();

      expect(await signInAConventionally(), isFalse);

      expect(primary.currentUserId, 'uid-a');
      expect(secondary.currentUserId, 'uid-a');
      expect(selection.value, isFalse);
    });

    test('si A reservada no supera la validacion '
        'no se libera el duplicado', () async {
      var releases = 0;

      secondaryVerifier.valid = false;

      configureLinkedAccount(
        release: (_, _) async {
          releases++;
          primary.changeTo(null);
          return true;
        },
      );

      expect(await signInAConventionally(), isFalse);

      expect(releases, 0);
      expect(primary.currentUserId, 'uid-a');
      expect(secondary.currentUserId, 'uid-a');
      expect(selection.value, isFalse);
    });

    test('una liberacion fallida no autoriza A', () async {
      configureLinkedAccount(release: (_, _) async => false);

      expect(await signInAConventionally(), isFalse);

      expect(primary.currentUserId, 'uid-a');
      expect(secondary.currentUserId, 'uid-a');
      expect(selection.value, isFalse);
    });

    test('cancelar durante la liberacion '
        'rechaza la autorizacion antigua', () async {
      final pending = Completer<bool>();

      configureLinkedAccount(
        release: (_, _) async {
          final result = await pending.future;

          if (result) {
            primary.changeTo(null);
          }

          return result;
        },
      );

      final operation = signInAConventionally();

      await Future<void>.delayed(Duration.zero);

      expect(coordinator.isSigningIn, isTrue);

      coordinator.cancelAndLock();
      pending.complete(true);

      expect(await operation, isFalse);
      expect(selection.value, isFalse);
      expect(secondary.currentUserId, 'uid-a');
    });
  });
}
