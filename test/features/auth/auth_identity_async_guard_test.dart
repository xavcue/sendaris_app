import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('AuthViewModel - validacion asincronica por UID', () {
    late _PendingValidationAuthRepository repository;
    late AuthViewModel viewModel;

    setUp(() {
      repository = _PendingValidationAuthRepository();
      viewModel = AuthViewModel(repository);
    });

    tearDown(() async {
      viewModel.dispose();
      await repository.dispose();
    });

    test('una validacion vigente conserva la cuenta A', () async {
      final operation = viewModel.validateCurrentSession();

      expect(viewModel.isValidatingSession, isTrue);

      repository.completeValidation(true);

      final result = await operation;

      expect(result, isTrue);
      expect(repository.validationCalls, 1);
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.currentUserId, 'uid-a');
      expect(viewModel.isAuthenticatedAppReady, isTrue);
      expect(viewModel.isValidatingSession, isFalse);
    });

    test('una respuesta invalida de A no desautentica a B', () async {
      final operation = viewModel.validateCurrentSession();

      repository.changeAccount('uid-b');

      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.isAuthenticated, isTrue);

      repository.completeValidation(false);

      final result = await operation;

      expect(
        result,
        isTrue,
        reason:
            'La validacion obsoleta de A no debe '
            'invalidar la sesion actual de B.',
      );

      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.isAuthenticatedAppReady, isTrue);
      expect(viewModel.isValidatingSession, isFalse);
    });

    test('un error tardio de A no se muestra en B', () async {
      final operation = viewModel.validateCurrentSession();

      repository.changeAccount('uid-b');

      repository.failValidation(
        const AuthFailure('Error de validacion de la cuenta anterior.'),
      );

      final result = await operation;

      expect(result, isTrue);
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.currentUserId, 'uid-b');

      expect(
        viewModel.errorMessage,
        isNull,
        reason:
            'Un error perteneciente a A no debe '
            'contaminar el estado de B.',
      );

      expect(viewModel.isValidatingSession, isFalse);
    });

    test('un retorno A a B a A no reutiliza el resultado antiguo', () async {
      final operation = viewModel.validateCurrentSession();

      repository.changeAccount('uid-b');
      repository.changeAccount('uid-a');

      repository.completeValidation(false);

      final result = await operation;

      expect(
        result,
        isTrue,
        reason:
            'Una nueva sesion de A no debe aceptar '
            'el resultado de una operacion anterior.',
      );

      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.currentUserId, 'uid-a');
      expect(viewModel.isAuthenticatedAppReady, isTrue);
      expect(viewModel.isValidatingSession, isFalse);
    });
  });
}

class _PendingValidationAuthRepository
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthSessionValidationRepository,
        AuthEmailVerificationRepository {
  final StreamController<bool> _authController =
      StreamController<bool>.broadcast(sync: true);

  final StreamController<String?> _identityController =
      StreamController<String?>.broadcast(sync: true);

  final Completer<bool> _validation = Completer<bool>();

  String? _userId = 'uid-a';

  bool _emailVerified = true;

  int validationCalls = 0;

  @override
  bool get isAuthenticated => _userId != null;

  @override
  String? get currentUserId => _userId;

  @override
  String? get currentUserEmail {
    final uid = _userId;

    if (uid == null) {
      return null;
    }

    return '$uid@example.test';
  }

  @override
  bool get isCurrentUserEmailVerified => _emailVerified;

  @override
  Stream<bool> get authStateChanges => _authController.stream;

  @override
  Stream<String?> get userIdChanges => _identityController.stream;

  void changeAccount(String? userId) {
    _userId = userId;
    _emailVerified = userId != null;

    _identityController.add(userId);
    _authController.add(userId != null);
  }

  void completeValidation(bool valid) {
    _validation.complete(valid);
  }

  void failValidation(Object error) {
    _validation.completeError(error);
  }

  @override
  Future<bool> validateCurrentSession() {
    validationCalls++;
    return _validation.future;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    changeAccount('uid-login');
  }

  @override
  Future<void> signOut() async {
    changeAccount(null);
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> refreshEmailVerificationStatus() async {
    return _emailVerified;
  }

  Future<void> dispose() async {
    await _identityController.close();
    await _authController.close();
  }
}
