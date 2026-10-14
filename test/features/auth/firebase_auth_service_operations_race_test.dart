import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/data/services/firebase_auth_service.dart';

void main() {
  group('FirebaseAuthService - operaciones pendientes del SDK', () {
    late _ControlledUser userA;
    late _ControlledUser userB;
    late _ControlledFirebaseAuth auth;
    late FirebaseAuthService service;

    setUp(() {
      userA = _ControlledUser('uid-a');
      userB = _ControlledUser('uid-b');
      auth = _ControlledFirebaseAuth(userA, signInUser: userB);
      service = FirebaseAuthService(auth);
    });

    tearDown(() async {
      await auth.dispose();
    });

    test('una recarga vigente renueva el token de A', () async {
      await service.reloadCurrentUser();

      expect(userA.reloadCalls, 1);
      expect(userA.tokenRequests, [true]);
      expect(userB.reloadCalls, 0);
      expect(userB.tokenRequests, isEmpty);
      expect(auth.currentUser?.uid, 'uid-a');
    });

    test('cambiar a B durante reload impide renovar el token de A', () async {
      userA.reloadGate = Completer<void>();

      final operation = service.reloadCurrentUser();
      await userA.reloadStarted.future;

      auth.changeUser(userB);
      userA.reloadGate!.complete();
      await operation;

      expect(userA.tokenRequests, isEmpty);
      expect(userB.reloadCalls, 0);
      expect(userB.tokenRequests, isEmpty);
      expect(auth.currentUser?.uid, 'uid-b');
    });

    test('A a B a A durante reload invalida la recarga anterior', () async {
      userA.reloadGate = Completer<void>();

      final operation = service.reloadCurrentUser();
      await userA.reloadStarted.future;

      auth.changeUser(userB);
      auth.changeUser(userA);
      userA.reloadGate!.complete();
      await operation;

      expect(userA.tokenRequests, isEmpty);
      expect(userB.tokenRequests, isEmpty);
      expect(auth.currentUser?.uid, 'uid-a');
    });

    test('el token pendiente de A no confirma la verificacion en B', () async {
      userA.verified = true;
      userA.tokenGate = Completer<String?>();

      final operation = service.refreshCurrentUserEmailVerificationStatus();
      await userA.tokenStarted.future;

      auth.changeUser(userB);
      userA.tokenGate!.complete('token-ficticio-a');

      expect(await operation, isFalse);
      expect(userA.tokenRequests, [true]);
      expect(userB.tokenRequests, isEmpty);
      expect(auth.currentUser?.uid, 'uid-b');
    });

    test(
      'A a B a A durante el token no recupera el resultado anterior',
      () async {
        userA.verified = true;
        userA.tokenGate = Completer<String?>();

        final operation = service.refreshCurrentUserEmailVerificationStatus();
        await userA.tokenStarted.future;

        auth.changeUser(userB);
        auth.changeUser(userA);
        userA.tokenGate!.complete('token-ficticio-anterior');

        expect(await operation, isFalse);
        expect(userA.tokenRequests, [true]);
        expect(userB.tokenRequests, isEmpty);
        expect(auth.currentUser?.uid, 'uid-a');
      },
    );

    test('el envio vigente verifica exclusivamente el correo de A', () async {
      await service.sendCurrentUserEmailVerification();

      expect(auth.languageCodes, ['es-419']);
      expect(userA.verificationCalls, 1);
      expect(userB.verificationCalls, 0);
      expect(auth.currentUser?.uid, 'uid-a');
    });

    test('cambiar a B antes del envio invalida la solicitud de A', () async {
      auth.languageGate = Completer<void>();

      final operation = service.sendCurrentUserEmailVerification();
      final checked = expectLater(operation, throwsA(isA<StateError>()));
      await auth.languageStarted.future;

      auth.changeUser(userB);
      auth.languageGate!.complete();
      await checked;

      expect(userA.verificationCalls, 0);
      expect(userB.verificationCalls, 0);
      expect(auth.currentUser?.uid, 'uid-b');
    });

    test(
      'A a B a A antes del envio no reutiliza la solicitud antigua',
      () async {
        auth.languageGate = Completer<void>();

        final operation = service.sendCurrentUserEmailVerification();
        final checked = expectLater(operation, throwsA(isA<StateError>()));
        await auth.languageStarted.future;

        auth.changeUser(userB);
        auth.changeUser(userA);
        auth.languageGate!.complete();
        await checked;

        expect(userA.verificationCalls, 0);
        expect(userB.verificationCalls, 0);
        expect(auth.currentUser?.uid, 'uid-a');
      },
    );

    test('un cierre sin operaciones competidoras termina la sesion', () async {
      await service.signOut();

      expect(auth.signOutCalls, 1);
      expect(auth.currentUser, isNull);
    });

    test('un cierre pendiente no elimina el acceso posterior de B', () async {
      auth.signOutGate = Completer<void>();

      final closing = service.signOut();
      await auth.signOutStarted.future;

      final signingIn = service.signInAndGetUserId(
        email: 'cuenta-b@example.com',
        password: 'PasswordFicticia123!',
      );

      // Permite completar las microtareas del acceso si no existe
      // coordinacion entre las operaciones. El cierre sigue bloqueado.
      await Future<void>.delayed(Duration.zero);

      auth.signOutGate!.complete();
      await closing;
      final resultUserId = await signingIn;

      expect(resultUserId, 'uid-b');
      expect(auth.signOutCalls, 1);
      expect(auth.signInCalls, 1);
      expect(
        auth.currentUser?.uid,
        'uid-b',
        reason: 'El cierre anterior no debe borrar la nueva sesion de B.',
      );
    });
  });
}

