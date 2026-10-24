import 'biometric_binding_policy.dart';

/// Decide si el arranque dual puede iniciar una recuperacion
/// sin apropiarse de una sesion Firebase preexistente.
///
/// El destino de recuperacion sera el contexto primary solo
/// cuando primary y secondary esten completamente vacios.
/// No concede acceso privado ni valida credenciales.
abstract final class AccountLinkedSessionRecoveryPolicy {
  static bool canOffer({
    required BiometricBindingState binding,
    required String? primaryUserId,
    required String? secondaryUserId,
  }) {
    if (binding is! BiometricBindingEnabled) {
      return false;
    }

    final userId = binding.userId;

    return userId.isNotEmpty &&
        userId.trim() == userId &&
        primaryUserId == null &&
        secondaryUserId == null;
  }
}
