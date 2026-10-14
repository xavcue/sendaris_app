import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:sendaris/features/auth/data/services/firebase_auth_service.dart';

void main() {
  group('FirebaseAuthRepository - aislamiento de validaciones', () {
    late _ControlledFirebaseAuthService service;
    late FirebaseAuthRepository repository;

    setUp(() {
      service = _ControlledFirebaseAuthService();
      repository = FirebaseAuthRepository(service);
    });

    tearDown(() async {
      await service.dispose();
    });

    test('una sesion invalida vigente se cierra correctamente', () async {
      final operation = repository.validateCurrentSession();

      service.failValidation(FirebaseAuthException(code: 'user-disabled'));

      final result = await operation;

      expect(result, isFalse);
      expect(service.signOutCalls, 1);
      expect(repository.currentUserId, isNull);
    });

    test('un error tardio de A no cierra la sesion de B', () async {
      final operation = repository.validateCurrentSession();

      service.changeUser(_FakeUser('uid-b'));

      service.failValidation(FirebaseAuthException(code: 'user-disabled'));

      final result = await operation;

      expect(
        result,
        isTrue,
        reason:
            'La validacion antigua de A no debe '
            'invalidar la sesion vigente de B.',
      );

      expect(service.signOutCalls, 0);
      expect(repository.currentUserId, 'uid-b');
      expect(repository.isAuthenticated, isTrue);
    });

    test(
      'A a B a A no acepta una invalidacion de la sesion anterior',
      () async {
        final originalUser = service.currentUser;

        final operation = repository.validateCurrentSession();

        service.changeUser(_FakeUser('uid-b'));

        // Se reutiliza deliberadamente el mismo objeto para
        // comprobar que comparar solo el UID o la referencia
        // del usuario no es suficiente.
        service.changeUser(originalUser);

        service.failValidation(
          FirebaseAuthException(code: 'invalid-user-token'),
        );

        final result = await operation;

        expect(
          result,
          isTrue,
          reason:
              'El regreso al mismo UID debe constituir '
              'un contexto de autenticacion diferente.',
        );

        expect(service.signOutCalls, 0);
        expect(repository.currentUserId, 'uid-a');
        expect(repository.isAuthenticated, isTrue);
      },
    );

    test('un error de red antiguo de A no afecta la validacion de B', () async {
      final operation = repository.validateCurrentSession();

      service.changeUser(_FakeUser('uid-b'));

      service.failValidation(
        FirebaseAuthException(code: 'network-request-failed'),
      );

      final result = await operation;

      expect(
        result,
        isTrue,
        reason:
            'El error de red corresponde a A, '
            'no a la sesion actualmente autenticada.',
      );

      expect(service.signOutCalls, 0);
      expect(repository.currentUserId, 'uid-b');
    });
  });
}

class _ControlledFirebaseAuthService extends FirebaseAuthService {
  _ControlledFirebaseAuthService() : super(_UnusedFirebaseAuth());

  final StreamController<User?> _changes = StreamController<User?>.broadcast(
    sync: true,
  );

  final Completer<void> _validation = Completer<void>();

  User? _user = _FakeUser('uid-a');

  int signOutCalls = 0;

  @override
  User? get currentUser => _user;

  @override
  Stream<User?> get authStateChanges => _changes.stream;

  void changeUser(User? user) {
    _user = user;
    _changes.add(user);
  }

  void failValidation(Object error) {
    _validation.completeError(error);
  }

  @override
  Future<void> reloadCurrentUser() {
    return _validation.future;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    changeUser(null);
  }

  Future<void> dispose() async {
    await _changes.close();
  }
}

class _UnusedFirebaseAuth extends Fake implements FirebaseAuth {}

class _FakeUser extends Fake implements User {
  _FakeUser(this.uid);

  @override
  final String uid;
}
