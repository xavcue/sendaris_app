abstract interface class AuthRepository {
  bool get isAuthenticated;

  Stream<bool> get authStateChanges;

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

/// Operaciones sensibles relacionadas con la administración
/// de una cuenta autenticada.
///
/// Esta capacidad permanece separada del inicio/cierre de sesión
/// ordinario para mantener la lógica destructiva desacoplada.
abstract interface class AuthAccountManagementRepository {
  Future<void> reauthenticateWithPassword({required String password});

  Future<void> deleteCurrentAccount();
}
