import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/theme/app_theme.dart';
import 'package:sendaris/app/theme/theme_mode_controller.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:sendaris/features/auth/presentation/views/login_view.dart';

void main() {
  testWidgets('login muestra una interfaz clara y orientada al usuario', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
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

    expect(find.byKey(const Key('sendaris-brand-icon')), findsOneWidget);
    expect(find.text('Sendaris'), findsOneWidget);

    expect(
      find.text('Organiza registros y rutinas en un solo lugar.'),
      findsOneWidget,
    );

    expect(find.text('Accede a tu cuenta'), findsOneWidget);

    expect(find.byKey(const Key('login-email-field')), findsOneWidget);
    expect(find.byKey(const Key('login-password-field')), findsOneWidget);
    expect(find.byKey(const Key('login-submit-button')), findsOneWidget);

    expect(find.textContaining('anonymousId'), findsNothing);
    expect(find.textContaining('UID'), findsNothing);
    expect(find.textContaining('Firebase'), findsNothing);
  });

  testWidgets('login valida correo y contraseña obligatorios', (tester) async {
    final repository = _FakeAuthRepository();
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

    final submitButton = find.byKey(const Key('login-submit-button'));

    expect(submitButton, findsOneWidget);

    await tester.ensureVisible(submitButton);
    await tester.pumpAndSettle();

    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    expect(find.text('Ingresa tu correo electrónico.'), findsOneWidget);
    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);
  });

  testWidgets('login permite seleccionar Sistema, Claro y Oscuro', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    final authViewModel = AuthViewModel(repository);
    final themeController = ThemeModeController();

    addTearDown(authViewModel.dispose);
    addTearDown(repository.dispose);
    addTearDown(themeController.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
          ChangeNotifierProvider<ThemeModeController>.value(
            value: themeController,
          ),
        ],
        child: AnimatedBuilder(
          animation: themeController,
          builder: (context, child) {
            return MaterialApp(
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              themeMode: themeController.themeMode,
              home: const LoginView(),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(themeController.themeMode, ThemeMode.system);
    expect(find.byKey(const Key('auth-theme-menu-button')), findsOneWidget);
    expect(find.byKey(const Key('auth-back-button')), findsNothing);
    expect(find.byTooltip('Usar modo claro'), findsNothing);
    expect(find.byTooltip('Usar modo oscuro'), findsNothing);

    final options = <ThemeMode, String>{
      ThemeMode.light: 'auth-theme-light',
      ThemeMode.dark: 'auth-theme-dark',
      ThemeMode.system: 'auth-theme-system',
    };

    for (final entry in options.entries) {
      await tester.tap(find.byKey(const Key('auth-theme-menu-button')));
      await tester.pumpAndSettle();

      expect(find.text('Sistema'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Oscuro'), findsOneWidget);

      await tester.tap(find.byKey(Key(entry.value)));
      await tester.pumpAndSettle();

      expect(themeController.themeMode, entry.key);
      expect(find.byKey(const Key('auth-theme-menu-button')), findsOneWidget);
    }

    expect(find.byKey(const Key('login-email-field')), findsOneWidget);
    expect(find.byKey(const Key('login-password-field')), findsOneWidget);
  });

  testWidgets('login y registro utilizan un único selector de tema', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    final authViewModel = AuthViewModel(repository);
    final themeController = ThemeModeController();

    addTearDown(authViewModel.dispose);
    addTearDown(repository.dispose);
    addTearDown(themeController.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
          ChangeNotifierProvider<ThemeModeController>.value(
            value: themeController,
          ),
        ],
        child: MaterialApp(theme: AppTheme.light, home: const LoginView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('auth-theme-menu-button')), findsOneWidget);

    final createAccount = find.byKey(const Key('login-create-account-button'));

    await tester.ensureVisible(createAccount);
    await tester.pumpAndSettle();
    await tester.tap(createAccount);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('registration-email-view')), findsOneWidget);

    expect(find.byKey(const Key('auth-theme-menu-button')), findsOneWidget);

    final backButton = find.byKey(const Key('registration-email-back-button'));

    expect(backButton, findsOneWidget);

    await tester.tap(backButton);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('login-email-field')), findsOneWidget);
    expect(find.byKey(const Key('registration-email-view')), findsNothing);

    expect(find.byKey(const Key('auth-theme-menu-button')), findsOneWidget);

    expect(find.byKey(const Key('auth-back-button')), findsNothing);
  });
}

class _FakeAuthRepository implements AuthRepository {
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  bool _isAuthenticated = false;

  @override
  bool get isAuthenticated => _isAuthenticated;

  @override
  Stream<bool> get authStateChanges => _controller.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
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
