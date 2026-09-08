import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/theme/app_theme.dart';
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
