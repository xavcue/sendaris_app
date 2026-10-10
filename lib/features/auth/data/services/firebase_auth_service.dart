import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  FirebaseAuthService(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  User? get currentUser => _firebaseAuth.currentUser;

  Stream<User?> get authStateChanges {
    return _firebaseAuth.authStateChanges();
  }

  Future<void> signIn({required String email, required String password}) async {
    await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
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
}
