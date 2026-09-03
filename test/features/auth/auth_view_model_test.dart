import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('AuthViewModel', () {
    late FakeAuthRepository repository;
    late AuthViewModel viewModel;

    setUp(() {
      repository = FakeAuthRepository();
      viewModel = AuthViewModel(repository);
    });

    tearDown(() async {
      viewModel.dispose();
      await repository.dispose();
    });

    test('inicia sin sesión autenticada', () {
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
    });

    test(
      'rechaza credenciales vacías mediante un mensaje controlado',
      () async {
        final result = await viewModel.signIn(email: '', password: '');

        expect(result, isFalse);
        expect(viewModel.errorMessage, 'Ingresa tu correo y contraseña.');
        expect(repository.signInCalls, 0);
      },
    );

    test(
      'acepta credenciales válidas y actualiza el estado autenticado',
      () async {
        final result = await viewModel.signIn(
          email: 'prueba.sendaris@example.com',
          password: 'PasswordDePrueba123!',
        );

        expect(result, isTrue);
        expect(viewModel.isAuthenticated, isTrue);
        expect(viewModel.errorMessage, isNull);
        expect(repository.signInCalls, 1);
      },
    );

    test(
      'presenta un error controlado cuando el repositorio rechaza el acceso',
      () async {
        repository.signInError = const AuthFailure(
          'Correo o contraseña incorrectos.',
        );

        final result = await viewModel.signIn(
          email: 'prueba.sendaris@example.com',
          password: 'incorrecta',
        );

        expect(result, isFalse);
        expect(viewModel.errorMessage, 'Correo o contraseña incorrectos.');
        expect(viewModel.isAuthenticated, isFalse);
      },
    );

    test('cierra la sesión correctamente', () async {
      await viewModel.signIn(
        email: 'prueba.sendaris@example.com',
        password: 'PasswordDePrueba123!',
      );

      expect(viewModel.isAuthenticated, isTrue);

      final result = await viewModel.signOut();

      expect(result, isTrue);
      expect(viewModel.isAuthenticated, isFalse);
    });
  });
}

class FakeAuthRepository implements AuthRepository {
  final StreamController<bool> _authController =
      StreamController<bool>.broadcast(sync: true);

  bool _isAuthenticated = false;

  Object? signInError;
  int signInCalls = 0;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Stream<bool> get authStateChanges => _authController.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;

    final error = signInError;

    if (error != null) {
      throw error;
    }

    _isAuthenticated = true;
    _authController.add(true);
  }

  @override
  Future<void> signOut() async {
    _isAuthenticated = false;
    _authController.add(false);
  }

  Future<void> dispose() {
    return _authController.close();
  }
}
