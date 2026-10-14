import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/auth/data/services/firebase_auth_service.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('AuthViewModel - aislamiento al eliminar cuentas', () {
    late _ControlledAccountRepository repository;
    late AuthViewModel viewModel;

    setUp(() {
      repository = _ControlledAccountRepository();
      viewModel = AuthViewModel(repository);
    });

    tearDown(() async {
      viewModel.dispose();
      await repository.dispose();
    });

    test('eliminar A sin cambios de sesion conserva el resultado', () async {
      final operation = viewModel.deleteCurrentAccount();

      expect(viewModel.isLoading, isTrue);
      expect(repository.deleteCalls, ['uid-a']);

      repository.completeDeletion();

      expect(await operation, isTrue);
      expect(viewModel.currentUserId, 'uid-a');
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test(
      'eliminar A con cierre de sesion esperado conserva el exito',
      () async {
        repository.logoutOnSuccessfulDeletion = true;

        final operation = viewModel.deleteCurrentAccount();

        repository.completeDeletion();

        expect(await operation, isTrue);
        expect(viewModel.isAuthenticated, isFalse);
        expect(viewModel.currentUserId, isNull);
        expect(viewModel.errorMessage, isNull);
        expect(viewModel.isLoading, isFalse);
      },
    );

    test('un resultado tardio de A no confirma la eliminacion en B', () async {
      final operation = viewModel.deleteCurrentAccount();

      repository.changeAccount('uid-b');

      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.isAuthenticated, isTrue);

      repository.completeDeletion();

      expect(
        await operation,
        isFalse,
        reason:
            'Una operacion iniciada por A no debe '
            'confirmarse dentro de la sesion B.',
      );

      expect(repository.deleteCalls, ['uid-a']);
      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.errorMessage, isNull);
    });

    test('A a B a A no reutiliza una eliminacion antigua', () async {
      final operation = viewModel.deleteCurrentAccount();

      repository.changeAccount('uid-b');
      repository.changeAccount('uid-a');

      repository.completeDeletion();

      expect(
        await operation,
        isFalse,
        reason:
            'La sesion A actual es distinta de '
            'la que inicio la eliminacion.',
      );

      expect(repository.deleteCalls, ['uid-a']);
      expect(viewModel.currentUserId, 'uid-a');
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.errorMessage, isNull);
    });

    test('un error tardio de A no se muestra en B', () async {
      final operation = viewModel.deleteCurrentAccount();

      repository.changeAccount('uid-b');

      repository.failDeletion(
        const AuthFailure('No fue posible eliminar la cuenta anterior.'),
      );

      expect(await operation, isFalse);

      expect(
        viewModel.errorMessage,
        isNull,
        reason:
            'Los errores de A no deben permanecer '
            'en el contexto autenticado de B.',
      );

      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.isAuthenticated, isTrue);
    });
  });

  group('FirebaseAuthService - identidad de eliminacion', () {
    test('la eliminacion iniciada por A no invoca delete sobre B', () async {
      final userA = _ControlledUser('uid-a');
      final userB = _ControlledUser('uid-b');

      final firebaseAuth = _ControlledFirebaseAuth(userA);
      final service = FirebaseAuthService(firebaseAuth);

      final operation = service.deleteCurrentUser();

      expect(userA.deleteCalls, 1);
      expect(userB.deleteCalls, 0);

      firebaseAuth.current = userB;

      userA.completeDeletion();

      await operation;

      expect(userA.deleteCalls, 1);
      expect(userB.deleteCalls, 0);
      expect(firebaseAuth.currentUser?.uid, 'uid-b');
    });

    test('no permite eliminar sin una cuenta autenticada', () async {
      final firebaseAuth = _ControlledFirebaseAuth(null);
      final service = FirebaseAuthService(firebaseAuth);

      await expectLater(
        service.deleteCurrentUser(),
        throwsA(isA<StateError>()),
      );
    });
  });
}

class _ControlledAccountRepository
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthAccountManagementRepository {
  final StreamController<bool> _authChanges = StreamController<bool>.broadcast(
    sync: true,
  );

  final StreamController<String?> _identityChanges =
      StreamController<String?>.broadcast(sync: true);

  final Completer<void> _deletionGate = Completer<void>();

  final List<String?> deleteCalls = [];

  String? _userId = 'uid-a';

  bool logoutOnSuccessfulDeletion = false;

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

  void completeDeletion() {
    _deletionGate.complete();
  }

  void failDeletion(Object error) {
    _deletionGate.completeError(error);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    changeAccount('uid-login');
  }

  @override
  Future<void> signOut() async {
    changeAccount(null);
  }

  @override
  Future<void> reauthenticateWithPassword({required String password}) async {}

  @override
  Future<void> deleteCurrentAccount() async {
    deleteCalls.add(_userId);

    await _deletionGate.future;

    if (logoutOnSuccessfulDeletion) {
      changeAccount(null);
    }
  }

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}

class _ControlledFirebaseAuth extends Fake implements FirebaseAuth {
  _ControlledFirebaseAuth(this.current);

  User? current;

  @override
  User? get currentUser => current;
}

class _ControlledUser extends Fake implements User {
  _ControlledUser(this.uid);

  @override
  final String uid;

  final Completer<void> _deletionGate = Completer<void>();

  int deleteCalls = 0;

  @override
  Future<void> delete() {
    deleteCalls++;

    return _deletionGate.future;
  }

  void completeDeletion() {
    _deletionGate.complete();
  }
}
