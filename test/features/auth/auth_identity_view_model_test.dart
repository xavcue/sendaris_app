import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('AuthViewModel - aislamiento de identidad', () {
    late FakeIdentityAuthRepository repository;
    late AuthViewModel viewModel;

    setUp(() {
      repository = FakeIdentityAuthRepository();
      viewModel = AuthViewModel(repository);
    });

    tearDown(() async {
      viewModel.dispose();
      await repository.dispose();
    });

    test('inicia sin identidad autenticada', () {
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.currentUserId, isNull);
      expect(viewModel.currentUserEmail, isNull);
      expect(viewModel.isEmailVerified, isNull);
      expect(viewModel.isAuthenticatedAppReady, isFalse);
    });

    test('identifica una cuenta autenticada por su UID', () {
      repository.activateAccount(
        uid: 'uid-usuario-a',
        email: 'usuario-a@example.test',
        emailVerified: true,
      );

      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.currentUserId, 'uid-usuario-a');
      expect(viewModel.currentUserEmail, 'usuario-a@example.test');
      expect(viewModel.isEmailVerified, isTrue);
      expect(viewModel.isAuthenticatedAppReady, isTrue);
    });

    test('detecta un cambio de UID aunque ambas cuentas '
        'permanezcan autenticadas', () {
      final observedIds = <String?>[];

      viewModel.addListener(() {
        observedIds.add(viewModel.currentUserId);
      });

      repository.activateAccount(
        uid: 'uid-usuario-a',
        email: 'usuario@example.test',
        emailVerified: true,
      );

      expect(viewModel.currentUserId, 'uid-usuario-a');

      repository.activateAccount(
        uid: 'uid-usuario-b',
        email: 'usuario@example.test',
        emailVerified: true,
        emitAuthenticationEvent: false,
      );

      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.currentUserId, 'uid-usuario-b');
      expect(viewModel.isAuthenticatedAppReady, isTrue);

      expect(observedIds, <String?>['uid-usuario-a', 'uid-usuario-b']);
    });

    test('ignora un evento antiguo de identidad', () {
      repository.activateAccount(
        uid: 'uid-usuario-a',
        email: 'usuario-a@example.test',
        emailVerified: true,
      );

      repository.activateAccount(
        uid: 'uid-usuario-b',
        email: 'usuario-b@example.test',
        emailVerified: true,
        emitAuthenticationEvent: false,
      );

      var notifications = 0;

      viewModel.addListener(() {
        notifications++;
      });

      repository.emitIdentityEvent('uid-usuario-a');

      expect(viewModel.currentUserId, 'uid-usuario-b');
      expect(viewModel.currentUserEmail, 'usuario-b@example.test');
      expect(notifications, 0);
    });

    test('no notifica cambios duplicados del mismo UID', () {
      repository.activateAccount(
        uid: 'uid-usuario-a',
        email: 'usuario-a@example.test',
        emailVerified: true,
      );

      var notifications = 0;

      viewModel.addListener(() {
        notifications++;
      });

      repository.emitIdentityEvent('uid-usuario-a');
      repository.emitIdentityEvent('uid-usuario-a');

      expect(viewModel.currentUserId, 'uid-usuario-a');
      expect(notifications, 0);
    });

    test('actualiza la verificacion sin cambiar el UID', () {
      repository.activateAccount(
        uid: 'uid-usuario-a',
        email: 'usuario-a@example.test',
        emailVerified: false,
      );

      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.isAuthenticatedAppReady, isFalse);

      repository.activateAccount(
        uid: 'uid-usuario-a',
        email: 'usuario-a@example.test',
        emailVerified: true,
        emitAuthenticationEvent: false,
      );

      expect(viewModel.currentUserId, 'uid-usuario-a');
      expect(viewModel.isEmailVerified, isTrue);
      expect(viewModel.isAuthenticatedAppReady, isTrue);
    });

    test('limpia la identidad al cerrar la sesion', () async {
      repository.activateAccount(
        uid: 'uid-usuario-a',
        email: 'usuario-a@example.test',
        emailVerified: true,
      );

      final result = await viewModel.signOut();

      expect(result, isTrue);
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.currentUserId, isNull);
      expect(viewModel.currentUserEmail, isNull);
      expect(viewModel.isEmailVerified, isNull);
      expect(viewModel.isAuthenticatedAppReady, isFalse);
    });
  });
}

class FakeIdentityAuthRepository
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthEmailVerificationRepository {
  final StreamController<bool> _authenticationController =
      StreamController<bool>.broadcast(sync: true);

  final StreamController<String?> _identityController =
      StreamController<String?>.broadcast(sync: true);

  String? _currentUserId;
  String? _currentUserEmail;
  bool _emailVerified = false;

  @override
  bool get isAuthenticated => _currentUserId != null;

  @override
  String? get currentUserId => _currentUserId;

  @override
  String? get currentUserEmail => _currentUserEmail;

  @override
  bool get isCurrentUserEmailVerified => _emailVerified;

  @override
  Stream<bool> get authStateChanges => _authenticationController.stream;

  @override
  Stream<String?> get userIdChanges => _identityController.stream;

  void activateAccount({
    required String uid,
    required String email,
    required bool emailVerified,
    bool emitAuthenticationEvent = true,
  }) {
    _currentUserId = uid;
    _currentUserEmail = email;
    _emailVerified = emailVerified;

    _identityController.add(uid);

    if (emitAuthenticationEvent) {
      _authenticationController.add(true);
    }
  }

  void emitIdentityEvent(String? uid) {
    _identityController.add(uid);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    activateAccount(uid: 'uid-test-login', email: email, emailVerified: false);
  }

  @override
  Future<void> signOut() async {
    _currentUserId = null;
    _currentUserEmail = null;
    _emailVerified = false;

    _identityController.add(null);
    _authenticationController.add(false);
  }

  @override
  Future<void> sendEmailVerification() async {
    // No se envian correos reales durante las pruebas.
  }

  @override
  Future<bool> refreshEmailVerificationStatus() async {
    return _emailVerified;
  }

  Future<void> dispose() async {
    await _identityController.close();
    await _authenticationController.close();
  }
}
