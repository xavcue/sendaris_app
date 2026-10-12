import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('AuthViewModel verificación de correo', () {
    late _FakeEmailVerificationRepository repository;
    late AuthViewModel viewModel;

    setUp(() {
      repository = _FakeEmailVerificationRepository();
      viewModel = AuthViewModel(repository);
    });

    tearDown(() async {
      viewModel.dispose();
      await repository.dispose();
    });

    test('expone correo y mantiene bloqueada una sesión no verificada', () {
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.currentUserEmail, 'cuenta@example.com');
      expect(viewModel.isEmailVerified, isFalse);
      expect(viewModel.isAuthenticatedAppReady, isFalse);
    });

    test('envía verificación mientras la cuenta continúa pendiente', () async {
      final result = await viewModel.sendEmailVerification();

      expect(result, isTrue);
      expect(repository.sendVerificationCalls, 1);
      expect(viewModel.isAuthenticatedAppReady, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test('habilita la aplicación únicamente después de verificar', () async {
      repository.nextVerificationStatus = true;

      final result = await viewModel.refreshEmailVerificationStatus();

      expect(result, isTrue);
      expect(repository.refreshVerificationCalls, 1);
      expect(viewModel.isEmailVerified, isTrue);
      expect(viewModel.isAuthenticatedAppReady, isTrue);
      expect(viewModel.errorMessage, isNull);
    });

    test('no reenvía correo si la cuenta ya está verificada', () async {
      repository.nextVerificationStatus = true;

      await viewModel.refreshEmailVerificationStatus();

      final result = await viewModel.sendEmailVerification();

      expect(result, isTrue);
      expect(repository.sendVerificationCalls, 0);
      expect(viewModel.isAuthenticatedAppReady, isTrue);
    });

    test('un fallo remoto de comprobación no habilita la aplicación', () async {
      repository.refreshError = const AuthFailure(
        'No fue posible comprobar la verificación del correo. '
        'Verifica tu conexión.',
      );

      final result = await viewModel.refreshEmailVerificationStatus();

      expect(result, isFalse);
      expect(repository.refreshVerificationCalls, 1);
      expect(viewModel.isEmailVerified, isFalse);
      expect(viewModel.isAuthenticatedAppReady, isFalse);
      expect(
        viewModel.errorMessage,
        'No fue posible comprobar la verificación del correo. '
        'Verifica tu conexión.',
      );
    });

    test('cerrar sesión limpia correo y estado de verificación', () async {
      final result = await viewModel.signOut();

      expect(result, isTrue);
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.currentUserEmail, isNull);
      expect(viewModel.isEmailVerified, isNull);
      expect(viewModel.isAuthenticatedAppReady, isFalse);
    });
  });
}

class _FakeEmailVerificationRepository
    implements AuthRepository, AuthEmailVerificationRepository {
  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );

  bool _authenticated = true;
  String? _email = 'cuenta@example.com';
  bool _emailVerified = false;

  bool nextVerificationStatus = false;

  Object? sendError;
  Object? refreshError;

  int sendVerificationCalls = 0;
  int refreshVerificationCalls = 0;

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
  Future<void> sendEmailVerification() async {
    sendVerificationCalls++;

    final error = sendError;

    if (error != null) {
      throw error;
    }
  }

  @override
  Future<bool> refreshEmailVerificationStatus() async {
    refreshVerificationCalls++;

    final error = refreshError;

    if (error != null) {
      throw error;
    }

    _emailVerified = nextVerificationStatus;

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
