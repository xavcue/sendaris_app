abstract interface class AuthRepository {
  bool get isAuthenticated;

  Stream<bool> get authStateChanges;

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

/// Capacidad para crear una cuenta provisional mediante
/// correo electrónico y contraseña.
///
/// La creación de la cuenta en el proveedor de autenticación
/// no habilita todavía el acceso funcional a Sendaris.
/// La cuenta debe verificar primero su dirección de correo.
abstract interface class AuthRegistrationRepository {
  Future<void> createUnverifiedAccount({
    required String email,
    required String password,
  });
}

/// Capacidad adicional para consultar y gestionar la verificación
/// del correo electrónico de la cuenta autenticada.
///
/// El correo pertenece exclusivamente al contexto de autenticación
/// y no debe incorporarse a los registros de seguimiento.
abstract interface class AuthEmailVerificationRepository {
  String? get currentUserEmail;

  bool get isCurrentUserEmailVerified;

  Future<void> sendEmailVerification();

  Future<bool> refreshEmailVerificationStatus();
}

/// Capacidad adicional para comprobar contra el proveedor de
/// autenticación si la sesión actual continúa siendo válida.
abstract interface class AuthSessionValidationRepository {
  Future<bool> validateCurrentSession();
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
