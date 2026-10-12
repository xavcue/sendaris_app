import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  FirebaseAuthService(this._firebaseAuth);

  static const String _authenticationEmailLanguageCode = 'es-419';

  final FirebaseAuth _firebaseAuth;

  User? get currentUser => _firebaseAuth.currentUser;

  String? get currentUserEmail => _firebaseAuth.currentUser?.email;

  bool get isCurrentUserEmailVerified {
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }

  Stream<User?> get authStateChanges {
    return _firebaseAuth.authStateChanges();
  }

  Future<void> signIn({required String email, required String password}) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user ?? _firebaseAuth.currentUser;

    if (user == null) {
      await _safeSignOut();

      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'The authenticated user is unavailable.',
      );
    }

    final refreshedUser = await _reloadUserAndRefreshIdToken(user);

    if (refreshedUser == null) {
      await _safeSignOut();

      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'The authenticated user became unavailable.',
      );
    }
  }

  Future<void> createUnverifiedAccount({
    required String email,
    required String password,
  }) async {
    final passwordStatus = await _firebaseAuth.validatePassword(
      _firebaseAuth,
      password,
    );

    if (!passwordStatus.isValid) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'The password does not satisfy the configured policy.',
      );
    }

    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = credential.user ?? _firebaseAuth.currentUser;

    if (user == null) {
      await _safeSignOut();

      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'The newly created user is unavailable.',
      );
    }

    try {
      await _firebaseAuth.setLanguageCode(_authenticationEmailLanguageCode);

      await user.sendEmailVerification();
    } catch (_) {
      await _deleteNewRegistrationOrSignOut(user);

      rethrow;
    }
  }

  Future<void> sendCurrentUserEmailVerification() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Authentication is required before sending '
        'email verification.',
      );
    }

    if (user.emailVerified) {
      return;
    }

    await _firebaseAuth.setLanguageCode(_authenticationEmailLanguageCode);

    await user.sendEmailVerification();
  }

  Future<bool> refreshCurrentUserEmailVerificationStatus() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Authentication is required before refreshing '
        'email verification.',
      );
    }

    final refreshedUser = await _reloadUserAndRefreshIdToken(user);

    return refreshedUser?.emailVerified ?? false;
  }

  Future<void> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      return;
    }

    await _reloadUserAndRefreshIdToken(user);
  }

  Future<void> signOut() {
    return _firebaseAuth.signOut();
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

    await user.reauthenticateWithCredential(credential);
  }

  Future<void> deleteCurrentUser() async {
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw StateError(
        'Authentication is required before deleting the account.',
      );
    }

    await user.delete();
  }

  Future<User?> _reloadUserAndRefreshIdToken(User user) async {
    await user.reload();

    final refreshedUser = _firebaseAuth.currentUser;

    if (refreshedUser == null) {
      return null;
    }

    await refreshedUser.getIdToken(true);

    return refreshedUser;
  }

  Future<void> _deleteNewRegistrationOrSignOut(User? user) async {
    if (user != null) {
      try {
        await user.delete();

        return;
      } catch (_) {
        // Si no es posible eliminar la cuenta recién creada,
        // como mínimo se elimina la sesión local.
      }
    }

    await _safeSignOut();
  }

  Future<void> _safeSignOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (_) {
      // La excepción original debe conservarse.
    }
  }
}
