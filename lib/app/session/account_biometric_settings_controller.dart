import 'package:flutter/foundation.dart';

import 'account_biometric_access_coordinator.dart';
import 'account_session_selection_controller.dart';
import 'biometric_binding_policy.dart';
import 'biometric_vault_gateway.dart';
import 'firebase_account_contexts.dart';

/// Resultado de una operacion de configuracion biometrica.
///
/// Un resultado satisfactorio no concede una sesion
/// Firebase nueva ni reemplaza una autorizacion anterior.
enum AccountBiometricSettingsResult {
  activated,
  deactivated,
  alreadyEnabled,
  notEnabled,
  notAuthorized,
  otherAccountBound,
  invalidSession,
  identityChanged,
  cancelled,
  denied,
  unavailable,
  busy,
}

/// Tipo de cambio efectuado sobre el almacenamiento
/// biometrico nativo.
enum AccountBiometricBindingOperation { activation, deactivation }

/// Describe una mutacion confirmada mediante una
/// lectura posterior del almacenamiento Android.
///
/// El UID y el contexto proceden de la seleccion
/// privada previamente autorizada, no de la interfaz.
final class AccountBiometricBindingChange {
  const AccountBiometricBindingChange({
    required this.slot,
    required this.userId,
    required this.operation,
  });

  final FirebaseAccountSlot slot;
  final String userId;
  final AccountBiometricBindingOperation operation;

  bool get enabled => operation == AccountBiometricBindingOperation.activation;
}

/// La raiz debe aceptar una mutacion solamente cuando
/// pueda actualizar su politica de cuentas sin
/// desconectar accidentalmente la cuenta vinculada.
///
/// Una respuesta false o una excepcion obliga a
/// bloquear la autorizacion privada.
typedef AccountBiometricBindingChangeHandler = Future<bool> Function(
  AccountBiometricBindingChange change,
);

/// Gestiona la activacion y desactivacion biometrica
/// de la cuenta que tiene acceso privado en Sendaris.
///
/// Seguridad:
/// - No recibe un UID desde la pantalla.
/// - No guarda contrasenas ni credenciales.
/// - No crea ni cierra sesiones Firebase.
/// - No modifica datos de Firestore.
/// - No utiliza clearBinding().
/// - La desactivacion utiliza BiometricUnlinkGateway.
/// - Verifica la sesion Firebase antes de la operacion.
/// - Relee el almacenamiento Android al finalizar.
/// - Exige que la raiz acepte la nueva configuracion.
///
/// Una operacion satisfactoria conserva el acceso
/// actual, para permitir permanecer en Ajustes.
///
/// Si existe una mutacion ambigua, una identidad
/// diferente o un error de sincronizacion, se revoca
/// el acceso privado.
final class AccountBiometricSettingsController extends ChangeNotifier {
  AccountBiometricSettingsController({
    required this.selection,
    required this.primarySession,
    required this.secondarySession,
    required this.gateway,
    required this.unlinkGateway,
    required this.onBindingChanged,
  });

  final AccountSessionSelectionController selection;

  final AccountFirebaseSessionVerifier primarySession;
  final AccountFirebaseSessionVerifier secondarySession;

  final BiometricVaultGateway gateway;
  final BiometricUnlinkGateway unlinkGateway;

  /// No debe ejecutar una preparacion que cierre
  /// automaticamente la sesion de la cuenta actual.
  ///
  /// La implementacion del componente raiz debe:
  /// - Validar la vinculacion leida en Android.
  /// - Comprobar UID y contexto Firebase.
  /// - Actualizar la distribucion de sesiones.
  /// - Conservar el acceso privado de la misma cuenta.
  /// - Responder false si no puede garantizarlo.
  final AccountBiometricBindingChangeHandler onBindingChanged;

  bool _busy = false;
  bool _disposed = false;

  bool get isBusy => !_disposed && _busy;

  AccountFirebaseSessionVerifier _sessionFor(FirebaseAccountSlot slot) {
    return switch (slot) {
      FirebaseAccountSlot.primary => primarySession,
      FirebaseAccountSlot.secondary => secondarySession,
    };
  }

