import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('AuthViewModel - aislamiento del indicador de carga', () {
    late _PendingAccountRepository repository;
    late AuthViewModel viewModel;

    setUp(() {
      repository = _PendingAccountRepository();
      viewModel = AuthViewModel(repository);
    });

    tearDown(() async {
      viewModel.dispose();
      await repository.dispose();
    });

    test('cambiar de A a B libera el indicador de carga de A', () async {
      final operationA = viewModel.deleteCurrentAccount();

      expect(viewModel.isLoading, isTrue);
      expect(repository.deleteCalls, ['uid-a']);

      repository.changeAccount('uid-b');

      final loadingAfterSwitch = viewModel.isLoading;

      repository.completeDeletion('uid-a');

      final resultA = await operationA;

      expect(resultA, isFalse);

      expect(
        loadingAfterSwitch,
        isFalse,
        reason:
            'La cuenta B no debe heredar el estado '
            'de carga de una eliminacion iniciada por A.',
      );

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.isAuthenticated, isTrue);
    });

    test('el final de la eliminacion de A no oculta '
        'el progreso de la eliminacion de B', () async {
      final operationA = viewModel.deleteCurrentAccount();

      repository.changeAccount('uid-b');

      final operationB = viewModel.deleteCurrentAccount();

      expect(repository.deleteCalls, ['uid-a', 'uid-b']);

      repository.completeDeletion('uid-a');

      final resultA = await operationA;

      final loadingWhileBIsPending = viewModel.isLoading;

      repository.completeDeletion('uid-b');

      final resultB = await operationB;

      expect(resultA, isFalse);

      expect(
        loadingWhileBIsPending,
        isTrue,
        reason:
            'La finalizacion de A no debe desactivar '
            'el indicador de una operacion pendiente de B.',
      );

      expect(resultB, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.errorMessage, isNull);
    });

    test('el final de la eliminacion de A no oculta '
        'la reautenticacion pendiente de B', () async {
      final operationA = viewModel.deleteCurrentAccount();

      repository.changeAccount('uid-b');

      final reauthenticationB = viewModel.reauthenticateWithPassword(
        password: 'PasswordDePrueba123!',
      );

      expect(repository.reauthenticationCalls, ['uid-b']);

      repository.completeDeletion('uid-a');

      final resultA = await operationA;

      final loadingWhileBIsPending = viewModel.isLoading;

      repository.completeReauthentication();

      final resultB = await reauthenticationB;

      expect(resultA, isFalse);

      expect(
        loadingWhileBIsPending,
        isTrue,
        reason:
            'La eliminacion antigua de A no debe '
            'ocultar el progreso de la reautenticacion de B.',
      );

      expect(resultB, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.errorMessage, isNull);
    });
  });
}

class _PendingAccountRepository
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthAccountManagementRepository {
  final StreamController<bool> _authChanges = StreamController<bool>.broadcast(
    sync: true,
  );

  final StreamController<String?> _identityChanges =
      StreamController<String?>.broadcast(sync: true);

  final Map<String, Completer<void>> _deletionGates = {
    'uid-a': Completer<void>(),
    'uid-b': Completer<void>(),
  };

  final Completer<void> _reauthenticationGate = Completer<void>();

  final List<String?> deleteCalls = [];

  final List<String?> reauthenticationCalls = [];

  String? _userId = 'uid-a';

  @override
  bool get isAuthenticated => _userId != null;

  @override
  String? get currentUserId => _userId;

  @override
  Stream<bool> get authStateChanges => _authChanges.stream;

  @override
  Stream<String?> get userIdChanges => _identityChanges.stream;

  void changeAccount(String? userId) {
    _userId = userId;

    _identityChanges.add(userId);
    _authChanges.add(userId != null);
  }

  void completeDeletion(String userId) {
    _deletionGates[userId]!.complete();
  }

  void completeReauthentication() {
    _reauthenticationGate.complete();
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
  Future<void> reauthenticateWithPassword({required String password}) async {
    reauthenticationCalls.add(_userId);

    await _reauthenticationGate.future;
  }

  @override
  Future<void> deleteCurrentAccount() async {
    final requestedUserId = _userId;

    deleteCalls.add(requestedUserId);

    await _deletionGates[requestedUserId]!.future;
  }

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}
