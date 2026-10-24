import 'dart:async';

import 'account_biometric_access_coordinator.dart';
import 'account_session_selection_controller.dart';
import 'biometric_binding_policy.dart';
import 'biometric_vault_gateway.dart';

/// Resultado de recuperar la sesion Firebase vinculada.
///
/// [recovered] confirma la identidad y la sesion Firebase,
/// pero NO concede permiso privado para abrir Sendaris.
enum AccountLinkedRecoveryResult {
  recovered,
  busy,
  unavailable,
  bindingUnavailable,
  bindingChanged,
  alreadyAuthenticated,
  otherContextOccupied,
  accountMismatch,
  identityChanged,
  sessionInvalid,
  cancelled,
}

/// Recupera una sesion Firebase perdida sin eliminar
/// la vinculacion biometrica conservada en Android.
///
/// Este coordinador no:
/// - Guarda contrasenas o credenciales de Google.
/// - Elimina cuentas, seguimientos o datos Firestore.
/// - Ejecuta clearBinding o deactivate.
/// - Concede acceso privado automaticamente.
/// - Utiliza la huella para iniciar sesion en Firebase.
///
/// La autenticacion mediante credenciales se proporciona
/// mediante un callback externo y debe ejecutarse solamente
/// sobre el contexto Firebase reservado para A.
///
/// El componente raiz es responsable de seleccionar
/// el contexto reservado y mostrar la interfaz de acceso.
final class AccountLinkedSessionRecoveryCoordinator {
  AccountLinkedSessionRecoveryCoordinator({
    required this.linkedIdentity,
    required this.otherIdentity,
    required this.linkedSession,
    required this.gateway,
  });

  final AccountIdentitySource linkedIdentity;
  final AccountIdentitySource otherIdentity;
  final AccountFirebaseSessionVerifier linkedSession;
  final BiometricVaultGateway gateway;

  bool _busy = false;
  bool _disposed = false;
  int _revision = 0;

  bool get isBusy => !_disposed && _busy;

  bool _isCurrent(int revision) {
    return !_disposed && revision == _revision;
  }

  bool _validUid(String? uid) {
    return uid != null && uid.isNotEmpty && uid.trim() == uid;
  }

