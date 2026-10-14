import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('AuthViewModel - operaciones pendientes por identidad', () {
    late _ControlledIdentityRepository repository;
    late AuthViewModel viewModel;

    setUp(() {
      repository = _ControlledIdentityRepository();
      viewModel = AuthViewModel(repository);
    });

    tearDown(() async {
      viewModel.dispose();
      await repository.dispose();
    });

    test('cambiar a B durante la comprobacion de A '
        'no cancela ni elimina la cuenta B', () async {
      final operation = viewModel.cancelUnverifiedAccount();

      expect(repository.refreshCalls, ['uid-a']);
      expect(repository.deleteCalls, isEmpty);

      repository.changeAccount('uid-b');

      repository.completeRefresh(false);

      final result = await operation;

      expect(
        result,
        isFalse,
        reason:
            'La comprobacion de A no autoriza '
            'eliminar la cuenta B.',
      );

      expect(repository.deleteCalls, isEmpty);
      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.errorMessage, isNull);
    });

    test('A a B a A no reutiliza una comprobacion antigua '
        'para eliminar una cuenta', () async {
      final operation = viewModel.cancelUnverifiedAccount();

      expect(repository.refreshCalls, ['uid-a']);

      repository.changeAccount('uid-b');
      repository.changeAccount('uid-a');

      repository.completeRefresh(false);

      final result = await operation;

      expect(result, isFalse);

      expect(
        repository.deleteCalls,
        isEmpty,
        reason:
            'Una sesion nueva de A necesita '
            'su propia comprobacion de verificacion.',
      );

      expect(viewModel.currentUserId, 'uid-a');
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.errorMessage, isNull);
    });

    test('una verificacion tardia de A no marca '
        'como verificado el correo de B', () async {
      final operation = viewModel.cancelUnverifiedAccount();

      repository.changeAccount('uid-b');

      expect(viewModel.isEmailVerified, isFalse);
      expect(viewModel.isAuthenticatedAppReady, isFalse);

      // El resultado pertenece a A y no debe
      // modificar el estado de verificacion de B.
      repository.completeRefresh(true);

      final result = await operation;

      expect(result, isFalse);
      expect(repository.deleteCalls, isEmpty);

      expect(
        viewModel.isEmailVerified,
        isFalse,
        reason:
            'La cuenta B sigue sin verificar '
            'su direccion de correo.',
      );

      expect(viewModel.isAuthenticatedAppReady, isFalse);
      expect(viewModel.currentUserId, 'uid-b');
    });

    test('un error tardio al verificar A '
        'no se muestra en B', () async {
      final operation = viewModel.cancelUnverifiedAccount();

      repository.changeAccount('uid-b');

      repository.failRefresh(
        const AuthFailure('No fue posible verificar la cuenta anterior.'),
      );

      final result = await operation;

      expect(result, isFalse);
      expect(repository.deleteCalls, isEmpty);

      expect(
        viewModel.errorMessage,
        isNull,
        reason:
            'El error de la cuenta A no pertenece '
            'al contexto de B.',
      );

      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.isAuthenticated, isTrue);
    });

    test('una reautenticacion tardia de A '
        'no autoriza operaciones de B', () async {
      final operation = viewModel.reauthenticateWithPassword(
        password: 'PasswordDePrueba123!',
      );

      expect(repository.reauthenticationCalls, ['uid-a']);

      repository.changeAccount('uid-b');

      repository.completeReauthentication();

      final result = await operation;

      expect(
        result,
        isFalse,
        reason:
            'La identidad confirmada fue A, '
            'no la sesion actual B.',
      );

      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('un error antiguo de envio de correo '
        'no aparece en B', () async {
      final operation = viewModel.sendEmailVerification();

      expect(repository.sendCalls, ['uid-a']);

      repository.changeAccount('uid-b');

      repository.failSend(
        const AuthFailure('No fue posible enviar el correo de A.'),
      );

      final result = await operation;

      expect(result, isFalse);

      expect(
        viewModel.errorMessage,
        isNull,
        reason:
            'Un fallo de envio anterior '
            'no debe mostrarse en B.',
      );

      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.isEmailVerified, isFalse);
      expect(viewModel.isLoading, isFalse);
    });
  });
}

class _ControlledIdentityRepository
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthEmailVerificationRepository,
        AuthAccountManagementRepository {
  final StreamController<bool> _authChanges = StreamController<bool>.broadcast(
    sync: true,
  );

  final StreamController<String?> _identityChanges =
      StreamController<String?>.broadcast(sync: true);

  final Completer<bool> _refreshGate = Completer<bool>();
  final Completer<void> _reauthenticationGate = Completer<void>();
  final Completer<void> _sendGate = Completer<void>();

  final List<String?> refreshCalls = [];
  final List<String?> deleteCalls = [];
  final List<String?> reauthenticationCalls = [];
  final List<String?> sendCalls = [];

  String? _userId = 'uid-a';

  final Map<String, bool> _verified = {'uid-a': false, 'uid-b': false};

  @override
  bool get isAuthenticated => _userId != null;

  @override
  String? get currentUserId => _userId;

  @override
  Stream<bool> get authStateChanges => _authChanges.stream;

  @override
  Stream<String?> get userIdChanges => _identityChanges.stream;

  @override
  String? get currentUserEmail {
    final uid = _userId;

    if (uid == null) {
      return null;
    }

    return '$uid@example.com';
  }

  @override
  bool get isCurrentUserEmailVerified {
    return _verified[_userId] ?? false;
  }

  void changeAccount(String? userId) {
    _userId = userId;

    _identityChanges.add(userId);
    _authChanges.add(userId != null);
  }

  void completeRefresh(bool verified) {
    _refreshGate.complete(verified);
  }

  void failRefresh(Object error) {
    _refreshGate.completeError(error);
  }

  void completeReauthentication() {
    _reauthenticationGate.complete();
  }

  void failSend(Object error) {
    _sendGate.completeError(error);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    changeAccount('uid-b');
  }

  @override
  Future<void> signOut() async {
    changeAccount(null);
  }

  @override
  Future<void> sendEmailVerification() async {
    sendCalls.add(_userId);

    await _sendGate.future;
  }

  @override
  Future<bool> refreshEmailVerificationStatus() async {
    // La solicitud queda asociada a la cuenta
    // autenticada cuando comienza.
    refreshCalls.add(_userId);

    return _refreshGate.future;
  }

  @override
  Future<void> reauthenticateWithPassword({required String password}) async {
    reauthenticationCalls.add(_userId);

    await _reauthenticationGate.future;
  }

  @override
  Future<void> deleteCurrentAccount() async {
    // Registramos el UID vigente al momento de borrar.
    // Esto permite detectar si una solicitud antigua
    // intenta eliminar una cuenta nueva.
    deleteCalls.add(_userId);

    changeAccount(null);
  }

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}
