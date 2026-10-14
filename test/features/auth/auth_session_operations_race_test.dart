import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('AuthViewModel - concurrencia de operaciones de sesion', () {
    late _PendingAuthenticationRepository repository;
    late AuthViewModel viewModel;

    const password = 'MiPasswordSegura123!';

    setUp(() {
      repository = _PendingAuthenticationRepository();
      viewModel = AuthViewModel(repository);
    });

    tearDown(() async {
      viewModel.dispose();
      await repository.dispose();
    });

    test('un inicio de sesion legitimo acepta su nuevo UID', () async {
      repository.applySignInOnCompletion = true;

      final operation = viewModel.signIn(
        email: 'acceso@example.com',
        password: password,
      );

      expect(viewModel.isLoading, isTrue);

      repository.completeSignIn();

      expect(await operation, isTrue);
      expect(viewModel.currentUserId, 'uid-login');
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('un inicio de sesion antiguo no confirma el acceso en B', () async {
      final operation = viewModel.signIn(
        email: 'cuenta-a@example.com',
        password: password,
      );

      repository.changeAccount('uid-b');
      repository.completeSignIn();

      expect(
        await operation,
        isFalse,
        reason:
            'El resultado del intento anterior no debe '
            'confirmar un acceso en una sesion distinta.',
      );

      expect(repository.signInCalls, ['cuenta-a@example.com']);
      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('un error tardio de inicio de sesion no aparece en B', () async {
      final operation = viewModel.signIn(
        email: 'cuenta-a@example.com',
        password: password,
      );

      repository.changeAccount('uid-b');

      repository.failSignIn(
        const AuthFailure('Error del inicio de sesion anterior.'),
      );

      expect(await operation, isFalse);
      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.errorMessage, isNull);
    });

    test('un registro legitimo acepta la nueva cuenta provisional', () async {
      repository.applyRegistrationOnCompletion = true;

      final operation = viewModel.createUnverifiedAccount(
        email: 'nueva@example.com',
        password: password,
        passwordConfirmation: password,
      );

      repository.completeRegistration();

      expect(await operation, isTrue);
      expect(viewModel.currentUserId, 'uid-registro');
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('un registro antiguo no confirma el registro en B', () async {
      final operation = viewModel.createUnverifiedAccount(
        email: 'nueva@example.com',
        password: password,
        passwordConfirmation: password,
      );

      repository.changeAccount('uid-b');
      repository.completeRegistration();

      expect(
        await operation,
        isFalse,
        reason:
            'El registro iniciado en un contexto anterior '
            'no debe confirmarse dentro de B.',
      );

      expect(repository.registrationCalls, ['nueva@example.com']);
      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.errorMessage, isNull);
    });

    test('un error antiguo de registro no aparece en B', () async {
      final operation = viewModel.createUnverifiedAccount(
        email: 'nueva@example.com',
        password: password,
        passwordConfirmation: password,
      );

      repository.changeAccount('uid-b');

      repository.failRegistration(
        const AuthFailure('Error del registro anterior.'),
      );

      expect(await operation, isFalse);
      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.errorMessage, isNull);
    });

    test('un cierre de sesion legitimo finaliza correctamente', () async {
      repository.changeAccount('uid-a');
      repository.applySignOutOnCompletion = true;

      final operation = viewModel.signOut();

      repository.completeSignOut();

      expect(await operation, isTrue);
      expect(viewModel.currentUserId, isNull);
      expect(viewModel.isAuthenticated, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('el cierre de A no se confirma dentro de B', () async {
      repository.changeAccount('uid-a');

      final operation = viewModel.signOut();

      repository.changeAccount('uid-b');
      repository.completeSignOut();

      expect(
        await operation,
        isFalse,
        reason:
            'Un cierre iniciado en A no debe considerarse '
            'un cierre valido de la sesion B.',
      );

      expect(repository.signOutCalls, ['uid-a']);
      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('un error tardio de cierre de A no aparece en B', () async {
      repository.changeAccount('uid-a');

      final operation = viewModel.signOut();

      repository.changeAccount('uid-b');

      repository.failSignOut(
        const AuthFailure('Error del cierre de sesion anterior.'),
      );

      expect(await operation, isFalse);
      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.errorMessage, isNull);
    });

    test('A a B a A no reutiliza un cierre de sesion anterior', () async {
      repository.changeAccount('uid-a');

      final operation = viewModel.signOut();

      repository.changeAccount('uid-b');
      repository.changeAccount('uid-a');

      repository.completeSignOut();

      expect(
        await operation,
        isFalse,
        reason:
            'La nueva sesion de A no debe reutilizar '
            'una operacion iniciada en la sesion anterior.',
      );

      expect(repository.signOutCalls, ['uid-a']);
      expect(viewModel.currentUserId, 'uid-a');
      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.errorMessage, isNull);
    });

    test('un acceso no reutiliza el UID despues de A a B a A', () async {
      final operation = viewModel.signIn(
        email: 'cuenta-a@example.com',
        password: password,
      );

      repository.changeAccount('uid-login');
      repository.changeAccount('uid-b');
      repository.changeAccount('uid-login');
      repository.completeSignIn();

      expect(await operation, isFalse);
      expect(viewModel.currentUserId, 'uid-login');
      expect(viewModel.errorMessage, isNull);
    });

    test('un registro no reutiliza el UID despues de A a B a A', () async {
      final operation = viewModel.createUnverifiedAccount(
        email: 'nueva@example.com',
        password: password,
        passwordConfirmation: password,
      );

      repository.changeAccount('uid-registro');
      repository.changeAccount('uid-b');
      repository.changeAccount('uid-registro');
      repository.completeRegistration();

      expect(await operation, isFalse);
      expect(viewModel.currentUserId, 'uid-registro');
      expect(viewModel.errorMessage, isNull);
    });

    test('dos accesos al mismo UID no aceptan el intento sustituido', () async {
      repository.changeAccount('uid-login');

      final first = viewModel.signIn(
        email: 'cuenta-a@example.com',
        password: password,
      );
      final second = viewModel.signIn(
        email: 'cuenta-a@example.com',
        password: password,
      );

      repository.completeSignIn(index: 1);
      expect(await second, isTrue);

      repository.completeSignIn();
      expect(await first, isFalse);
      expect(repository.signInCalls, hasLength(2));
      expect(viewModel.currentUserId, 'uid-login');
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isFalse);
    });

    test(
      'un error sustituido no contamina ni termina la carga nueva',
      () async {
        final first = viewModel.signIn(
          email: 'cuenta-a@example.com',
          password: password,
        );
        final second = viewModel.signIn(
          email: 'cuenta-a@example.com',
          password: password,
        );

        repository.failSignIn(
          const AuthFailure('Error del intento sustituido.'),
        );

        expect(await first, isFalse);
        expect(viewModel.errorMessage, isNull);
        expect(viewModel.isLoading, isTrue);

        repository.applySignInOnCompletion = true;
        repository.completeSignIn(index: 1);

        expect(await second, isTrue);
        expect(viewModel.currentUserId, 'uid-login');
        expect(viewModel.errorMessage, isNull);
        expect(viewModel.isLoading, isFalse);
      },
    );

    test('un error inesperado antiguo de registro no aparece en B', () async {
      final operation = viewModel.createUnverifiedAccount(
        email: 'nueva@example.com',
        password: password,
        passwordConfirmation: password,
      );

      repository.changeAccount('uid-b');
      repository.failRegistration(StateError('Error inesperado anterior.'));

      expect(await operation, isFalse);
      expect(viewModel.currentUserId, 'uid-b');
      expect(viewModel.errorMessage, isNull);
    });

    test('un error del intento vigente si se comunica', () async {
      final operation = viewModel.signIn(
        email: 'cuenta-a@example.com',
        password: password,
      );

      repository.failSignIn(const AuthFailure('Error del intento vigente.'));

      expect(await operation, isFalse);
      expect(viewModel.errorMessage, 'Error del intento vigente.');
      expect(viewModel.isLoading, isFalse);
    });
  });
}

class _PendingAuthenticationRepository
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthIdentitySessionOperationsRepository,
        AuthRegistrationRepository {
  final StreamController<bool> _authChanges = StreamController<bool>.broadcast(
    sync: true,
  );

  final StreamController<String?> _identityChanges =
      StreamController<String?>.broadcast(sync: true);

  final List<Completer<void>> _signInGates = [];
  final Completer<void> _registrationGate = Completer<void>();
  final Completer<void> _signOutGate = Completer<void>();

  final List<String> signInCalls = [];
  final List<String> registrationCalls = [];
  final List<String?> signOutCalls = [];

  String? _userId;

  bool applySignInOnCompletion = false;
  bool applyRegistrationOnCompletion = false;
  bool applySignOutOnCompletion = false;

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

  void completeSignIn({int index = 0}) {
    _signInGates[index].complete();
  }

  void failSignIn(Object error, {int index = 0}) {
    _signInGates[index].completeError(error);
  }

  void completeRegistration() {
    _registrationGate.complete();
  }

  void failRegistration(Object error) {
    _registrationGate.completeError(error);
  }

  void completeSignOut() {
    _signOutGate.complete();
  }

  void failSignOut(Object error) {
    _signOutGate.completeError(error);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    signInCalls.add(email);

    final gate = Completer<void>();
    _signInGates.add(gate);

    await gate.future;

    if (applySignInOnCompletion) {
      changeAccount('uid-login');
    }
  }

  @override
  Future<void> createUnverifiedAccount({
    required String email,
    required String password,
  }) async {
    registrationCalls.add(email);

    await _registrationGate.future;

    if (applyRegistrationOnCompletion) {
      changeAccount('uid-registro');
    }
  }

  @override
  Future<String> signInAndGetUserId({
    required String email,
    required String password,
  }) async {
    await signIn(email: email, password: password);

    // Identidad de esta solicitud, aunque ahora este autenticada B.
    return 'uid-login';
  }

  @override
  Future<String> createUnverifiedAccountAndGetUserId({
    required String email,
    required String password,
  }) async {
    await createUnverifiedAccount(email: email, password: password);

    return 'uid-registro';
  }

  @override
  Future<void> signOut() async {
    signOutCalls.add(_userId);

    await _signOutGate.future;

    if (applySignOutOnCompletion) {
      changeAccount(null);
    }
  }

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}
