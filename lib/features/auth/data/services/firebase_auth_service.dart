import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  FirebaseAuthService(this._firebaseAuth);

  static const String _authenticationEmailLanguageCode = 'es-419';

  final FirebaseAuth _firebaseAuth;

  // La cola siempre se libera, incluso cuando falla una operación.
  Future<void>? _sessionOperationTail;

  User? get currentUser => _firebaseAuth.currentUser;

  String? get currentUserEmail => _firebaseAuth.currentUser?.email;

  bool get isCurrentUserEmailVerified =>
      _firebaseAuth.currentUser?.emailVerified ?? false;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  Future<void> signIn({required String email, required String password}) async {
    await signInAndGetUserId(email: email, password: password);
  }

  Future<String> signInAndGetUserId({
    required String email,
    required String password,
  }) {
    return _runSessionOperation(
      () => _signInAndGetUserId(email: email, password: password),
    );
  }

  Future<String> signInObserved({
    required String email,
    required String password,
    required void Function() onExecutionStarted,
  }) {
    return _runSessionOperation(() {
      onExecutionStarted();
      return _signInAndGetUserId(email: email, password: password);
    });
  }

  Future<String> _signInAndGetUserId({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'The authenticated user is unavailable.',
      );
    }

    final refreshedUser = await _reloadUserAndRefreshIdToken(user);

    if (refreshedUser == null) {
      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'The authenticated user became unavailable.',
      );
    }

    if (refreshedUser.uid != user.uid) {
      throw StateError('Authentication identity changed during sign-in.');
    }

    return user.uid;
  }

  Future<void> createUnverifiedAccount({
    required String email,
    required String password,
  }) async {
    await createUnverifiedAccountAndGetUserId(email: email, password: password);
  }

  Future<String> createUnverifiedAccountAndGetUserId({
    required String email,
    required String password,
  }) {
    return _runSessionOperation(
      () => _createUnverifiedAccountAndGetUserId(
        email: email,
        password: password,
      ),
    );
  }

  Future<String> createUnverifiedAccountObserved({
    required String email,
    required String password,
    required void Function() onExecutionStarted,
    required void Function(String userId) onProvisionalAccountCreated,
    required void Function(String userId) onProvisionalAccountCleaned,
  }) {
    return _runSessionOperation(() {
      onExecutionStarted();

      return _createUnverifiedAccountAndGetUserId(
        email: email,
        password: password,
        onProvisionalAccountCreated: onProvisionalAccountCreated,
        onProvisionalAccountCleaned: onProvisionalAccountCleaned,
      );
    });
  }

  Future<String> _createUnverifiedAccountAndGetUserId({
    required String email,
    required String password,
    void Function(String userId)? onProvisionalAccountCreated,
    void Function(String userId)? onProvisionalAccountCleaned,
  }) async {
    final initialContext = _AuthOperationContext(
      _firebaseAuth,
      _firebaseAuth.currentUser?.uid,
    );

    try {
      final passwordStatus = await _firebaseAuth.validatePassword(
        _firebaseAuth,
        password,
      );

      // Detecta A -> B -> A durante la validación.
      initialContext.requireCurrent();

      if (!passwordStatus.isValid) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: 'The password does not satisfy the configured policy.',
        );
      }

      return await _createAndVerifyAccount(
        email: email,
        password: password,
        onProvisionalAccountCreated: onProvisionalAccountCreated,
        onProvisionalAccountCleaned: onProvisionalAccountCleaned,
      );
    } finally {
      await initialContext.dispose();
    }
  }

  Future<String> _createAndVerifyAccount({
    required String email,
    required String password,
    void Function(String userId)? onProvisionalAccountCreated,
    void Function(String userId)? onProvisionalAccountCleaned,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user;

    if (user == null) {
      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'The newly created user is unavailable.',
      );
    }

    final context = _AuthOperationContext(_firebaseAuth, user.uid);

    try {
      context.requireCurrent();
      onProvisionalAccountCreated?.call(user.uid);

      await _firebaseAuth.setLanguageCode(_authenticationEmailLanguageCode);

      context.requireCurrent();

      await user.sendEmailVerification();

      context.requireCurrent();

      return user.uid;
    } catch (_) {
      // Nunca eliminar una sesión externa ni una nueva
      // sesión que reutilice el mismo UID.
      if (context.isCurrent) {
        await _deleteNewRegistrationOrSignOut(user, context);

        if (_firebaseAuth.currentUser == null) {
          onProvisionalAccountCleaned?.call(user.uid);
        }
      }

      rethrow;
    } finally {
      await context.dispose();
    }
  }

  Future<void> sendCurrentUserEmailVerification() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Authentication is required before sending email verification.',
      );
    }

    if (user.emailVerified) {
      return;
    }

    await _runInCapturedContext(user.uid, () async {
      final context = _AuthOperationContext(_firebaseAuth, user.uid);

      try {
        context.requireCurrent();

        await _firebaseAuth.setLanguageCode(_authenticationEmailLanguageCode);

        context.requireCurrent();

        await user.sendEmailVerification();

        context.requireCurrent();
      } finally {
        await context.dispose();
      }
    });
  }

  Future<bool> refreshCurrentUserEmailVerificationStatus() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Authentication is required before refreshing email verification.',
      );
    }

    return _runInCapturedContext(user.uid, () async {
      final refreshedUser = await _reloadUserAndRefreshIdToken(user);
      return refreshedUser?.emailVerified ?? false;
    });
  }

  Future<void> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      return;
    }

    await _runInCapturedContext(user.uid, () async {
      await _reloadUserAndRefreshIdToken(user);
    });
  }

  Future<void> signOut() {
    final requestedUserId = _firebaseAuth.currentUser?.uid;

    return _runInCapturedContext(requestedUserId, _firebaseAuth.signOut);
  }

  Future<void> reauthenticateCurrentUserWithPassword({
    required String password,
  }) async {
    final user = _firebaseAuth.currentUser;
    final email = user?.email;

    if (user == null || email == null || email.trim().isEmpty) {
      throw StateError(
        'Password reauthentication requires an authenticated email user.',
      );
    }

    final supportsPassword = user.providerData.any(
      (provider) => provider.providerId == 'password',
    );

    if (!supportsPassword) {
      throw StateError(
        'Password reauthentication is unavailable for this provider.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await _runInCapturedContext(user.uid, () async {
      await user.reauthenticateWithCredential(credential);
    });
  }

  Future<void> deleteCurrentUser() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Authentication is required before deleting the account.',
      );
    }

    await _runInCapturedContext(user.uid, user.delete);
  }

  Future<User?> _reloadUserAndRefreshIdToken(User user) async {
    final context = _AuthOperationContext(_firebaseAuth, user.uid);

    try {
      if (!context.isCurrent) {
        return null;
      }

      await user.reload();

      if (!context.isCurrent) {
        return null;
      }

      await user.getIdToken(true);

      if (!context.isCurrent) {
        return null;
      }

      return _firebaseAuth.currentUser;
    } finally {
      await context.dispose();
    }
  }

  Future<void> _deleteNewRegistrationOrSignOut(
    User user,
    _AuthOperationContext context,
  ) async {
    if (!context.isCurrent) {
      return;
    }

    try {
      await user.delete();
      return;
    } catch (_) {
      // Conservar el error original del registro.
    }

    if (!context.isCurrent) {
      return;
    }

    try {
      // Ya estamos dentro de la operación de registro;
      // no se puede volver a entrar en la cola.
      await _firebaseAuth.signOut();
    } catch (_) {
      // Conservar el error original del registro.
    }
  }

  Future<T> _runInCapturedContext<T>(
    String? requestedUserId,
    Future<T> Function() action,
  ) async {
    final waitingContext = _sessionOperationTail == null
        ? null
        : _AuthOperationContext(_firebaseAuth, requestedUserId);

    try {
      return await _runSessionOperation(() {
        waitingContext?.requireCurrent();

        if (_firebaseAuth.currentUser?.uid != requestedUserId) {
          throw StateError('Authentication changed before operation.');
        }

        return action();
      });
    } finally {
      if (waitingContext != null) {
        await waitingContext.dispose();
      }
    }
  }

  Future<T> _runSessionOperation<T>(Future<T> Function() action) {
    final previous = _sessionOperationTail;

    final release = Completer<void>();
    final released = release.future;

    _sessionOperationTail = released;

    Future<T> execute() async {
      try {
        if (previous != null) {
          await previous;
        }

        return await action();
      } finally {
        if (identical(_sessionOperationTail, released)) {
          _sessionOperationTail = null;
        }

        release.complete();
      }
    }

    return execute();
  }
}

class _AuthOperationContext {
  _AuthOperationContext(this._auth, this._requestedUserId) {
    _subscription = _auth.authStateChanges().listen((user) {
      if (user?.uid != _requestedUserId) {
        _invalidated = true;
      }
    });
  }

  final FirebaseAuth _auth;
  final String? _requestedUserId;

  late final StreamSubscription<User?> _subscription;

  bool _invalidated = false;

  bool get isCurrent =>
      !_invalidated && _auth.currentUser?.uid == _requestedUserId;

  void requireCurrent() {
    if (!isCurrent) {
      throw StateError('Authentication identity changed during operation.');
    }
  }

  Future<void> dispose() => _subscription.cancel();
}
