import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/data/services/firebase_auth_service.dart';

void main() {
  group('FirebaseAuthService - aislamiento de operaciones en cola', () {
    late _QueueUser userA;
    late _QueueUser userB;
    late _QueueAuth auth;
    late FirebaseAuthService service;

    setUp(() {
      userA = _QueueUser('uid-a');
      userB = _QueueUser('uid-b');
      auth = _QueueAuth(userA, userB);
      service = FirebaseAuthService(auth);
    });

    tearDown(() async {
      await auth.dispose();
    });

    test('un cierre fallido no bloquea el siguiente acceso', () async {
      auth.signOutGate = Completer<void>();
      auth.signOutError = StateError('Fallo ficticio del cierre.');

      final closing = service.signOut();
      final checked = expectLater(closing, throwsA(isA<StateError>()));
      await auth.signOutStarted.future;

      final signingIn = service.signInAndGetUserId(
        email: 'b@example.com',
        password: 'PasswordFicticia123!',
      );

      auth.signOutGate!.complete();
      await checked;

      expect(await signingIn, 'uid-b');
      expect(auth.signOutCalls, 1);
      expect(auth.signInCalls, 1);
      expect(auth.currentUser?.uid, 'uid-b');
    });

    test(
      'un cierre solicitado en A no se ejecuta sobre B al salir de la cola',
      () async {
        auth.signInGate = Completer<void>();

        final signingIn = service.signInAndGetUserId(
          email: 'b@example.com',
          password: 'PasswordFicticia123!',
        );
        await auth.signInStarted.future;

        final closing = service.signOut();
        final checked = expectLater(closing, throwsA(isA<StateError>()));

        auth.signInGate!.complete();

        expect(await signingIn, 'uid-b');
        await checked;

        expect(auth.signOutCalls, 0);
        expect(auth.currentUser?.uid, 'uid-b');
      },
    );

    test(
      'A a B a A invalida tambien un envio que sigue esperando turno',
      () async {
        userA.reloadGate = Completer<void>();

        final reloading = service.reloadCurrentUser();
        await userA.reloadStarted.future;

        final sending = service.sendCurrentUserEmailVerification();
        final checked = expectLater(sending, throwsA(isA<StateError>()));

        auth.changeUser(userB);
        auth.changeUser(userA);
        userA.reloadGate!.complete();

        await reloading;
        await checked;

        expect(userA.verificationCalls, 0);
        expect(userB.verificationCalls, 0);
        expect(auth.languageCalls, 0);
        expect(auth.currentUser?.uid, 'uid-a');
      },
    );
  });
}

class _QueueAuth extends Fake implements FirebaseAuth {
  _QueueAuth(this._currentUser, this.nextUser);

  User? _currentUser;
  final User nextUser;

  final StreamController<User?> _changes = StreamController<User?>.broadcast(
    sync: true,
  );

  final Completer<void> signInStarted = Completer<void>();
  final Completer<void> signOutStarted = Completer<void>();

  Completer<void>? signInGate;
  Completer<void>? signOutGate;
  Object? signOutError;

  int signInCalls = 0;
  int signOutCalls = 0;
  int languageCalls = 0;

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> authStateChanges() => _changes.stream;

  void changeUser(User? user) {
    _currentUser = user;
    _changes.add(user);
  }

  @override
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    signInCalls++;

    if (!signInStarted.isCompleted) {
      signInStarted.complete();
    }

    final gate = signInGate;
    if (gate != null) {
      await gate.future;
    }

    changeUser(nextUser);

    return _QueueCredential(nextUser);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;

    if (!signOutStarted.isCompleted) {
      signOutStarted.complete();
    }

    final gate = signOutGate;
    if (gate != null) {
      await gate.future;
    }

    final error = signOutError;
    if (error != null) {
      throw error;
    }

    changeUser(null);
  }

  @override
  Future<void> setLanguageCode(String? languageCode) async {
    languageCalls++;
  }

  Future<void> dispose() => _changes.close();
}

class _QueueUser extends Fake implements User {
  _QueueUser(this.uid);

  @override
  final String uid;

  @override
  bool get emailVerified => false;

  final Completer<void> reloadStarted = Completer<void>();
  Completer<void>? reloadGate;
  int verificationCalls = 0;

  @override
  Future<void> reload() async {
    if (!reloadStarted.isCompleted) {
      reloadStarted.complete();
    }

    final gate = reloadGate;
    if (gate != null) {
      await gate.future;
    }
  }

  @override
  Future<String?> getIdToken([bool forceRefresh = false]) async {
    return 'token-ficticio-$uid';
  }

  @override
  Future<void> sendEmailVerification([
    ActionCodeSettings? actionCodeSettings,
  ]) async {
    verificationCalls++;
  }
}

class _QueueCredential extends Fake implements UserCredential {
  _QueueCredential(this.user);

  @override
  final User user;
}