class _ControlledFirebaseAuth extends Fake implements FirebaseAuth {
  _ControlledFirebaseAuth(this._currentUser, {required this.signInUser});

  final _ControlledUser signInUser;
  User? _currentUser;

  final StreamController<User?> _changes = StreamController<User?>.broadcast(
    sync: true,
  );

  final Completer<void> languageStarted = Completer<void>();
  final Completer<void> signOutStarted = Completer<void>();

  Completer<void>? languageGate;
  Completer<void>? signOutGate;

  final List<String?> languageCodes = [];
  int signOutCalls = 0;
  int signInCalls = 0;

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => _changes.stream;

  void changeUser(User? user) {
    _currentUser = user;
    _changes.add(user);
  }

  @override
  Future<void> setLanguageCode(String? languageCode) async {
    languageCodes.add(languageCode);

    if (!languageStarted.isCompleted) {
      languageStarted.complete();
    }

    final gate = languageGate;
    if (gate != null) {
      await gate.future;
    }
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInCalls++;
    changeUser(signInUser);

    return _ControlledCredential(signInUser);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;

    if (!signOutStarted.isCompleted) {
      signOutStarted.complete();
    }

    final gate = signOutGate;
    if (gate != null) {
      await gate.future;
    }

    // Simula una operacion global del SDK que termina tarde.
    changeUser(null);
  }

  Future<void> dispose() => _changes.close();
}

class _ControlledUser extends Fake implements User {
  _ControlledUser(this.uid);

  @override
  final String uid;

  bool verified = false;
  int reloadCalls = 0;
  int verificationCalls = 0;
  final List<bool> tokenRequests = [];

  final Completer<void> reloadStarted = Completer<void>();
  final Completer<void> tokenStarted = Completer<void>();

  Completer<void>? reloadGate;
  Completer<String?>? tokenGate;

  @override
  bool get emailVerified => verified;

  @override
  Future<void> reload() async {
    reloadCalls++;

    if (!reloadStarted.isCompleted) {
      reloadStarted.complete();
    }

    final gate = reloadGate;
    if (gate != null) {
      await gate.future;
    }
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    tokenRequests.add(forceRefresh);

    if (!tokenStarted.isCompleted) {
      tokenStarted.complete();
    }

    final gate = tokenGate;
    if (gate != null) {
      return gate.future;
    }

    return 'token-ficticio-$uid';
  }

  @override
  Future<void> sendEmailVerification([
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    verificationCalls++;
  }
}

class _ControlledCredential extends Fake implements UserCredential {
  _ControlledCredential(this.user);

  @override
  final User user;
}
