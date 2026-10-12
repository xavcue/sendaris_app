import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('AuthViewModel validación de sesión', () {
    late _FakeSessionRepository repository;
    late AuthViewModel viewModel;

    setUp(() {
      repository = _FakeSessionRepository();
      viewModel = AuthViewModel(repository);
    });

    tearDown(() async {
      viewModel.dispose();
      await repository.dispose();
    });

    test('mantiene una sesión válida todavía no verificada', () async {
      final result = await viewModel.validateCurrentSession();

      expect(result, isTrue);
      expect(repository.validationCalls, 1);
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.isEmailVerified, isFalse);
      expect(viewModel.isAuthenticatedAppReady, isFalse);
    });

    test('refresca la verificación durante la validación de sesión', () async {
      repository.emailVerifiedAfterValidation = true;

      final result = await viewModel.validateCurrentSession();

      expect(result, isTrue);
      expect(repository.validationCalls, 1);
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.isEmailVerified, isTrue);
      expect(viewModel.isAuthenticatedAppReady, isTrue);
    });

    test('expulsa una sesión que el proveedor considera inválida', () async {
      repository.validationResult = false;

      final result = await viewModel.validateCurrentSession();

      expect(result, isFalse);
      expect(repository.validationCalls, 1);
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.currentUserEmail, isNull);
      expect(viewModel.isEmailVerified, isNull);
      expect(viewModel.isAuthenticatedAppReady, isFalse);
    });

    test('un fallo temporal de red no expulsa la sesión local', () async {
      repository.validationError = const AuthFailure(
        'No fue posible verificar la sesión. '
        'Comprueba tu conexión.',
      );

      final result = await viewModel.validateCurrentSession();

      expect(result, isTrue);
      expect(repository.validationCalls, 1);
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.isAuthenticatedAppReady, isFalse);
      expect(
        viewModel.errorMessage,
        'No fue posible verificar la sesión. '
        'Comprueba tu conexión.',
      );
    });
  });
}

class _FakeSessionRepository
    implements
        AuthRepository,
        AuthSessionValidationRepository,
        AuthEmailVerificationRepository {
  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );

  bool _authenticated = true;
  String? _email = 'cuenta@example.com';
  bool _emailVerified = false;

  bool validationResult = true;
  bool emailVerifiedAfterValidation = false;
  Object? validationError;

  int validationCalls = 0;

  @override
  bool get isAuthenticated => _authenticated;

  @override
  String? get currentUserEmail => _email;

  @override
  bool get isCurrentUserEmailVerified => _emailVerified;

  @override
  Stream<bool> get authStateChanges => _controller.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _authenticated = true;
    _email = email;
    _emailVerified = false;

    _controller.add(true);
  }

  @override
  Future<bool> validateCurrentSession() async {
    validationCalls++;

    final error = validationError;

    if (error != null) {
      throw error;
    }

    if (!validationResult) {
      _authenticated = false;
      _email = null;
      _emailVerified = false;

      _controller.add(false);

      return false;
    }

    _emailVerified = emailVerifiedAfterValidation;

    return true;
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> refreshEmailVerificationStatus() async {
    return _emailVerified;
  }

  @override
  Future<void> signOut() async {
    _authenticated = false;
    _email = null;
    _emailVerified = false;

    _controller.add(false);
  }

  Future<void> dispose() {
    return _controller.close();
  }
}
