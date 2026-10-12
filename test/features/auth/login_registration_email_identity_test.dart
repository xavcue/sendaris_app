import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/theme/app_theme.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:sendaris/features/auth/presentation/views/login_view.dart';

void main() {
  group('Flujo visual de creación de cuenta', () {
    testWidgets(
      'Crear cuenta abre una pantalla completa y permite volver al login',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(500, 950));

        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repository = _FakeRegistrationRepository();

        final viewModel = AuthViewModel(repository);

        addTearDown(viewModel.dispose);
        addTearDown(repository.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AuthViewModel>.value(
            value: viewModel,
            child: MaterialApp(theme: AppTheme.light, home: const LoginView()),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('login-create-account-button')),
          findsOneWidget,
        );

        expect(find.byKey(const Key('registration-email-view')), findsNothing);

        final createAccountButton = find.byKey(
          const Key('login-create-account-button'),
        );

        await tester.ensureVisible(createAccountButton);

        await tester.tap(createAccountButton);

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('registration-email-view')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('registration-email-title')),
          findsOneWidget,
        );

        expect(find.text('Verifica tu correo para continuar'), findsOneWidget);

        expect(
          find.byKey(const Key('registration-email-field')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('registration-password-field')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('registration-password-confirmation-field')),
          findsOneWidget,
        );

        expect(find.byType(BottomSheet), findsNothing);

        expect(find.byKey(const Key('login-email-field')), findsNothing);

        await tester.tap(
          find.byKey(const Key('registration-email-back-button')),
        );

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('login-email-field')), findsOneWidget);

        expect(find.byKey(const Key('registration-email-view')), findsNothing);
      },
    );

    testWidgets(
      'Revisa tu correo muestra la identidad usada para crear la cuenta',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(500, 1100));

        addTearDown(() => tester.binding.setSurfaceSize(null));

        final repository = _FakeRegistrationRepository();

        final viewModel = AuthViewModel(repository);

        addTearDown(viewModel.dispose);
        addTearDown(repository.dispose);

        await tester.pumpWidget(
          ChangeNotifierProvider<AuthViewModel>.value(
            value: viewModel,
            child: MaterialApp(theme: AppTheme.light, home: const LoginView()),
          ),
        );

        await tester.pumpAndSettle();

        final createAccountButton = find.byKey(
          const Key('login-create-account-button'),
        );

        await tester.ensureVisible(createAccountButton);

        await tester.tap(createAccountButton);

        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('registration-email-field')),
          'Cuenca.Fernando26+Duplicado@GMAIL.COM',
        );

        await tester.enterText(
          find.byKey(const Key('registration-password-field')),
          'Sendaris2026!',
        );

        await tester.enterText(
          find.byKey(const Key('registration-password-confirmation-field')),
          'Sendaris2026!',
        );

        await tester.pumpAndSettle();

        final createButton = find.byKey(
          const Key('registration-create-account-button'),
        );

        await tester.ensureVisible(createButton);

        await tester.tap(createButton);

        await tester.pumpAndSettle();

        expect(
          repository.lastRegistrationEmail,
          'Cuenca.Fernando26+Duplicado@gmail.com',
        );

        expect(repository.lastPassword, 'Sendaris2026!');

        expect(
          viewModel.currentUserEmail,
          'Cuenca.Fernando26+Duplicado@gmail.com',
        );

        expect(viewModel.isAuthenticated, isTrue);

        expect(viewModel.isEmailVerified, isFalse);

        expect(viewModel.isAuthenticatedAppReady, isFalse);

        expect(
          find.byKey(const Key('registration-verification-pending')),
          findsOneWidget,
        );

        expect(find.text('Revisa tu correo'), findsOneWidget);

        expect(
          find.text('Enviamos un correo de verificación a:'),
          findsOneWidget,
        );

        final sentAddress = tester.widget<Text>(
          find.byKey(const Key('registration-email-sent-address')),
        );

        expect(sentAddress.data, 'Cuenca.Fernando26+Duplicado@gmail.com');

        expect(
          find.text('Cuenca.Fernando26+Duplicado@GMAIL.COM'),
          findsNothing,
        );
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

  bool _isAuthenticated = false;

  bool _emailVerified = false;

  String? _currentUserEmail;

  String? lastRegistrationEmail;

  String? lastPassword;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  String? get currentUserEmail => _currentUserEmail;

  @override
  bool get isCurrentUserEmailVerified => _emailVerified;

  @override
  Stream<bool> get authStateChanges => _controller.stream;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> createUnverifiedAccount({
    required String email,
    required String password,
  }) async {
    lastRegistrationEmail = email;
    lastPassword = password;

    _currentUserEmail = email;
    _emailVerified = false;
    _isAuthenticated = true;

    _controller.add(true);
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> refreshEmailVerificationStatus() async {
    return _emailVerified;
  }

  @override
  Future<void> signOut() async {
    _isAuthenticated = false;
    _emailVerified = false;
    _currentUserEmail = null;

    _controller.add(false);
  }

  Future<void> dispose() {
    return _controller.close();
  }
}
