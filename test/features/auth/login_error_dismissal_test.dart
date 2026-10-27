import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:sendaris/features/auth/presentation/views/login_view.dart';

final class _FailedLoginRepository
    implements AuthRepository, AuthGoogleSignInRepository {
  final _changes = StreamController<bool>.broadcast();

  @override
  bool get isAuthenticated => false;

  @override
  Stream<bool> get authStateChanges => _changes.stream;

  @override
  Future<void> signIn({required String email, required String password}) async {
    throw const AuthFailure('Contraseña incorrecta de prueba.');
  }

  @override
  Future<String?> signInWithGoogleObserved({
    required void Function() onExecutionStarted,
  }) async {
    onExecutionStarted();

    throw const AuthFailure('No fue posible conectar con Google.');
  }

  @override
  Future<void> signOut() async {}

  Future<void> dispose() => _changes.close();
}

void main() {
  late _FailedLoginRepository repository;
  late AuthViewModel viewModel;

  setUp(() {
    repository = _FailedLoginRepository();
    viewModel = AuthViewModel(repository);
  });

  tearDown(() async {
    viewModel.dispose();
    await repository.dispose();
  });

  Future<void> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: viewModel,
        child: const MaterialApp(home: LoginView()),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('los errores de campos desaparecen sin borrar lo escrito', (
    tester,
  ) async {
    await mount(tester);

    await tester.enterText(
      find.byKey(const Key('login-email-field')),
      'prueba@example.com',
    );

    final submit = find.byKey(const Key('login-submit-button'));

    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    expect(find.text('Ingresa tu contraseña.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pump();

    expect(find.text('Ingresa tu contraseña.'), findsNothing);

    final email = tester.widget<TextFormField>(
      find.byKey(const Key('login-email-field')),
    );

    expect(email.controller?.text, 'prueba@example.com');
  });

  testWidgets('el error de contraseña usa la tarjeta y desaparece', (
    tester,
  ) async {
    await mount(tester);

    expect(
      await viewModel.signIn(
        email: 'prueba@example.com',
        password: 'ClaveIncorrecta123!',
      ),
      isFalse,
    );

    await tester.pump();

    expect(find.byKey(const Key('login-error-banner')), findsOneWidget);

    expect(find.text('Contraseña incorrecta de prueba.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pump();

    expect(find.byKey(const Key('login-error-banner')), findsNothing);

    expect(viewModel.errorMessage, isNull);
  });

  testWidgets('el error de Google usa la misma tarjeta y desaparece', (
    tester,
  ) async {
    await mount(tester);

    expect(await viewModel.signInWithGoogle(), isFalse);

    await tester.pump();

    expect(find.byKey(const Key('login-error-banner')), findsOneWidget);

    expect(find.text('No fue posible conectar con Google.'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    await tester.pump();

    expect(find.byKey(const Key('login-error-banner')), findsNothing);

    expect(viewModel.errorMessage, isNull);
  });
}
