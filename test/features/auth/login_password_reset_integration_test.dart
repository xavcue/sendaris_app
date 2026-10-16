import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/theme/app_theme.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/domain/repositories/password_reset_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:sendaris/features/auth/presentation/views/login_view.dart';

void main() {
  late _FakeAuthRepository authRepository;
  late _FakePasswordResetRepository resetRepository;
  late AuthViewModel authViewModel;

  setUp(() {
    authRepository = _FakeAuthRepository();
    resetRepository = _FakePasswordResetRepository();
    authViewModel = AuthViewModel(authRepository);
  });

  tearDown(() async {
    authViewModel.dispose();
    await authRepository.dispose();
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: authViewModel,
        child: MaterialApp(
          theme: AppTheme.light,
          home: LoginView(passwordResetRepository: resetRepository),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('login muestra el acceso de recuperación de contraseña', (
    tester,
  ) async {
    await pumpLogin(tester);

    expect(find.byKey(const Key('login-email-field')), findsOneWidget);

    expect(find.byKey(const Key('login-password-field')), findsOneWidget);

    expect(
      find.byKey(const Key('login-forgot-password-button')),
      findsOneWidget,
    );

    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);

    expect(authRepository.signInCalls, 0);
    expect(resetRepository.requestedEmails, isEmpty);
  });

  testWidgets('abre recuperación con el correo escrito y conserva la sesión', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.enterText(
      find.byKey(const Key('login-email-field')),
      '  usuario@example.com  ',
    );

    await tester.enterText(
      find.byKey(const Key('login-password-field')),
      'PasswordDePrueba123!',
    );

    final forgotPassword = find.byKey(
      const Key('login-forgot-password-button'),
    );

    await tester.ensureVisible(forgotPassword);
    await tester.pumpAndSettle();

    await tester.tap(forgotPassword);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('password-reset-dialog')), findsOneWidget);

    expect(find.textContaining('habilitado el acceso'), findsNothing);

    final emailField = tester.widget<TextField>(
      find.byKey(const Key('password-reset-email-field')),
    );

    expect(emailField.controller?.text, 'usuario@example.com');

    expect(authViewModel.isAuthenticated, isFalse);
    expect(authRepository.signInCalls, 0);
    expect(resetRepository.requestedEmails, isEmpty);

    await tester.tap(find.byKey(const Key('password-reset-close-button')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('password-reset-dialog')), findsNothing);

    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('login-email-field')))
          .controller
          ?.text,
      '  usuario@example.com  ',
    );

    expect(authRepository.signInCalls, 0);
    expect(authViewModel.isAuthenticated, isFalse);
  });

  testWidgets('envía solicitud y mantiene el Login sin autenticar', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tester.enterText(
      find.byKey(const Key('login-email-field')),
      'usuario@example.com',
    );

    final forgotPassword = find.byKey(
      const Key('login-forgot-password-button'),
    );

    await tester.ensureVisible(forgotPassword);
    await tester.pumpAndSettle();

    await tester.tap(forgotPassword);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('password-reset-submit-button')));

    await tester.pumpAndSettle();

    expect(resetRepository.requestedEmails, ['usuario@example.com']);

    expect(find.byKey(const Key('password-reset-success')), findsOneWidget);

    expect(
      find.textContaining('Si es posible recuperar la contraseña'),
      findsOneWidget,
    );

    expect(find.textContaining('correo no deseado'), findsNothing);

    expect(authRepository.signInCalls, 0);
    expect(authViewModel.isAuthenticated, isFalse);

    await tester.tap(find.byKey(const Key('password-reset-close-button')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-submit-button')), findsOneWidget);

    expect(find.byKey(const Key('password-reset-dialog')), findsNothing);

    expect(authRepository.signInCalls, 0);
  });
}

class _FakeAuthRepository implements AuthRepository {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool _isAuthenticated = false;

  int signInCalls = 0;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Stream<bool> get authStateChanges => _controller.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;
    _isAuthenticated = true;
    _controller.add(true);
  }

  @override
  Future<void> signOut() async {
    _isAuthenticated = false;
    _controller.add(false);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}

class _FakePasswordResetRepository implements PasswordResetRepository {
  final List<String> requestedEmails = [];

  @override
  Future<void> requestPasswordReset({required String email}) async {
    requestedEmails.add(email);
  }
}
