import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  late _FakeGoogleAuthRepository repository;
  late AuthViewModel viewModel;

  setUp(() {
    repository = _FakeGoogleAuthRepository();
    viewModel = AuthViewModel(repository);
  });

  tearDown(() async {
    viewModel.dispose();
    await repository.dispose();
  });

  test('autentica mediante Google con el UID correspondiente', () async {
    final result = await viewModel.signInWithGoogle();

    expect(result, isTrue);
    expect(repository.googleCalls, 1);
    expect(viewModel.isAuthenticated, isTrue);
    expect(viewModel.currentUserId, 'uid-google');
    expect(viewModel.isAuthenticatedAppReady, isTrue);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isLoading, isFalse);
  });

  test('la cancelación no muestra un error', () async {
    repository.nextGoogleUserId = null;

    final result = await viewModel.signInWithGoogle();

    expect(result, isFalse);
    expect(viewModel.isAuthenticated, isFalse);
    expect(viewModel.currentUserId, isNull);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isLoading, isFalse);
  });

  test('mantiene el indicador de carga durante la solicitud', () async {
    final completer = Completer<String?>();
    repository.pendingGoogle = completer;

    final pending = viewModel.signInWithGoogle();

    expect(viewModel.isLoading, isTrue);
    expect(repository.googleCalls, 1);

    completer.complete('uid-google');

    expect(await pending, isTrue);
    expect(viewModel.isLoading, isFalse);
  });

  test('presenta errores controlados del repositorio', () async {
    repository.googleFailure = const AuthFailure(
      'No fue posible conectar con Google.',
    );

    final result = await viewModel.signInWithGoogle();

    expect(result, isFalse);
    expect(viewModel.errorMessage, 'No fue posible conectar con Google.');
    expect(viewModel.isAuthenticated, isFalse);
    expect(viewModel.isLoading, isFalse);
  });

  test('no revela errores técnicos inesperados', () async {
    repository.googleFailure = StateError('Detalle interno confidencial');

    final result = await viewModel.signInWithGoogle();

    expect(result, isFalse);
    expect(
      viewModel.errorMessage,
      'No fue posible iniciar sesión con Google. '
      'Inténtalo nuevamente.',
    );
    expect(viewModel.errorMessage, isNot(contains('confidencial')));
  });

  test('impide aprobar una operación obsoleta A-B-A', () async {
    repository.setIdentity('uid-a');

    final completer = Completer<String?>();
    repository.pendingGoogle = completer;

    final pending = viewModel.signInWithGoogle();

    repository.setIdentity('uid-b');
    repository.setIdentity('uid-a');

    completer.complete('uid-a');

    final result = await pending;

    expect(result, isFalse);
    expect(viewModel.currentUserId, 'uid-a');
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isLoading, isFalse);
  });

  test('no habilita la aplicación si el correo no está verificado', () async {
    repository.emailVerified = false;

    final result = await viewModel.signInWithGoogle();

    expect(result, isTrue);
    expect(viewModel.isAuthenticated, isTrue);
    expect(viewModel.isEmailVerified, isFalse);
    expect(viewModel.isAuthenticatedAppReady, isFalse);
  });
}

class _FakeGoogleAuthRepository
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

  bool emailVerified = true;
  String? nextGoogleUserId = 'uid-google';

  Object? googleFailure;
  Completer<String?>? pendingGoogle;

  int googleCalls = 0;

  @override
  bool get isAuthenticated => _uid != null;

  @override
  String? get currentUserId => _uid;

  @override
  String? get currentUserEmail => _uid == null ? null : 'prueba@example.com';

  @override
  bool get isCurrentUserEmailVerified => emailVerified;

  @override
  Stream<bool> get authStateChanges => _authChanges.stream;

  @override
  Stream<String?> get userIdChanges => _identityChanges.stream;

  void setIdentity(String? uid) {
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

    final error = googleFailure;

    if (error != null) {
      throw error;
    }

    final pending = pendingGoogle;
    final resultUserId = pending == null
        ? nextGoogleUserId
        : await pending.future;

    if (resultUserId != null) {
      setIdentity(resultUserId);
    }

    return resultUserId;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    setIdentity('uid-password');
  }

  @override
  Future<void> signOut() async {
    setIdentity(null);
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> refreshEmailVerificationStatus() async {
    return emailVerified;
  }

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}
