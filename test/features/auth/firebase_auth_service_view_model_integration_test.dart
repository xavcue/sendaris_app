import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:sendaris/features/auth/data/services/firebase_auth_service.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

const _password = 'PasswordFicticia123!';

void main() {
  group('FirebaseAuthService y AuthViewModel - cola y registro', () {
    late _IntegrationAuth auth;
    late _IntegrationUser userA;
    late _IntegrationUser userB;
    late _IntegrationUser newUser;
    late FirebaseAuthService service;
    late AuthViewModel viewModel;

    setUp(() {
      auth = _IntegrationAuth();
      userA = _IntegrationUser(auth, 'uid-a');
      userB = _IntegrationUser(auth, 'uid-b');
      newUser = _IntegrationUser(auth, 'uid-registro');
      auth.signInUser = userB;
      auth.registrationUser = newUser;
      service = FirebaseAuthService(auth);
      viewModel = AuthViewModel(FirebaseAuthRepository(service));
    });

    tearDown(() async {
      viewModel.dispose();
      await auth.dispose();
    });

    test(
      'el acceso en cola confirma B tras el cierre pendiente de A',
      () async {
        auth.changeUser(userA);
        auth.signOutGate = Completer<void>();

        final closing = viewModel.signOut();
        await auth.signOutStarted.future;

        final signingIn = viewModel.signIn(
          email: 'b@example.com',
          password: _password,
        );

        auth.signOutGate!.complete();
        await closing;

        expect(await signingIn, isTrue);
        expect(viewModel.currentUserId, 'uid-b');
        expect(viewModel.isAuthenticated, isTrue);
        expect(viewModel.errorMessage, isNull);
        expect(auth.currentUser?.uid, 'uid-b');
      },
    );

    test('el registro en cola confirma su UID tras cerrar A', () async {
      auth.changeUser(userA);
      auth.signOutGate = Completer<void>();

      final closing = viewModel.signOut();
      await auth.signOutStarted.future;

      final registering = viewModel.createUnverifiedAccount(
        email: 'nuevo@example.com',
        password: _password,
        passwordConfirmation: _password,
      );

      auth.signOutGate!.complete();
      await closing;

      expect(await registering, isTrue);
      expect(viewModel.currentUserId, 'uid-registro');
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.errorMessage, isNull);
      expect(newUser.verificationCalls, 1);
    });

    test('el registro correcto sin cola confirma su identidad', () async {
      expect(
        await viewModel.createUnverifiedAccount(
          email: 'nuevo@example.com',
          password: _password,
          passwordConfirmation: _password,
        ),
        isTrue,
      );

      expect(viewModel.currentUserId, 'uid-registro');
      expect(auth.currentUser?.uid, 'uid-registro');
      expect(newUser.verificationCalls, 1);
      expect(newUser.deleteCalls, 0);
    });

    test(
      'un fallo del correo elimina el registro y muestra el error',
      () async {
        newUser.verificationError = FirebaseAuthException(
          code: 'network-request-failed',
        );

        final registered = await viewModel.createUnverifiedAccount(
          email: 'nuevo@example.com',
          password: _password,
          passwordConfirmation: _password,
        );

        expect(registered, isFalse);
        expect(newUser.deleteCalls, 1);
        expect(auth.currentUser, isNull);
        expect(viewModel.isAuthenticated, isFalse);
        expect(viewModel.errorMessage, contains('Verifica tu conexión'));
      },
    );

    test('si falla la eliminación provisional se cierra la sesión', () async {
      newUser.verificationError = FirebaseAuthException(
        code: 'network-request-failed',
      );
      newUser.deleteError = StateError('Eliminación ficticia fallida.');

      await expectLater(
        service.createUnverifiedAccountAndGetUserId(
          email: 'nuevo@example.com',
          password: _password,
        ),
        throwsA(
          isA<FirebaseAuthException>().having(
            (error) => error.code,
            'código del fallo original',
            'network-request-failed',
          ),
        ),
      );

      expect(newUser.deleteCalls, 1);
      expect(auth.signOutCalls, 1);
      expect(auth.currentUser, isNull);
    });

    test(
      'A a B a A durante la eliminación no cierra la nueva sesión',
      () async {
        newUser.verificationError = FirebaseAuthException(
          code: 'network-request-failed',
        );
        newUser.deleteError = StateError('Eliminación ficticia fallida.');
        newUser.deleteGate = Completer<void>();

        final registering = service.createUnverifiedAccountAndGetUserId(
          email: 'nuevo@example.com',
          password: _password,
        );
        final checked = expectLater(
          registering,
          throwsA(isA<FirebaseAuthException>()),
        );

        await newUser.deleteStarted.future;
        auth.changeUser(userB);
        auth.changeUser(newUser);
        newUser.deleteGate!.complete();

        await checked;
        expect(auth.signOutCalls, 0);
        expect(auth.currentUser?.uid, 'uid-registro');
      },
    );

    test('un fallo tardío del correo no elimina la sesión B', () async {
      newUser.verificationGate = Completer<void>();
      newUser.verificationError = FirebaseAuthException(
        code: 'network-request-failed',
      );

      final registering = service.createUnverifiedAccountAndGetUserId(
        email: 'nuevo@example.com',
        password: _password,
      );
      final checked = expectLater(
        registering,
        throwsA(isA<FirebaseAuthException>()),
      );

      await newUser.verificationStarted.future;
      auth.changeUser(userB);
      newUser.verificationGate!.complete();

      await checked;
      expect(newUser.deleteCalls, 0);
      expect(auth.signOutCalls, 0);
      expect(auth.currentUser?.uid, 'uid-b');
    });

    test('A a B a A durante la política impide crear la cuenta', () async {
      auth.changeUser(userA);
      auth.passwordGate = Completer<void>();

      final registering = service.createUnverifiedAccountAndGetUserId(
        email: 'nuevo@example.com',
        password: _password,
      );
      final checked = expectLater(registering, throwsA(isA<StateError>()));

      await auth.passwordStarted.future;
      auth.changeUser(userB);
      auth.changeUser(userA);
      auth.passwordGate!.complete();

      await checked;
      expect(auth.createCalls, 0);
      expect(auth.currentUser?.uid, 'uid-a');
    });
  });
}

