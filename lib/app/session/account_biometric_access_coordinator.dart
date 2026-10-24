import 'package:firebase_auth/firebase_auth.dart';

import 'account_session_selection_controller.dart';
import 'biometric_binding_policy.dart';
import 'biometric_vault_gateway.dart';
import 'firebase_account_contexts.dart';

/// Verifica una sesión Firebase perteneciente a una cuenta.
///
/// La implementación real debe confirmar que la sesión
/// sigue vigente y que su correo está verificado.
abstract interface class AccountFirebaseSessionVerifier {
  String? get currentUserId;

  Future<bool> validate({required String expectedUserId});
}

/// Verificador de sesión mediante Firebase Authentication.
///
/// No utiliza credenciales guardadas ni modifica la cuenta.
///
/// Si Firebase no puede confirmar la sesión, la operación
/// se considera fallida.
final class FirebaseAccountSessionVerifier
    implements AccountFirebaseSessionVerifier {
  const FirebaseAccountSessionVerifier(this.auth);

  final FirebaseAuth auth;

  @override
  String? get currentUserId => auth.currentUser?.uid;

  @override
  Future<bool> validate({required String expectedUserId}) async {
    if (expectedUserId.isEmpty || expectedUserId.trim() != expectedUserId) {
      return false;
    }

    final initialUser = auth.currentUser;

    if (initialUser == null || initialUser.uid != expectedUserId) {
      return false;
    }

    try {
      // Consulta nuevamente el estado de la cuenta.
      await initialUser.reload();

      final refreshedUser = auth.currentUser;

      if (refreshedUser == null ||
          refreshedUser.uid != expectedUserId ||
          refreshedUser.emailVerified != true) {
        return false;
      }

      // Solicita un token Firebase actualizado.
      //
      // La sesión biométrica no almacena contraseñas
      // ni genera por sí misma credenciales Firebase.
      final String? token = await refreshedUser.getIdToken(true);

      if (token == null || token.isEmpty) {
        return false;
      }

      // La identidad no puede haber cambiado durante
      // la comunicación con Firebase.
      final finalUser = auth.currentUser;

      return finalUser != null &&
          finalUser.uid == expectedUserId &&
          finalUser.emailVerified == true;
    } catch (_) {
      return false;
    }
  }
}

/// Resultado de la autorización privada iniciada con biometría.
/// Solo [granted] significa que el selector aceptó la sesión.
enum AccountBiometricAccessOutcome {
  granted,
  cancelled,
  denied,
  unavailable,
  sessionUnavailable,
}

/// Coordina el acceso biométrico a una de las sesiones
/// Firebase independientes de Sendaris.
///
/// La selección y el permiso privado se administran
/// mediante AccountSessionSelectionController.
///
/// Este componente:
/// - No abre pantallas.
/// - No inicia sesiones con contraseñas.
/// - No elimina ni cambia cuentas Firebase.
/// - No modifica Firestore.
/// - No elimina vinculaciones biométricas.
/// - No concede acceso a un UID diferente del vinculado.
///
/// Todavía debe integrarse con el componente raíz para
/// controlar efectivamente las rutas privadas.
final class AccountBiometricAccessCoordinator {
  AccountBiometricAccessCoordinator({
    required this.selection,
    required this.gateway,
    required this.primarySession,
    required this.secondarySession,
  });

  /// Crea el coordinador utilizando exactamente los
  /// dos contextos de FirebaseAccountContextManager.
  ///
  /// La fábrica no concede acceso al inicializarse.
  factory AccountBiometricAccessCoordinator.forFirebase({
    required FirebaseAccountContextManager contexts,
    required BiometricVaultGateway gateway,
  }) {
    return AccountBiometricAccessCoordinator(
      selection: AccountSessionSelectionController(
        primary: FirebaseAccountIdentitySource(contexts.primary.auth),
        secondary: FirebaseAccountIdentitySource(contexts.secondary.auth),
      ),
      gateway: gateway,
      primarySession: FirebaseAccountSessionVerifier(contexts.primary.auth),
      secondarySession: FirebaseAccountSessionVerifier(contexts.secondary.auth),
    );
  }

  final AccountSessionSelectionController selection;
  final BiometricVaultGateway gateway;
  final AccountFirebaseSessionVerifier primarySession;
  final AccountFirebaseSessionVerifier secondarySession;

