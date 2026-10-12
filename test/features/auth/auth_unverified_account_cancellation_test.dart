import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('Cancelación segura de cuenta provisional', () {
    late _FakeProvisionalAccountRepository repository;
    late AuthViewModel viewModel;

    tearDown(() async {
      viewModel.dispose();
      await repository.dispose();
    });

    test(
      'elimina únicamente después de confirmar que sigue sin verificar',
      () async {
        repository = _FakeProvisionalAccountRepository();
        viewModel = AuthViewModel(repository);

        final result = await viewModel.cancelUnverifiedAccount();

        expect(result, isTrue);
        expect(repository.refreshCalls, 1);
        expect(repository.deleteCalls, 1);
        expect(viewModel.isAuthenticated, isFalse);
        expect(viewModel.isAuthenticatedAppReady, isFalse);
        expect(viewModel.errorMessage, isNull);
      },
    );

    test(
      'jamás elimina la cuenta si Firebase confirma que ya fue verificada',
      () async {
        repository = _FakeProvisionalAccountRepository(
          providerEmailVerified: true,
        );
        viewModel = AuthViewModel(repository);

        expect(viewModel.isEmailVerified, isFalse);
        expect(viewModel.isAuthenticatedAppReady, isFalse);

        final result = await viewModel.cancelUnverifiedAccount();

        expect(result, isFalse);
        expect(repository.refreshCalls, 1);
        expect(repository.deleteCalls, 0);
        expect(viewModel.isAuthenticated, isTrue);
        expect(viewModel.isEmailVerified, isTrue);
        expect(viewModel.isAuthenticatedAppReady, isTrue);
        expect(
          viewModel.errorMessage,
          'Tu correo ya está verificado. La cuenta no se eliminó.',
        );
      },
    );

    test('un fallo al comprobar Firebase impide eliminar la cuenta', () async {
      repository = _FakeProvisionalAccountRepository()
        ..refreshError = const AuthFailure(
          'No fue posible comprobar la verificación del correo.',
        );

      viewModel = AuthViewModel(repository);

      final result = await viewModel.cancelUnverifiedAccount();

      expect(result, isFalse);
      expect(repository.refreshCalls, 1);
      expect(repository.deleteCalls, 0);
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.isAuthenticatedAppReady, isFalse);
      expect(
        viewModel.errorMessage,
        'No fue posible comprobar la verificación del correo.',
      );
    });
  });
}

class _FakeProvisionalAccountRepository
    implements
        AuthRepository,
        AuthEmailVerificationRepository,
        AuthAccountManagementRepository {
  _FakeProvisionalAccountRepository({this.providerEmailVerified = false});

  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );

  bool _authenticated = true;
  String? _email = 'pendiente@example.com';
  bool _emailVerified = false;

  bool providerEmailVerified;
  Object? refreshError;

  int refreshCalls = 0;
  int deleteCalls = 0;

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
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> refreshEmailVerificationStatus() async {
    refreshCalls++;

    final error = refreshError;

    if (error != null) {
      throw error;
    }

    _emailVerified = providerEmailVerified;

    return _emailVerified;
  }

  @override
  Future<void> reauthenticateWithPassword({required String password}) async {}

  @override
  Future<void> deleteCurrentAccount() async {
    deleteCalls++;

    _authenticated = false;
    _email = null;
    _emailVerified = false;

    _controller.add(false);
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
