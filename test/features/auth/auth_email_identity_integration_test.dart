import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('AuthViewModel normalización de identidad de correo', () {
    late _FakeEmailIdentityRepository repository;
    late AuthViewModel viewModel;

    setUp(() {
      repository = _FakeEmailIdentityRepository();
      viewModel = AuthViewModel(repository);
    });

    tearDown(() {
      viewModel.dispose();
    });

    test(
      'conserva la identidad Gmail al crear la cuenta provisional',
      () async {
        final result = await viewModel.createUnverifiedAccount(
          email: '  Cuenca.Fernando26+Sendaris99@GMAIL.COM  ',
          password: 'Sendaris2026!',
          passwordConfirmation: 'Sendaris2026!',
        );

        expect(result, isTrue);

        expect(
          repository.lastRegistrationEmail,
          'Cuenca.Fernando26+Sendaris99@gmail.com',
        );

        expect(repository.lastRegistrationPassword, 'Sendaris2026!');
      },
    );

    test('conserva alias y puntos de Outlook al crear la cuenta', () async {
      final result = await viewModel.createUnverifiedAccount(
        email: 'nombre.apellido+registro@OUTLOOK.COM',
        password: 'Sendaris2026!',
        passwordConfirmation: 'Sendaris2026!',
      );

      expect(result, isTrue);

      expect(
        repository.lastRegistrationEmail,
        'nombre.apellido+registro@outlook.com',
      );

      expect(repository.lastRegistrationPassword, 'Sendaris2026!');
    });

    test('conserva puntos y alias Gmail antes del inicio de sesión', () async {
      final result = await viewModel.signIn(
        email: 'cuenca.fernando26+otra@gmail.com',
        password: 'Sendaris2026!',
      );

      expect(result, isTrue);

      expect(repository.lastSignInEmail, 'cuenca.fernando26+otra@gmail.com');

      expect(repository.lastSignInPassword, 'Sendaris2026!');
    });

    test('conserva alias y puntos de proveedores no reconocidos', () async {
      final result = await viewModel.signIn(
        email: 'nombre.apellido+prueba@yahoo.com',
        password: 'Sendaris2026!',
      );

      expect(result, isTrue);

      expect(repository.lastSignInEmail, 'nombre.apellido+prueba@yahoo.com');

      expect(repository.lastSignInPassword, 'Sendaris2026!');
    });
  });
}

class _FakeEmailIdentityRepository
    implements AuthRepository, AuthRegistrationRepository {
  bool _isAuthenticated = false;

  String? lastSignInEmail;
  String? lastSignInPassword;

  String? lastRegistrationEmail;
  String? lastRegistrationPassword;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Stream<bool> get authStateChanges {
    return const Stream<bool>.empty();
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    lastSignInEmail = email;
    lastSignInPassword = password;

    _isAuthenticated = true;
  }

  @override
  Future<void> createUnverifiedAccount({
    required String email,
    required String password,
  }) async {
    lastRegistrationEmail = email;
    lastRegistrationPassword = password;

    _isAuthenticated = true;
  }

  @override
  Future<void> signOut() async {
    _isAuthenticated = false;
  }
}
