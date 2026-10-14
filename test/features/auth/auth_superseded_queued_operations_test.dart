import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:sendaris/features/auth/data/services/firebase_auth_service.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';

void main() {
  group('AuthViewModel - operaciones sustituidas en cola', () {
    test('solo el ultimo acceso solicitado puede ejecutarse '
        'despues de un cierre pendiente', () async {
      final firebaseAuth = _QueuedFirebaseAuth();

      final service = FirebaseAuthService(firebaseAuth);
      final repository = FirebaseAuthRepository(service);
      final viewModel = AuthViewModel(repository);

      addTearDown(() async {
        viewModel.dispose();
        await firebaseAuth.dispose();
      });

      expect(viewModel.currentUserId, 'uid-a');
      expect(viewModel.isAuthenticated, isTrue);

      // El cierre de A comienza y permanece pendiente.
      final closing = viewModel.signOut();

      await firebaseAuth.signOutStarted.future;

      // Este acceso queda primero en la cola.
      final obsoleteSignIn = viewModel.signIn(
        email: 'primero@example.com',
        password: 'PasswordSegura123!',
      );

      // La solicitud posterior sustituye a la anterior.
      final latestSignIn = viewModel.signIn(
        email: 'segundo@example.com',
        password: 'PasswordSegura123!',
      );

      expect(firebaseAuth.signInEmails, isEmpty);

      // Permitimos que termine el cierre de A.
      firebaseAuth.completeSignOut();

      final obsoleteResult = await obsoleteSignIn;
      final latestResult = await latestSignIn;
      final closingResult = await closing;

      expect(
        obsoleteResult,
        isFalse,
        reason:
            'Una solicitud sustituida no debe '
            'confirmar un inicio de sesión.',
      );

      expect(
        latestResult,
        isTrue,
        reason:
            'La solicitud vigente debe poder '
            'autenticar su propia identidad.',
      );

      expect(
        closingResult,
        isFalse,
        reason:
            'El resultado anterior fue sustituido '
            'por una operación de sesión posterior.',
      );

      expect(
        firebaseAuth.signInEmails,
        <String>['segundo@example.com'],
        reason:
            'La solicitud antigua no debe llegar '
            'a ejecutar signInWithEmailAndPassword.',
      );

      expect(viewModel.currentUserId, 'uid-c');

      expect(firebaseAuth.currentUser?.uid, 'uid-c');

      expect(viewModel.isAuthenticated, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
    });
  });
}

class _QueuedFirebaseAuth extends Fake implements FirebaseAuth {
  _QueuedFirebaseAuth()
    : _currentUser = _QueuedUser(uid: 'uid-a', email: 'a@example.com');

  User? _currentUser;

  final StreamController<User?> _changes = StreamController<User?>.broadcast(
    sync: true,
  );

  final Completer<void> signOutStarted = Completer<void>();
  final Completer<void> _signOutGate = Completer<void>();

  final List<String> signInEmails = <String>[];

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => _changes.stream;

  void _changeUser(User? user) {
    _currentUser = user;
    _changes.add(user);
  }

  void completeSignOut() {
    if (!_signOutGate.isCompleted) {
      _signOutGate.complete();
    }
  }

  @override
  Future<void> signOut() async {
    if (!signOutStarted.isCompleted) {
      signOutStarted.complete();
    }

    await _signOutGate.future;

    _changeUser(null);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInEmails.add(email);

    final user = _QueuedUser(
      uid: email == 'primero@example.com' ? 'uid-b' : 'uid-c',
      email: email,
    );

    _changeUser(user);

    return _QueuedUserCredential(user);
  }

  Future<void> dispose() => _changes.close();
}

class _QueuedUser extends Fake implements User {
  _QueuedUser({required this.uid, required this.email});

  @override
  final String uid;

  @override
  final String email;

  @override
  bool get emailVerified => true;

  @override
  Future<void> reload() async {}

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    return 'token-ficticio-$uid';
  }
}

class _QueuedUserCredential extends Fake implements UserCredential {
  _QueuedUserCredential(this.user);

  @override
  final User user;
}
