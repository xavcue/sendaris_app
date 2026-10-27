import 'dart:async';

import '../../features/auth/domain/repositories/auth_repository.dart';
import 'biometric_binding_policy.dart';
import 'biometric_vault_gateway.dart';

/// Estado de la vinculación biométrica que puede presentar Ajustes.
///
/// Es información de configuración, no una autorización
/// para acceder a las pantallas privadas.
enum BiometricSettingsBindingStatus {
  notAuthenticated,
  disabled,
  enabledForCurrentUser,
  enabledForDifferentUser,
  unavailable,
  identityChanged,
}

/// Consulta el estado persistido de la biometría para
/// la identidad Firebase vigente.
///
/// No solicita biometría, no modifica el almacenamiento
/// y no concede permisos de acceso privado.
///
/// Una lectura que atraviesa un cambio A-B-A se rechaza,
/// aunque el UID final coincida con el inicial.
final class BiometricSettingsBindingReader {
  const BiometricSettingsBindingReader({
    required this.repository,
    required this.gateway,
  });

  final AuthRepository repository;
  final BiometricVaultGateway gateway;

  Future<BiometricSettingsBindingStatus> read() async {
    // AuthRepository no declara currentUserId ni userIdChanges.
    //
    // Primero verificamos que el repositorio implemente
    // el contrato de identidad y después obtenemos
    // una referencia explícitamente tipada.
    if (repository is! AuthIdentityRepository) {
      return BiometricSettingsBindingStatus.notAuthenticated;
    }

    final identityRepository = repository as AuthIdentityRepository;

    final expectedUserId = identityRepository.currentUserId;

    if (!repository.isAuthenticated ||
        expectedUserId == null ||
        expectedUserId.isEmpty ||
        expectedUserId.trim() != expectedUserId) {
      return BiometricSettingsBindingStatus.notAuthenticated;
    }

    var identityChanged = false;

    /// Registra cualquier cambio de contexto autenticado.
    ///
    /// El indicador es irreversible durante esta lectura:
    /// regresar al mismo UID no restaura la validez.
    void observeIdentity() {
      if (!repository.isAuthenticated ||
          identityRepository.currentUserId != expectedUserId) {
        identityChanged = true;
      }
    }

    bool isOriginalIdentity() {
      observeIdentity();

      return !identityChanged &&
          repository.isAuthenticated &&
          identityRepository.currentUserId == expectedUserId;
    }

    final authSubscription = repository.authStateChanges.listen(
      (_) => observeIdentity(),
    );

    final identitySubscription = identityRepository.userIdChanges.listen(
      (_) => observeIdentity(),
    );

    try {
      if (!isOriginalIdentity()) {
        return BiometricSettingsBindingStatus.identityChanged;
      }

      final BiometricBindingState binding;

      try {
        binding = await gateway.readBinding();
      } catch (_) {
        return isOriginalIdentity()
            ? BiometricSettingsBindingStatus.unavailable
            : BiometricSettingsBindingStatus.identityChanged;
      }

      if (!isOriginalIdentity()) {
        return BiometricSettingsBindingStatus.identityChanged;
      }

      if (binding is BiometricBindingDisabled) {
        return BiometricSettingsBindingStatus.disabled;
      }

      if (binding is BiometricBindingEnabled) {
        return binding.userId == expectedUserId
            ? BiometricSettingsBindingStatus.enabledForCurrentUser
            : BiometricSettingsBindingStatus.enabledForDifferentUser;
      }

      // Nunca interpretar errores nativos, información
      // incompleta o estados desconocidos como
      // una vinculación desactivada.
      return BiometricSettingsBindingStatus.unavailable;
    } finally {
      // La lectura ha finalizado. Las suscripciones ya
      // no deben observar nuevas transiciones.
      //
      // La limpieza asíncrona no concede ningún permiso.
      unawaited(authSubscription.cancel().catchError((Object _) {}));

      unawaited(identitySubscription.cancel().catchError((Object _) {}));
    }
  }
}
