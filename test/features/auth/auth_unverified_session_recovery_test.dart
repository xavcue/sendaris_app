import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/theme/app_theme.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:sendaris/features/auth/presentation/views/login_view.dart';

void main() {
  group('Recuperación de una cuenta con correo pendiente', () {
    testWidgets(
      'muestra Revisa tu correo al abrir Sendaris con una sesión no verificada',
      (tester) async {
        final repository = _FakeUnverifiedSessionRepository(
          authenticated: true,
          email: 'pendiente@example.com',
        );

        final viewModel = AuthViewModel(repository);

        addTearDown(viewModel.dispose);
        addTearDown(repository.dispose);

        await _pumpLogin(tester, viewModel);

        expect(viewModel.isAuthenticated, isTrue);

        expect(viewModel.isEmailVerified, isFalse);

        expect(viewModel.isAuthenticatedAppReady, isFalse);

        expect(
          find.byKey(const Key('registration-email-view')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('registration-verification-pending')),
          findsOneWidget,
        );

        expect(find.text('Revisa tu correo'), findsOneWidget);

        expect(find.text('pendiente@example.com'), findsOneWidget);

        expect(find.byKey(const Key('login-email-field')), findsNothing);
      },
    );

    testWidgets(
      'login válido de una cuenta no verificada abre directamente la verificación',
      (tester) async {
        final repository = _FakeUnverifiedSessionRepository();

        final viewModel = AuthViewModel(repository);

        addTearDown(viewModel.dispose);
        addTearDown(repository.dispose);

        await _pumpLogin(tester, viewModel);

        await tester.enterText(
          find.byKey(const Key('login-email-field')),
          'pendiente@example.com',
        );

        await tester.enterText(
          find.byKey(const Key('login-password-field')),
          'Sendaris2026!',
        );

        final loginButton = find.byKey(const Key('login-submit-button'));

        await tester.ensureVisible(loginButton);

        await tester.tap(loginButton);

        await tester.pumpAndSettle();

        expect(repository.signInCalls, 1);

        expect(viewModel.isAuthenticated, isTrue);

        expect(viewModel.isEmailVerified, isFalse);

        expect(viewModel.isAuthenticatedAppReady, isFalse);

        expect(
          find.byKey(const Key('registration-verification-pending')),
          findsOneWidget,
        );

        expect(find.text('pendiente@example.com'), findsOneWidget);

        expect(find.byKey(const Key('login-email-field')), findsNothing);
      },
    );

    testWidgets(
      'Cambiar correo elimina la cuenta provisional y mantiene Crear cuenta abierto',
      (tester) async {
        final repository = _FakeUnverifiedSessionRepository(
          authenticated: true,
          email: 'equivocado@example.com',
        );

        final viewModel = AuthViewModel(repository);

        addTearDown(viewModel.dispose);
        addTearDown(repository.dispose);

        await _pumpLogin(tester, viewModel);

        final changeEmailButton = find.byKey(
          const Key('registration-email-use-other-button'),
        );

        await tester.ensureVisible(changeEmailButton);

        await tester.tap(changeEmailButton);

        await tester.pumpAndSettle();

        expect(repository.deleteCalls, 1);

        expect(viewModel.isAuthenticated, isFalse);

        expect(
          find.byKey(const Key('registration-verification-pending')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('registration-email-field')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('registration-password-field')),
          findsOneWidget,
        );

        expect(find.byKey(const Key('login-email-field')), findsNothing);
      },
    );

    testWidgets(
      'volver desde una sesión no verificada cierra la sesión y muestra Login',
      (tester) async {
        final repository = _FakeUnverifiedSessionRepository(
          authenticated: true,
          email: 'pendiente@example.com',
        );

        final viewModel = AuthViewModel(repository);

        addTearDown(viewModel.dispose);
        addTearDown(repository.dispose);

        await _pumpLogin(tester, viewModel);

        final backButton = find.byKey(
          const Key('registration-email-back-button'),
        );

        await tester.tap(backButton);

        await tester.pumpAndSettle();

        expect(repository.signOutCalls, 1);

        expect(viewModel.isAuthenticated, isFalse);

        expect(
          find.byKey(const Key('registration-verification-pending')),
          findsNothing,
        );

        expect(find.byKey(const Key('login-email-field')), findsOneWidget);

        expect(find.byKey(const Key('login-password-field')), findsOneWidget);
      },
    );
  });
}

Future<void> _pumpLogin(WidgetTester tester, AuthViewModel viewModel) async {
  await tester.binding.setSurfaceSize(const Size(600, 1200));

  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ChangeNotifierProvider<AuthViewModel>.value(
      value: viewModel,
      child: MaterialApp(theme: AppTheme.light, home: const LoginView()),
    ),
  );

  await tester.pumpAndSettle();
}

class _FakeUnverifiedSessionRepository
    implements
        AuthRepository,
        AuthEmailVerificationRepository,
        AuthAccountManagementRepository {
  _FakeUnverifiedSessionRepository({bool authenticated = false, String? email})
    : _isAuthenticated = authenticated,
      _currentUserEmail = authenticated ? email : null;

  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );

  bool _isAuthenticated;

  bool _emailVerified = false;

  String? _currentUserEmail;

  int signInCalls = 0;

  int signOutCalls = 0;

  int deleteCalls = 0;

  bool nextVerificationStatus = false;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  String? get currentUserEmail => _currentUserEmail;

  @override
  bool get isCurrentUserEmailVerified => _emailVerified;

  @override
  Stream<bool> get authStateChanges => _controller.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls++;

    _currentUserEmail = email;
    _emailVerified = false;
    nextVerificationStatus = false;
    _isAuthenticated = true;

    _controller.add(true);
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> refreshEmailVerificationStatus() async {
    _emailVerified = nextVerificationStatus;

    return _emailVerified;
  }

  @override
  Future<void> reauthenticateWithPassword({required String password}) async {}

  @override
  Future<void> deleteCurrentAccount() async {
    deleteCalls++;

    _isAuthenticated = false;
    _emailVerified = false;
    _currentUserEmail = null;
    nextVerificationStatus = false;

    _controller.add(false);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;

    _isAuthenticated = false;
    _emailVerified = false;
    _currentUserEmail = null;
    nextVerificationStatus = false;

    _controller.add(false);
  }

  Future<void> dispose() {
    return _controller.close();
  }
}