  bool _validUid(String? uid) {
    return uid != null && uid.isNotEmpty && uid.trim() == uid;
  }

  bool _matchesAuthorization({
    required FirebaseAccountSlot slot,
    required String userId,
    required AccountFirebaseSessionVerifier session,
  }) {
    return !_disposed &&
        selection.value &&
        selection.selectedSlot == slot &&
        selection.selectedUserId == userId &&
        session.currentUserId == userId;
  }

  bool _matchesBinding({
    required BiometricBindingState binding,
    required bool enabled,
    required String userId,
  }) {
    if (enabled) {
      return binding is BiometricBindingEnabled && binding.userId == userId;
    }

    return binding is BiometricBindingDisabled;
  }

  Future<bool> _applyBindingChange(AccountBiometricBindingChange change) async {
    try {
      return await onBindingChanged(change);
    } catch (_) {
      return false;
    }
  }

  Future<AccountBiometricSettingsResult> activate() {
    return _execute(activateBinding: true);
  }

  /// La desactivacion requiere la operacion nativa
  /// protegida mediante BiometricPrompt y CryptoObject.
  Future<AccountBiometricSettingsResult> deactivate() {
    return _execute(activateBinding: false);
  }

  Future<AccountBiometricSettingsResult> _execute({
    required bool activateBinding,
  }) async {
    if (_disposed) {
      return AccountBiometricSettingsResult.unavailable;
    }

    if (_busy) {
      return AccountBiometricSettingsResult.busy;
    }

    final slot = selection.selectedSlot;
    final userId = selection.selectedUserId;

    if (!selection.value || slot == null || !_validUid(userId)) {
      return AccountBiometricSettingsResult.notAuthorized;
    }

    final expectedUserId = userId!;
    final session = _sessionFor(slot);

    if (session.currentUserId != expectedUserId) {
      selection.lock();
      return AccountBiometricSettingsResult.identityChanged;
    }

    _busy = true;
    notifyListeners();

    var authorizationChanged = false;

    void observeAuthorization() {
      if (!_matchesAuthorization(
        slot: slot,
        userId: expectedUserId,
        session: session,
      )) {
        authorizationChanged = true;
      }
    }

    bool stillAuthorized() {
      observeAuthorization();

      return !authorizationChanged &&
          _matchesAuthorization(
            slot: slot,
            userId: expectedUserId,
            session: session,
          );
    }

    selection.addListener(observeAuthorization);

    try {
      // Primera validacion remota.
      final validBefore = await session.validate(
        expectedUserId: expectedUserId,
      );

      if (!stillAuthorized()) {
        selection.lock();
        return AccountBiometricSettingsResult.identityChanged;
      }

      if (!validBefore) {
        selection.lock();
        return AccountBiometricSettingsResult.invalidSession;
      }

      // Una lectura ilegible nunca se interpreta
      // como ausencia de vinculacion.
      final before = await gateway.readBinding();

      if (!stillAuthorized()) {
        selection.lock();
        return AccountBiometricSettingsResult.identityChanged;
      }

      if (before is BiometricBindingUnavailable) {
        selection.lock();
        return AccountBiometricSettingsResult.unavailable;
      }

      if (activateBinding) {
        if (before is BiometricBindingEnabled) {
          return before.userId == expectedUserId
              ? AccountBiometricSettingsResult.alreadyEnabled
              : AccountBiometricSettingsResult.otherAccountBound;
        }

        if (before is! BiometricBindingDisabled) {
          selection.lock();
          return AccountBiometricSettingsResult.unavailable;
        }
      } else {
        if (before is BiometricBindingDisabled) {
          return AccountBiometricSettingsResult.notEnabled;
        }

        if (before is! BiometricBindingEnabled) {
          selection.lock();
          return AccountBiometricSettingsResult.unavailable;
        }

        if (before.userId != expectedUserId) {
          return AccountBiometricSettingsResult.otherAccountBound;
        }
      }

      // Android efectua el desafio criptografico.
      //
      // No se solicita una eliminacion sin huella,
      // ni se ejecuta clearBinding().
      final nativeOutcome = activateBinding
          ? await gateway.enroll(userId: expectedUserId)
          : await unlinkGateway.deactivate(expectedUserId: expectedUserId);

      // Se comprueba el resultado persistido incluso
      // cuando Android cancela o devuelve un error.
      final after = await gateway.readBinding();

      final mutationConfirmed = _matchesBinding(
        binding: after,
        enabled: activateBinding,
        userId: expectedUserId,
      );

      if (mutationConfirmed) {
        final change = AccountBiometricBindingChange(
          slot: slot,
          userId: expectedUserId,
          operation: activateBinding
              ? AccountBiometricBindingOperation.activation
              : AccountBiometricBindingOperation.deactivation,
        );

        // La sesion debe continuar siendo valida
        // despues del desafio de Android.
        final validAfter = await session.validate(
          expectedUserId: expectedUserId,
        );

        if (!stillAuthorized() || !validAfter) {
          selection.lock();

          // La vinculacion ya cambio en Android.
          // La raiz debe enterarse incluso si el
          // permiso privado ha sido revocado.
          await _applyBindingChange(change);

          return validAfter
              ? AccountBiometricSettingsResult.identityChanged
              : AccountBiometricSettingsResult.invalidSession;
        }

        // La raiz confirma que ya actualizo su
        // distribucion de cuentas y sus protecciones.
        //
        // Nunca utilizar aqui _prepare() si este
        // desconecta la cuenta actualmente abierta.
        final applied = await _applyBindingChange(change);

        if (!applied) {
          selection.lock();
          return AccountBiometricSettingsResult.unavailable;
        }

        // Otra lectura evita confiar en una configuracion
        // que pudo cambiar mientras se actualizaba la raiz.
        final finalBinding = await gateway.readBinding();

        if (!_matchesBinding(
          binding: finalBinding,
          enabled: activateBinding,
          userId: expectedUserId,
        )) {
          selection.lock();
          return AccountBiometricSettingsResult.unavailable;
        }

        if (!stillAuthorized()) {
          selection.lock();
          return AccountBiometricSettingsResult.identityChanged;
        }

        // Si el estado cambio a pesar de una cancelacion
        // o denegacion nativa, nunca tratamos el resultado
        // como una autenticacion biometrica correcta.
        if (nativeOutcome != BiometricVaultOutcome.verified) {
          selection.lock();
          return _nativeFailure(nativeOutcome);
        }

        // No bloquear A tras una transicion completa
        // y verificada. Se conserva Ajustes montado.
        return activateBinding
            ? AccountBiometricSettingsResult.activated
            : AccountBiometricSettingsResult.deactivated;
      }

      if (!stillAuthorized()) {
        selection.lock();
        return AccountBiometricSettingsResult.identityChanged;
      }

      if (after is BiometricBindingUnavailable) {
        selection.lock();
        return AccountBiometricSettingsResult.unavailable;
      }

      if (nativeOutcome == BiometricVaultOutcome.verified) {
        // La respuesta nativa no coincide con el
        // estado persistido: denegar y bloquear.
        selection.lock();
        return AccountBiometricSettingsResult.denied;
      }

      // Una cancelacion normal que no modifico la
      // vinculacion no exige cerrar la cuenta.
      return _nativeFailure(nativeOutcome);
    } catch (_) {
      selection.lock();
      return AccountBiometricSettingsResult.unavailable;
    } finally {
      selection.removeListener(observeAuthorization);

      _busy = false;

      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  AccountBiometricSettingsResult _nativeFailure(BiometricVaultOutcome outcome) {
    return switch (outcome) {
      BiometricVaultOutcome.verified => AccountBiometricSettingsResult.denied,
      BiometricVaultOutcome.cancelled =>
        AccountBiometricSettingsResult.cancelled,
      BiometricVaultOutcome.denied => AccountBiometricSettingsResult.denied,
      BiometricVaultOutcome.unavailable =>
        AccountBiometricSettingsResult.unavailable,
    };
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    super.dispose();
  }
}