  /// Ejecuta una nueva autenticacion solicitada expresamente
  /// por el usuario y comprueba que corresponde a la cuenta
  /// que sigue vinculada al dispositivo.
  ///
  /// El callback debe devolver true solamente cuando
  /// la autenticacion con credenciales haya finalizado.
  ///
  /// Una autenticacion correcta no basta: tambien deben
  /// superar las comprobaciones de UID, vigencia Firebase,
  /// identidad concurrente y vinculacion nativa.
  Future<AccountLinkedRecoveryResult> recover({
    required Future<bool> Function() authenticate,
  }) async {
    if (_disposed) {
      return AccountLinkedRecoveryResult.unavailable;
    }

    if (_busy) {
      return AccountLinkedRecoveryResult.busy;
    }

    _busy = true;
    final operationRevision = ++_revision;

    StreamSubscription<String?>? linkedSubscription;
    StreamSubscription<String?>? otherSubscription;

    try {
      if (linkedIdentity.currentUserId != null) {
        return AccountLinkedRecoveryResult.alreadyAuthenticated;
      }

      if (otherIdentity.currentUserId != null) {
        return AccountLinkedRecoveryResult.otherContextOccupied;
      }

      final initialBinding = await gateway.readBinding();

      if (!_isCurrent(operationRevision)) {
        return AccountLinkedRecoveryResult.identityChanged;
      }

      if (initialBinding is! BiometricBindingEnabled ||
          !_validUid(initialBinding.userId)) {
        return AccountLinkedRecoveryResult.bindingUnavailable;
      }

      final expectedUserId = initialBinding.userId;

      if (linkedIdentity.currentUserId != null ||
          linkedSession.currentUserId != null) {
        return AccountLinkedRecoveryResult.alreadyAuthenticated;
      }

      if (otherIdentity.currentUserId != null) {
        return AccountLinkedRecoveryResult.otherContextOccupied;
      }

      // Solo se admite la primera transicion:
      //
      // null -> UID vinculado.
      //
      // Cualquier UID intermedio, desaparicion posterior
      // o secuencia A -> B -> A invalida la recuperacion.
      var identityChanged = false;
      var observedLinkedUserId = linkedIdentity.currentUserId;
      var observedOtherUserId = otherIdentity.currentUserId;
      var linkedAccountSeen = false;

      linkedSubscription = linkedIdentity.userIdChanges.listen((userId) {
        if (userId == observedLinkedUserId) {
          return;
        }

        if (observedLinkedUserId == null &&
            userId == expectedUserId &&
            !linkedAccountSeen) {
          linkedAccountSeen = true;
        } else {
          identityChanged = true;
        }

        observedLinkedUserId = userId;
      });

      otherSubscription = otherIdentity.userIdChanges.listen((userId) {
        if (userId != observedOtherUserId) {
          identityChanged = true;
          observedOtherUserId = userId;
        }
      });

      // Antes de solicitar las credenciales, comprobar
      // de nuevo ambos contextos.
      if (linkedIdentity.currentUserId != null ||
          linkedSession.currentUserId != null ||
          otherIdentity.currentUserId != null) {
        return AccountLinkedRecoveryResult.identityChanged;
      }

      final authenticated = await authenticate();

      if (!_isCurrent(operationRevision) || identityChanged) {
        return AccountLinkedRecoveryResult.identityChanged;
      }

      if (!authenticated) {
        return AccountLinkedRecoveryResult.cancelled;
      }

      if (otherIdentity.currentUserId != null) {
        return AccountLinkedRecoveryResult.otherContextOccupied;
      }

      if (linkedIdentity.currentUserId != expectedUserId ||
          linkedSession.currentUserId != expectedUserId) {
        return AccountLinkedRecoveryResult.accountMismatch;
      }

      // Firebase debe comprobar la sesion real,
      // su correo verificado y un token actualizado.
      final validFirebaseSession = await linkedSession.validate(
        expectedUserId: expectedUserId,
      );

      if (!_isCurrent(operationRevision) || identityChanged) {
        return AccountLinkedRecoveryResult.identityChanged;
      }

      if (!validFirebaseSession) {
        return AccountLinkedRecoveryResult.sessionInvalid;
      }

      if (linkedIdentity.currentUserId != expectedUserId ||
          linkedSession.currentUserId != expectedUserId ||
          otherIdentity.currentUserId != null) {
        return AccountLinkedRecoveryResult.identityChanged;
      }

      // Verificar que Android sigue conservando exactamente
      // la misma vinculacion despues de la autenticacion.
      final confirmedBinding = await gateway.readBinding();

      if (!_isCurrent(operationRevision) || identityChanged) {
        return AccountLinkedRecoveryResult.identityChanged;
      }

      if (confirmedBinding is! BiometricBindingEnabled ||
          confirmedBinding.userId != expectedUserId) {
        return AccountLinkedRecoveryResult.bindingChanged;
      }

      if (linkedIdentity.currentUserId != expectedUserId ||
          linkedSession.currentUserId != expectedUserId ||
          otherIdentity.currentUserId != null) {
        return AccountLinkedRecoveryResult.identityChanged;
      }

      // No se llama a selection.select().
      // La recuperacion solo restablece Firebase.
      // El acceso privado requiere un paso posterior.
      return AccountLinkedRecoveryResult.recovered;
    } catch (_) {
      return AccountLinkedRecoveryResult.unavailable;
    } finally {
      if (linkedSubscription != null) {
        unawaited(linkedSubscription.cancel().catchError((Object _) {}));
      }

      if (otherSubscription != null) {
        unawaited(otherSubscription.cancel().catchError((Object _) {}));
      }

      _busy = false;
    }
  }

  /// Invalida operaciones pendientes, sin cancelar ni
  /// cerrar sesiones Firebase ajenas al coordinador.
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _revision++;
  }
}
