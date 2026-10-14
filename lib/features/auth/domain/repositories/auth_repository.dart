abstract interface class AuthRepository {
  bool get isAuthenticated;

  Stream<bool> get authStateChanges;

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

/// Capacidad adicional para identificar de forma estable
/// la cuenta autenticada.
abstract interface class AuthIdentityRepository {
  String? get currentUserId;

  Stream<String?> get userIdChanges;
}

/// Capacidad para crear una cuenta provisional mediante
/// correo electrónico y contraseña.
abstract interface class AuthRegistrationRepository {
  Future<void> createUnverifiedAccount({
    required String email,
    required String password,
  });
}

/// Capacidad adicional para consultar y gestionar
/// la verificación del correo electrónico.
abstract interface class AuthEmailVerificationRepository {
  String? get currentUserEmail;

  bool get isCurrentUserEmailVerified;

  Future<void> sendEmailVerification();

  Future<bool> refreshEmailVerificationStatus();
}

/// Capacidad adicional para comprobar si la sesión
/// actual continúa siendo válida.
abstract interface class AuthSessionValidationRepository {
  Future<bool> validateCurrentSession();
}

/// Operaciones sensibles relacionadas con la
/// administración de cuentas autenticadas.
abstract interface class AuthAccountManagementRepository {
  Future<void> reauthenticateWithPassword({required String password});

  Future<void> deleteCurrentAccount();
}

/// Capacidad opcional que devuelve el UID producido
/// por una operación concreta de autenticación.
abstract interface class AuthIdentitySessionOperationsRepository {
  Future<String> signInAndGetUserId({
    required String email,
    required String password,
  });

  Future<String> createUnverifiedAccountAndGetUserId({
    required String email,
    required String password,
  });
}

/// Permite correlacionar las operaciones serializadas
/// con el momento en que realmente comienzan.
///
/// Los callbacks se ejecutan sincrónicamente dentro
/// de la operación correspondiente.
abstract interface class AuthObservedSessionOperationsRepository {
  Future<String> signInObserved({
    required String email,
    required String password,
    required void Function() onExecutionStarted,
  });

  Future<String> createUnverifiedAccountObserved({
    required String email,
    required String password,
    required void Function() onExecutionStarted,
    required void Function(String userId) onProvisionalAccountCreated,
    required void Function(String userId) onProvisionalAccountCleaned,
  });
}
