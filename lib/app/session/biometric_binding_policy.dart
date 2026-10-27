/// Estado conocido de la vinculación biométrica de esta instalación.
///
/// Este estado debe provenir de un almacenamiento local validado.
/// Nunca debe deducirse que la biometría está desactivada
/// simplemente porque ocurrió un error al leer dicho almacenamiento.
sealed class BiometricBindingState {
  const BiometricBindingState();
}

/// El usuario todavía no ha activado el acceso biométrico,
/// o lo ha desactivado expresamente.
final class BiometricBindingDisabled extends BiometricBindingState {
  const BiometricBindingDisabled();
}

/// Existe una vinculación biométrica para un único UID.
///
/// Esta clase no constituye una prueba biométrica.
/// El desbloqueo requiere una verificación nativa posterior.
final class BiometricBindingEnabled extends BiometricBindingState {
  const BiometricBindingEnabled({required this.userId});

  final String userId;
}

/// No fue posible validar de forma confiable la vinculación.
///
/// Incluye información corrupta, inaccesible o cuya integridad
/// no puede confirmarse. Debe tratarse como estado bloqueado.
final class BiometricBindingUnavailable extends BiometricBindingState {
  const BiometricBindingUnavailable();
}

/// Acción permitida por la política de identidad.
///
/// Ninguno de estos resultados concede acceso a datos privados.
/// El guardián de sesión sigue siendo responsable de aplicar
/// los controles de autenticación y protección de la interfaz.
enum BiometricAccessAction {
  /// No existe una sesión Firebase válida identificable.
  requireSignIn,

  /// Se conserva la política temporal existente de Sendaris.
  continueLegacySession,

  /// Se debe realizar la comprobación biométrica nativa.
  requestBiometricVerification,

  /// No se permite continuar hasta resolver el conflicto.
  denyAccess,
}

/// Decide el tratamiento de una sesión respecto de la cuenta
/// vinculada al acceso biométrico.
///
/// Reglas:
/// - Una vinculación corresponde a un solo UID.
/// - No se vinculan cuentas por coincidencia de correo.
/// - Una vinculación ilegible nunca autoriza un acceso.
/// - La comprobación biométrica todavía debe ejecutarse.
/// - La vigencia real de Firebase se valida por separado.
final class BiometricBindingPolicy {
  const BiometricBindingPolicy._();

  static BiometricAccessAction decide({
    required String? firebaseUserId,
    required BiometricBindingState binding,
  }) {
    // La configuración insegura o ilegible nunca puede
    // interpretarse como un acceso biométrico desactivado.
    if (binding is BiometricBindingUnavailable) {
      return BiometricAccessAction.denyAccess;
    }

    // La huella no puede reconstruir una sesión inexistente.
    if (!_isValidUserId(firebaseUserId)) {
      return BiometricAccessAction.requireSignIn;
    }

    // Las cuentas sin biometría continúan utilizando
    // la política de sesión existente.
    if (binding is BiometricBindingDisabled) {
      return BiometricAccessAction.continueLegacySession;
    }

    if (binding is BiometricBindingEnabled) {
      // Nunca se debe aceptar una vinculación corrupta
      // ni permitir que A desbloquee la cuenta B.
      if (!_isValidUserId(binding.userId) || firebaseUserId != binding.userId) {
        return BiometricAccessAction.denyAccess;
      }

      // Coincidir en UID NO significa estar desbloqueado.
      // Falta obtener una prueba biométrica nativa válida.
      return BiometricAccessAction.requestBiometricVerification;
    }

    // Comportamiento restrictivo ante estados inesperados.
    return BiometricAccessAction.denyAccess;
  }

  static bool _isValidUserId(String? userId) {
    return userId != null && userId.isNotEmpty && userId.trim() == userId;
  }
}
