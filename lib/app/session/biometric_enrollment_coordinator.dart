import 'dart:async';

import '../../features/auth/domain/repositories/auth_repository.dart';
import 'biometric_binding_policy.dart';
import 'biometric_vault_gateway.dart';

/// Resultado de una solicitud explícita de activación biométrica.
enum BiometricEnrollmentResult {
  enabled,
  alreadyBound,
  cancelled,
  unavailable,
  denied,
  identityChanged,
  invalidSession,
  unverifiedEmail,
  bindingMismatch,
}

/// Coordina la activación de biometría para el UID Firebase vigente.
///
/// No concede permisos de acceso privado ni modifica Firestore.
///
/// Una activación correcta requiere:
/// - identidad Firebase estable;
/// - validación remota satisfactoria;
/// - correo electrónico verificado;
/// - vinculación local inicialmente desactivada;
/// - operación criptográfica nativa confirmada;
/// - lectura posterior vinculada al mismo UID.
///
/// Si cambia la identidad durante la operación, el resultado
/// se rechaza aunque Firebase termine nuevamente con el
/// UID original.
final class BiometricEnrollmentCoordinator {
  const BiometricEnrollmentCoordinator({
    required this.repository,
    required this.gateway,
  });

  final AuthRepository repository;
  final BiometricVaultGateway gateway;

  Future<BiometricEnrollmentResult> enroll() async {
    if (repository is! AuthIdentityRepository ||
        repository is! AuthEmailVerificationRepository ||
        repository is! AuthSessionValidationRepository) {
      return BiometricEnrollmentResult.unavailable;
    }

    final identityRepository = repository as AuthIdentityRepository;
    final verificationRepository =
        repository as AuthEmailVerificationRepository;
    final validationRepository = repository as AuthSessionValidationRepository;

    final userId = identityRepository.currentUserId;

    if (!repository.isAuthenticated ||
        userId == null ||
        userId.isEmpty ||
        userId.trim() != userId) {
      return BiometricEnrollmentResult.invalidSession;
    }

    var identityChanged = false;

    void observeIdentity() {
      if (!repository.isAuthenticated ||
          identityRepository.currentUserId != userId) {
        identityChanged = true;
      }
    }

    bool isCurrentIdentity() {
      observeIdentity();

      return !identityChanged &&
          repository.isAuthenticated &&
          identityRepository.currentUserId == userId;
    }

    final authSubscription = repository.authStateChanges.listen(
      (_) => observeIdentity(),
    );

    final identitySubscription = identityRepository.userIdChanges.listen(
      (_) => observeIdentity(),
    );

    try {
      if (!isCurrentIdentity()) {
        return BiometricEnrollmentResult.identityChanged;
      }

      if (!verificationRepository.isCurrentUserEmailVerified) {
        return BiometricEnrollmentResult.unverifiedEmail;
      }

      final bool sessionValid;

      try {
        sessionValid = await validationRepository.validateCurrentSession();
      } catch (_) {
        if (!isCurrentIdentity()) {
          return BiometricEnrollmentResult.identityChanged;
        }

        return BiometricEnrollmentResult.unavailable;
      }

      if (!isCurrentIdentity()) {
        return BiometricEnrollmentResult.identityChanged;
      }

      if (!sessionValid) {
        return BiometricEnrollmentResult.invalidSession;
      }

      if (!verificationRepository.isCurrentUserEmailVerified) {
        return BiometricEnrollmentResult.unverifiedEmail;
      }

      final BiometricBindingState binding;

      try {
        binding = await gateway.readBinding();
      } catch (_) {
        if (!isCurrentIdentity()) {
          return BiometricEnrollmentResult.identityChanged;
        }

        return BiometricEnrollmentResult.unavailable;
      }

      if (!isCurrentIdentity()) {
        return BiometricEnrollmentResult.identityChanged;
      }

      if (binding is BiometricBindingEnabled) {
        return binding.userId == userId
            ? BiometricEnrollmentResult.alreadyBound
            : BiometricEnrollmentResult.bindingMismatch;
      }

      if (binding is! BiometricBindingDisabled) {
        return BiometricEnrollmentResult.unavailable;
      }

      final BiometricVaultOutcome outcome;

      try {
        outcome = await gateway.enroll(userId: userId);
      } catch (_) {
        if (!isCurrentIdentity()) {
          return BiometricEnrollmentResult.identityChanged;
        }

        return BiometricEnrollmentResult.unavailable;
      }

      // Un éxito nativo antiguo nunca habilita una cuenta
      // cuya identidad cambió durante el desafío.
      if (!isCurrentIdentity()) {
        return BiometricEnrollmentResult.identityChanged;
      }

      switch (outcome) {
        case BiometricVaultOutcome.cancelled:
          return BiometricEnrollmentResult.cancelled;

        case BiometricVaultOutcome.unavailable:
          return BiometricEnrollmentResult.unavailable;

        case BiometricVaultOutcome.denied:
          return BiometricEnrollmentResult.denied;

        case BiometricVaultOutcome.verified:
          break;
      }

      // No aceptamos únicamente la respuesta del canal:
      // comprobamos que la vinculación haya sido persistida.
      final BiometricBindingState confirmedBinding;

      try {
        confirmedBinding = await gateway.readBinding();
      } catch (_) {
        if (!isCurrentIdentity()) {
          return BiometricEnrollmentResult.identityChanged;
        }

        return BiometricEnrollmentResult.unavailable;
      }

      if (!isCurrentIdentity()) {
        return BiometricEnrollmentResult.identityChanged;
      }

      if (!verificationRepository.isCurrentUserEmailVerified) {
        return BiometricEnrollmentResult.unverifiedEmail;
      }

      if (confirmedBinding is BiometricBindingEnabled) {
        return confirmedBinding.userId == userId
            ? BiometricEnrollmentResult.enabled
            : BiometricEnrollmentResult.bindingMismatch;
      }

      return BiometricEnrollmentResult.unavailable;
    } finally {
      // Solicitar inmediatamente la cancelación evita que la
      // limpieza asíncrona prolongue artificialmente el flujo.
      //
      // Los errores de cancelación se consumen sin conceder
      // permisos adicionales.
      unawaited(authSubscription.cancel().catchError((Object _) {}));

      unawaited(identitySubscription.cancel().catchError((Object _) {}));
    }
  }
}