  bool get privateAccessGranted => selection.value;

  FirebaseAccountSlot? get selectedSlot => selection.selectedSlot;

  String? get selectedUserId => selection.selectedUserId;

  AccountFirebaseSessionVerifier _sessionFor(FirebaseAccountSlot slot) {
    return switch (slot) {
      FirebaseAccountSlot.primary => primarySession,
      FirebaseAccountSlot.secondary => secondarySession,
    };
  }

  bool _validUserId(String? userId) {
    return userId != null && userId.isNotEmpty && userId.trim() == userId;
  }

  /// Mantiene el contrato booleano utilizado por los consumidores existentes.
  /// El resultado detallado solo informa a la interfaz; nunca autoriza acceso.
  Future<bool> unlockLinkedAccount({required FirebaseAccountSlot slot}) async {
    final outcome = await unlockLinkedAccountWithOutcome(slot: slot);
    return outcome == AccountBiometricAccessOutcome.granted;
  }

  /// Distingue una cancelación voluntaria de un rechazo o un fallo de sesión.
  ///
  /// Solo AccountSessionSelectionController puede otorgar acceso privado.
  /// Un resultado no exitoso no crea ni recupera sesiones Firebase.
  Future<AccountBiometricAccessOutcome> unlockLinkedAccountWithOutcome({
    required FirebaseAccountSlot slot,
  }) async {
    final session = _sessionFor(slot);
    final userId = session.currentUserId;

    if (!_validUserId(userId)) {
      selection.lock();
      return AccountBiometricAccessOutcome.sessionUnavailable;
    }

    final expectedUserId = userId!;
    var outcome = AccountBiometricAccessOutcome.unavailable;

    final selected = await selection.select(
      slot: slot,
      expectedUserId: expectedUserId,
      verifyAccess: () async {
        if (session.currentUserId != expectedUserId) {
          outcome = AccountBiometricAccessOutcome.sessionUnavailable;
          return false;
        }

        final binding = await gateway.readBinding();

        if (binding is! BiometricBindingEnabled ||
            binding.userId != expectedUserId) {
          outcome = AccountBiometricAccessOutcome.unavailable;
          return false;
        }

        if (session.currentUserId != expectedUserId) {
          outcome = AccountBiometricAccessOutcome.sessionUnavailable;
          return false;
        }

        final biometricResult = await gateway.unlock(
          expectedUserId: expectedUserId,
        );

        switch (biometricResult) {
          case BiometricVaultOutcome.cancelled:
            outcome = AccountBiometricAccessOutcome.cancelled;
            return false;
          case BiometricVaultOutcome.denied:
            outcome = AccountBiometricAccessOutcome.denied;
            return false;
          case BiometricVaultOutcome.unavailable:
            outcome = AccountBiometricAccessOutcome.unavailable;
            return false;
          case BiometricVaultOutcome.verified:
            break;
        }

        if (session.currentUserId != expectedUserId) {
          outcome = AccountBiometricAccessOutcome.sessionUnavailable;
          return false;
        }

        final validFirebaseSession = await session.validate(
          expectedUserId: expectedUserId,
        );

        if (!validFirebaseSession || session.currentUserId != expectedUserId) {
          outcome = AccountBiometricAccessOutcome.sessionUnavailable;
          return false;
        }

        // Si select() falla después de validar Firebase, el problema
        // es de selección de sesión y no una huella incorrecta.
        outcome = AccountBiometricAccessOutcome.sessionUnavailable;

        // Esta comprobación no basta para autorizar: select() valida
        // de nuevo ambas identidades y su revisión de seguridad.
        return true;
      },
    );

    // Si select() rechazó por una carrera tras la verificación,
    // jamás transformamos ese rechazo en un éxito.
    return selected ? AccountBiometricAccessOutcome.granted : outcome;
  }

  /// Revoca el permiso privado sin desconectar
  /// ninguna de las dos sesiones Firebase.
  ///
  /// Se utilizará al cerrar el acceso visual,
  /// cambiar de cuenta o bloquear la aplicación.
  void lock() {
    selection.lock();
  }

  /// El propietario del coordinador debe llamarlo al
  /// destruir su árbol de seguridad.
  void dispose() {
    selection.dispose();
  }
}
