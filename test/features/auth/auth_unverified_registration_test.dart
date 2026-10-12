import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('Registro con verificación de correo', () {
    late _FakeRegistrationRepository repository;
    late AuthViewModel viewModel;

    setUp(() {
      repository = _FakeRegistrationRepository();
      viewModel = AuthViewModel(repository);
    });

    tearDown(() async {
      viewModel.dispose();
      await repository.dispose();
    });

    test('rechaza localmente una contraseña débil', () async {
      final result = await viewModel.createUnverifiedAccount(
        email: 'cuenta@example.com',
        password: 'debil',
        passwordConfirmation: 'debil',
      );

      expect(result, isFalse);
      expect(repository.createCalls, 0);
      expect(
        viewModel.errorMessage,
        'La contraseña no cumple los requisitos de seguridad.',
      );
      expect(viewModel.isAuthenticated, isFalse);
    });

    test('rechaza contraseñas válidas que no coinciden', () async {
      final result = await viewModel.createUnverifiedAccount(
        email: 'cuenta@example.com',
        password: 'Sendaris2026!',
        passwordConfirmation: 'Sendaris2027!',
      );

      expect(result, isFalse);
      expect(repository.createCalls, 0);
      expect(viewModel.errorMessage, 'Las contraseñas no coinciden.');
      expect(viewModel.isAuthenticated, isFalse);
    });

    test('crea una cuenta provisional normalizando solo el dominio', () async {
      final result = await viewModel.createUnverifiedAccount(
        email: '  Usuario.Prueba+Sendaris@EXAMPLE.COM  ',
        password: 'Sendaris2026!',
        passwordConfirmation: 'Sendaris2026!',
      );

      expect(result, isTrue);
      expect(repository.createCalls, 1);
      expect(repository.lastEmail, 'Usuario.Prueba+Sendaris@example.com');
      expect(repository.lastPassword, 'Sendaris2026!');
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.currentUserEmail, 'Usuario.Prueba+Sendaris@example.com');
      expect(viewModel.isEmailVerified, isFalse);
      expect(viewModel.isAuthenticatedAppReady, isFalse);
    });

    test(
      'habilita el acceso solo después de confirmar la verificación',
      () async {
        await viewModel.createUnverifiedAccount(
          email: 'cuenta@example.com',
          password: 'Sendaris2026!',
          passwordConfirmation: 'Sendaris2026!',
        );

        expect(viewModel.isAuthenticatedAppReady, isFalse);

        repository.nextVerificationStatus = true;

        final verified = await viewModel.refreshEmailVerificationStatus();

        expect(verified, isTrue);
        expect(viewModel.isEmailVerified, isTrue);
        expect(viewModel.isAuthenticatedAppReady, isTrue);
      },
    );

    test(
      'propaga un mensaje seguro cuando el correo ya está registrado',
      () async {
        const message =
            'Ya existe un registro con este correo. '
            'Inicia sesión con las credenciales utilizadas '
            'para continuar con tu cuenta.';

        repository.registrationError = const AuthFailure(message);

        final result = await viewModel.createUnverifiedAccount(
          email: 'existente@example.com',
          password: 'Sendaris2026!',
          passwordConfirmation: 'Sendaris2026!',
        );

        expect(result, isFalse);
        expect(repository.createCalls, 1);
        expect(viewModel.errorMessage, message);
        expect(viewModel.errorMessage, isNot(contains('24 horas')));
        expect(viewModel.isAuthenticated, isFalse);
        expect(viewModel.isAuthenticatedAppReady, isFalse);
      },
    );

    test(
      'reenviar verificación no habilita prematuramente el acceso',
      () async {
        await viewModel.createUnverifiedAccount(
          email: 'cuenta@example.com',
          password: 'Sendaris2026!',
          passwordConfirmation: 'Sendaris2026!',
        );

        final sent = await viewModel.sendEmailVerification();

        expect(sent, isTrue);
        expect(repository.verificationSendCalls, 1);
        expect(viewModel.isEmailVerified, isFalse);
        expect(viewModel.isAuthenticatedAppReady, isFalse);
      },
    );
  });
}

class _FakeRegistrationRepository
    implements
        AuthRepository,
        AuthRegistrationRepository,
        AuthEmailVerificationRepository {
  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );

  bool _authenticated = false;
  String? _email;
  bool _emailVerified = false;

  bool nextVerificationStatus = false;
  Object? registrationError;

  int createCalls = 0;
  int verificationSendCalls = 0;

  String? lastEmail;
  String? lastPassword;

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
  Future<void> createUnverifiedAccount({
    required String email,
    required String password,
  }) async {
    createCalls++;

    lastEmail = email;
    lastPassword = password;

    final error = registrationError;

    if (error != null) {
      throw error;
    }

    _authenticated = true;
    _email = email;
    _emailVerified = false;
    nextVerificationStatus = false;

    _controller.add(true);
  }

  @override
  Future<void> sendEmailVerification() async {
    verificationSendCalls++;
  }

  @override
  Future<bool> refreshEmailVerificationStatus() async {
    _emailVerified = nextVerificationStatus;

    return _emailVerified;
  }

  @override
  Future<void> signOut() async {
    _authenticated = false;
    _email = null;
    _emailVerified = false;
    nextVerificationStatus = false;

    _controller.add(false);
  }

  Future<void> dispose() {
    return _controller.close();
  }
}
