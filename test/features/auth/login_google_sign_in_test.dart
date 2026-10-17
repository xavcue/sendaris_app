import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/theme/app_theme.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:sendaris/features/auth/presentation/views/login_view.dart';

void main() {
  late _FakeLoginGoogleRepository repository;
  late AuthViewModel viewModel;

  setUp(() {
    repository = _FakeLoginGoogleRepository();
    viewModel = AuthViewModel(repository);
  });

  tearDown(() async {
    viewModel.dispose();
    await repository.dispose();
  });

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AuthViewModel>.value(
        value: viewModel,
        child: MaterialApp(theme: AppTheme.light, home: const LoginView()),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> tapGoogle(WidgetTester tester) async {
    final button = find.byKey(const Key('login-google-button'));

    await tester.ensureVisible(button);
    await tester.pumpAndSettle();

    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('muestra los dos métodos de acceso', (tester) async {
    await pumpLogin(tester);

    expect(find.byKey(const Key('login-email-field')), findsOneWidget);

    expect(find.byKey(const Key('login-password-field')), findsOneWidget);

    expect(find.byKey(const Key('login-submit-button')), findsOneWidget);

    expect(find.byKey(const Key('login-google-button')), findsOneWidget);

    expect(find.text('Continuar con Google'), findsOneWidget);

    expect(
      find.byKey(const Key('login-create-account-button')),
      findsOneWidget,
    );
  });

  testWidgets('Google no requiere rellenar correo ni contraseña', (
    tester,
  ) async {
    await pumpLogin(tester);

    await tapGoogle(tester);
    await tester.pumpAndSettle();

    expect(repository.googleCalls, 1);
    expect(viewModel.isAuthenticated, isTrue);
    expect(viewModel.currentUserId, 'uid-google');

    expect(find.text('Ingresa tu correo electrónico.'), findsNothing);

    expect(find.text('Ingresa tu contraseña.'), findsNothing);
  });

  testWidgets('cancelar Google no muestra mensajes de error', (tester) async {
    repository.nextGoogleUserId = null;

    await pumpLogin(tester);

    await tapGoogle(tester);
    await tester.pumpAndSettle();

    expect(repository.googleCalls, 1);
    expect(viewModel.isAuthenticated, isFalse);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isLoading, isFalse);
  });

  testWidgets('deshabilita los métodos de acceso durante Google', (
    tester,
  ) async {
    final pending = Completer<String?>();
    repository.pendingGoogle = pending;

    await pumpLogin(tester);

    await tapGoogle(tester);

    expect(viewModel.isLoading, isTrue);

    final googleButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('login-google-button')),
    );

    final submitButton = tester.widget<FilledButton>(
      find.byKey(const Key('login-submit-button')),
    );

    expect(googleButton.onPressed, isNull);
    expect(submitButton.onPressed, isNull);

    pending.complete(null);

    await tester.pumpAndSettle();

    expect(viewModel.isLoading, isFalse);

    final enabledGoogleButton = tester.widget<OutlinedButton>(
      find.byKey(const Key('login-google-button')),
    );

    expect(enabledGoogleButton.onPressed, isNotNull);
  });

  testWidgets('muestra un error controlado de Google', (tester) async {
    repository.googleError = const AuthFailure(
      'No fue posible conectar con Google.',
    );

    await pumpLogin(tester);

    await tapGoogle(tester);
    await tester.pumpAndSettle();

    expect(repository.googleCalls, 1);

    expect(find.text('No fue posible conectar con Google.'), findsOneWidget);

    expect(viewModel.isAuthenticated, isFalse);
  });

  testWidgets('conserva el método de registro por correo', (tester) async {
    await pumpLogin(tester);

    final createAccount = find.byKey(const Key('login-create-account-button'));

    await tester.ensureVisible(createAccount);
    await tester.pumpAndSettle();

    expect(createAccount, findsOneWidget);
    expect(find.byKey(const Key('login-google-button')), findsOneWidget);
  });
}

class _FakeLoginGoogleRepository
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthEmailVerificationRepository,
        AuthGoogleSignInRepository {
  final StreamController<bool> _authChanges = StreamController<bool>.broadcast(
    sync: true,
  );

  final StreamController<String?> _identityChanges =
      StreamController<String?>.broadcast(sync: true);

  String? _uid;

  String? nextGoogleUserId = 'uid-google';
  Completer<String?>? pendingGoogle;
  Object? googleError;

  int googleCalls = 0;

  @override
  bool get isAuthenticated => _uid != null;

  @override
  String? get currentUserId => _uid;

  @override
  String? get currentUserEmail => _uid == null ? null : 'prueba@example.com';

  @override
  bool get isCurrentUserEmailVerified => true;

  @override
  Stream<bool> get authStateChanges => _authChanges.stream;

  @override
  Stream<String?> get userIdChanges => _identityChanges.stream;

  void _setIdentity(String? uid) {
    _uid = uid;

    _authChanges.add(uid != null);
    _identityChanges.add(uid);
  }

  @override
  Future<String?> signInWithGoogleObserved({
    required void Function() onExecutionStarted,
  }) async {
    onExecutionStarted();
    googleCalls++;

    final error = googleError;

    if (error != null) {
      throw error;
    }

    final pending = pendingGoogle;

    final uid = pending == null ? nextGoogleUserId : await pending.future;

    if (uid != null) {
      _setIdentity(uid);
    }

    return uid;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    _setIdentity('uid-password');
  }

  @override
  Future<void> signOut() async {
    _setIdentity(null);
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> refreshEmailVerificationStatus() async => true;

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}
