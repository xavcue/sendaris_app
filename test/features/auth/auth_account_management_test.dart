import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('AuthViewModel administración de cuenta', () {
    late _FakeAccountAuthRepository repository;

    late AuthViewModel viewModel;

    setUp(() {
      repository = _FakeAccountAuthRepository();

      viewModel = AuthViewModel(repository);
    });

    tearDown(() async {
      viewModel.dispose();

      await repository.dispose();
    });

    test('requiere contraseña antes de reautenticar', () async {
      final result = await viewModel.reauthenticateWithPassword(password: '');

      expect(result, isFalse);

      expect(repository.reauthenticationCalls, 0);

      expect(viewModel.errorMessage, 'Ingresa tu contraseña para continuar.');
    });

    test('confirma correctamente la identidad mediante contraseña', () async {
      final result = await viewModel.reauthenticateWithPassword(
        password: 'PasswordDePrueba123!',
      );

      expect(result, isTrue);

      expect(repository.reauthenticationCalls, 1);

      expect(repository.lastPassword, 'PasswordDePrueba123!');

      expect(viewModel.errorMessage, isNull);

      expect(viewModel.isAuthenticated, isTrue);
    });

    test('presenta error controlado si la contraseña es incorrecta', () async {
      repository.reauthenticationError = const AuthFailure(
        'La contraseña ingresada es incorrecta.',
      );

      final result = await viewModel.reauthenticateWithPassword(
        password: 'incorrecta',
      );

      expect(result, isFalse);

      expect(repository.reauthenticationCalls, 1);

      expect(viewModel.errorMessage, 'La contraseña ingresada es incorrecta.');

      expect(viewModel.isAuthenticated, isTrue);
    });

    test('elimina la cuenta y finaliza el contexto autenticado', () async {
      final result = await viewModel.deleteCurrentAccount();

      expect(result, isTrue);

      expect(repository.deleteAccountCalls, 1);

      expect(viewModel.isAuthenticated, isFalse);
    });

    test('un fallo de eliminación mantiene la sesión autenticada', () async {
      repository.deletionError = const AuthFailure(
        'No fue posible eliminar la cuenta.',
      );

      final result = await viewModel.deleteCurrentAccount();

      expect(result, isFalse);

      expect(repository.deleteAccountCalls, 1);

      expect(viewModel.isAuthenticated, isTrue);

      expect(viewModel.errorMessage, 'No fue posible eliminar la cuenta.');
    });
  });
}

class _FakeAccountAuthRepository
    implements AuthRepository, AuthAccountManagementRepository {
  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );

  bool authenticated = true;

  Object? reauthenticationError;

  Object? deletionError;

  int reauthenticationCalls = 0;

  int deleteAccountCalls = 0;

  String? lastPassword;

  @override
  bool get isAuthenticated {
    return authenticated;
  }

  @override
  Stream<bool> get authStateChanges {
    return _controller.stream;
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {
    authenticated = false;

    _controller.add(false);
  }

  @override
  Future<void> reauthenticateWithPassword({required String password}) async {
    reauthenticationCalls++;

    lastPassword = password;

    final error = reauthenticationError;

    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> deleteCurrentAccount() async {
    deleteAccountCalls++;

    final error = deletionError;

    if (error != null) {
      throw error;
    }

    authenticated = false;

    _controller.add(false);
  }

  Future<void> dispose() {
    return _controller.close();
  }
}