class _IntegrationAuth extends Fake implements FirebaseAuth {
  final StreamController<User?> _changes = StreamController<User?>.broadcast(
    sync: true,
  );

  User? _currentUser;
  late User signInUser;
  late User registrationUser;

  final Completer<void> signOutStarted = Completer<void>();
  final Completer<void> passwordStarted = Completer<void>();
  Completer<void>? signOutGate;
  Completer<void>? passwordGate;

  int signOutCalls = 0;
  int createCalls = 0;

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => _changes.stream;

  void changeUser(User? user) {
    _currentUser = user;
    _changes.add(user);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    changeUser(signInUser);
    return _IntegrationCredential(signInUser);
  }

  @override
  Future<UserCredential> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    createCalls++;
    changeUser(registrationUser);
    return _IntegrationCredential(registrationUser);
  }

  @override
  Future<PasswordValidationStatus> validatePassword(
    FirebaseAuth requestedAuth,
    String? password,
  ) async {
    if (!passwordStarted.isCompleted) {
      passwordStarted.complete();
    }
    final gate = passwordGate;
    if (gate != null) {
      await gate.future;
    }
    return _ValidPassword();
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
    changeUser(null);
  }

  @override
  Future<void> setLanguageCode(String? languageCode) async {}

  Future<void> dispose() => _changes.close();
}

class _IntegrationUser extends Fake implements User {
  _IntegrationUser(this._auth, this.uid);

  final _IntegrationAuth _auth;

  @override
  final String uid;

  @override
  String? get email => '$uid@example.com';

  @override
  bool get emailVerified => false;

  final Completer<void> verificationStarted = Completer<void>();
  final Completer<void> deleteStarted = Completer<void>();
  Completer<void>? verificationGate;
  Completer<void>? deleteGate;
  Object? verificationError;
  Object? deleteError;

  int verificationCalls = 0;
  int deleteCalls = 0;

  @override
  Future<void> reload() async {}

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    return 'token-ficticio-$uid';
  }

  @override
  Future<void> sendEmailVerification([
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    verificationCalls++;
    if (!verificationStarted.isCompleted) {
      verificationStarted.complete();
    }
    final gate = verificationGate;
    if (gate != null) {
      await gate.future;
    }
    if (verificationError != null) {
      throw verificationError!;
    }
  }

  @override
  Future<void> delete() async {
    deleteCalls++;
    if (!deleteStarted.isCompleted) {
      deleteStarted.complete();
    }
    final gate = deleteGate;
    if (gate != null) {
      await gate.future;
    }
    if (deleteError != null) {
      throw deleteError!;
    }
    if (identical(_auth.currentUser, this)) {
      _auth.changeUser(null);
    }
  }
}

class _IntegrationCredential extends Fake implements UserCredential {
  _IntegrationCredential(this.user);

  @override
  final User user;
}

class _ValidPassword extends Fake implements PasswordValidationStatus {
  @override
  bool get isValid => true;
}
