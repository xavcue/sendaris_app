import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  late _FakeGoogleAccountRepository repository;
  late AuthViewModel viewModel;

  setUp(() {
    repository = _FakeGoogleAccountRepository();
    viewModel = AuthViewModel(repository);
  });

  tearDown(() async {
    viewModel.dispose();
    await repository.dispose();
  });

  test('reconoce una cuenta autenticada con Google', () {
    expect(viewModel.isAuthenticated, isTrue);
    expect(viewModel.currentUserId, 'uid-a');
    expect(viewModel.canReauthenticateWithGoogle, isTrue);
  });

  test('no ofrece Google si el proveedor no está disponible', () async {
    repository.googleEnabled = false;

    expect(viewModel.canReauthenticateWithGoogle, isFalse);

    final result = await viewModel.reauthenticateWithGoogle();

    expect(result, isFalse);
    expect(repository.reauthenticationCalls, 0);
    expect(
      viewModel.errorMessage,
      'La confirmación con Google no está disponible para esta cuenta.',
    );
  });

  test('confirma la identidad y conserva el UID original', () async {
    final result = await viewModel.reauthenticateWithGoogle();

    expect(result, isTrue);
    expect(repository.reauthenticationCalls, 1);
    expect(viewModel.currentUserId, 'uid-a');
    expect(viewModel.isAuthenticated, isTrue);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isLoading, isFalse);
  });

  test('cancelar Google no crea un error', () async {
    repository.nextResult = false;

    final result = await viewModel.reauthenticateWithGoogle();

    expect(result, isFalse);
    expect(repository.reauthenticationCalls, 1);
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.currentUserId, 'uid-a');
    expect(viewModel.isLoading, isFalse);
  });

  test('mantiene la carga mientras espera Google', () async {
    final pending = Completer<bool>();
    repository.pendingResult = pending;

    final resultPending = viewModel.reauthenticateWithGoogle();

    expect(viewModel.isLoading, isTrue);
    expect(repository.reauthenticationCalls, 1);

    pending.complete(true);

    expect(await resultPending, isTrue);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.errorMessage, isNull);
  });

  test('presenta errores controlados del repositorio', () async {
    repository.failure = const AuthFailure(
      'La cuenta de Google seleccionada no coincide con la cuenta actual.',
    );

    final result = await viewModel.reauthenticateWithGoogle();

    expect(result, isFalse);
    expect(
      viewModel.errorMessage,
      'La cuenta de Google seleccionada no coincide con la cuenta actual.',
    );
    expect(viewModel.currentUserId, 'uid-a');
    expect(viewModel.isLoading, isFalse);
  });

  test('no divulga errores técnicos inesperados', () async {
    repository.failure = StateError('Detalle interno que no debe mostrarse');

    final result = await viewModel.reauthenticateWithGoogle();

    expect(result, isFalse);
    expect(
      viewModel.errorMessage,
      'No fue posible confirmar tu identidad con Google. '
      'Inténtalo nuevamente.',
    );
    expect(viewModel.errorMessage, isNot(contains('Detalle interno')));
  });

  test('no reautentica si la sesión se ha cerrado', () async {
    repository.changeIdentity(null);

    expect(viewModel.canReauthenticateWithGoogle, isFalse);

    final result = await viewModel.reauthenticateWithGoogle();

    expect(result, isFalse);
    expect(repository.reauthenticationCalls, 0);
    expect(viewModel.isAuthenticated, isFalse);
  });

  test('rechaza una respuesta obsoleta tras cambiar de A a B', () async {
    final pending = Completer<bool>();
    repository.pendingResult = pending;

    final operationA = viewModel.reauthenticateWithGoogle();

    repository.changeIdentity('uid-b');

    pending.complete(true);

    final result = await operationA;

    expect(result, isFalse);
    expect(viewModel.currentUserId, 'uid-b');
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isLoading, isFalse);
  });

  test('detecta cambios A-B-A durante la reautenticación', () async {
    final pending = Completer<bool>();
    repository.pendingResult = pending;

    final operationA = viewModel.reauthenticateWithGoogle();

    repository.changeIdentity('uid-b');
    repository.changeIdentity('uid-a');

    pending.complete(true);

    final result = await operationA;

    expect(result, isFalse);
    expect(viewModel.currentUserId, 'uid-a');
    expect(viewModel.errorMessage, isNull);
    expect(viewModel.isLoading, isFalse);
  });

  test('no muestra errores de una cuenta anterior', () async {
    final pending = Completer<bool>();
    repository.pendingResult = pending;

    final operationA = viewModel.reauthenticateWithGoogle();

    repository.changeIdentity('uid-b');

    repository.failure = const AuthFailure(
      'Error perteneciente a la cuenta A.',
    );

    pending.complete(true);

    final result = await operationA;

    expect(result, isFalse);
    expect(viewModel.currentUserId, 'uid-b');
    expect(viewModel.errorMessage, isNull);
  });

  test('la finalización de A no oculta la carga de B', () async {
    final pendingA = Completer<bool>();
    repository.pendingResult = pendingA;

    final operationA = viewModel.reauthenticateWithGoogle();

    repository.changeIdentity('uid-b');

    final pendingB = Completer<bool>();
    repository.pendingResult = pendingB;

    final operationB = viewModel.reauthenticateWithGoogle();

    expect(repository.reauthenticationCalls, 2);
    expect(viewModel.isLoading, isTrue);

    pendingA.complete(true);

    expect(await operationA, isFalse);
    expect(viewModel.isLoading, isTrue);
    expect(viewModel.currentUserId, 'uid-b');

    pendingB.complete(true);

    expect(await operationB, isTrue);
    expect(viewModel.isLoading, isFalse);
    expect(viewModel.currentUserId, 'uid-b');
    expect(viewModel.errorMessage, isNull);
  });
}

class _FakeGoogleAccountRepository
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthGoogleAccountManagementRepository {
  final StreamController<bool> _authChanges = StreamController<bool>.broadcast(
    sync: true,
  );

  final StreamController<String?> _identityChanges =
      StreamController<String?>.broadcast(sync: true);

  String? _uid = 'uid-a';

  bool googleEnabled = true;
  bool nextResult = true;

  Object? failure;
  Completer<bool>? pendingResult;

  int reauthenticationCalls = 0;

  @override
  bool get isAuthenticated => _uid != null;

  @override
  String? get currentUserId => _uid;

  @override
  Stream<bool> get authStateChanges => _authChanges.stream;

  @override
  Stream<String?> get userIdChanges => _identityChanges.stream;

  @override
  bool get canReauthenticateWithGoogle => _uid != null && googleEnabled;

  void changeIdentity(String? uid) {
    _uid = uid;

    _identityChanges.add(uid);
    _authChanges.add(uid != null);
  }

  @override
  Future<bool> reauthenticateWithGoogle() async {
    reauthenticationCalls++;

    final pending = pendingResult;

    final result = pending == null ? nextResult : await pending.future;

    final error = failure;

    if (error != null) {
      throw error;
    }

    return result;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    changeIdentity('uid-password');
  }

  @override
  Future<void> signOut() async {
    changeIdentity(null);
  }

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}
