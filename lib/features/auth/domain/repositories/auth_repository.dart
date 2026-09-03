abstract interface class AuthRepository {
  bool get isAuthenticated;

  Stream<bool> get authStateChanges;

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}
