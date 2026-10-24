import 'package:flutter/services.dart';

import 'biometric_binding_policy.dart';

/// Resultado de una operacion biometrica nativa.
///
/// VERIFIED solo representa una autenticacion valida
/// cuando Android completa la operacion criptografica
/// protegida por BiometricPrompt y Android Keystore.
enum BiometricVaultOutcome { verified, cancelled, unavailable, denied }

/// Contrato biometrico conservado por compatibilidad
/// con los componentes y pruebas existentes.
abstract interface class BiometricVaultGateway {
  Future<BiometricBindingState> readBinding();

  Future<BiometricVaultOutcome> enroll({required String userId});

  Future<BiometricVaultOutcome> unlock({required String expectedUserId});

  /// Operacion heredada.
  ///
  /// La nueva implementacion Android nunca permite
  /// eliminar una vinculacion mediante esta llamada.
  ///
  /// Se conserva temporalmente porque los flujos
  /// antiguos aun deben migrarse.
  Future<bool> clearBinding();
}

/// Contrato separado para desvinculacion autenticada.
///
/// Una implementacion valida exige biometria fuerte
/// y autorizacion criptografica nativa antes de
/// eliminar las credenciales locales.
abstract interface class BiometricUnlinkGateway {
  Future<BiometricVaultOutcome> deactivate({required String expectedUserId});
}

/// Adaptador al servicio nativo Android.
///
/// No almacena contrasenas ni concede permisos Firebase.
/// Los coordinadores superiores deben comprobar la
/// identidad Firebase, su vigencia y la autorizacion
/// privada antes y despues de estas operaciones.
final class AndroidBiometricVaultGateway
    implements BiometricVaultGateway, BiometricUnlinkGateway {
  AndroidBiometricVaultGateway({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('com.xavcue.sendaris/biometric_vault');

  final MethodChannel _channel;

  @override
  Future<BiometricBindingState> readBinding() async {
    try {
      final response = await _channel.invokeMethod<Object?>('readBinding');

      if (response is! Map) {
        return const BiometricBindingUnavailable();
      }

      if (response['status'] == 'disabled') {
        return const BiometricBindingDisabled();
      }

      if (response['status'] == 'enabled' && _isValidUserId(response['uid'])) {
        return BiometricBindingEnabled(userId: response['uid'] as String);
      }

      return const BiometricBindingUnavailable();
    } catch (_) {
      // Un almacenamiento ilegible nunca se trata
      // como una vinculacion desactivada.
      return const BiometricBindingUnavailable();
    }
  }

  @override
  Future<BiometricVaultOutcome> enroll({required String userId}) {
    return _perform(method: 'enroll', expectedUserId: userId);
  }

  @override
  Future<BiometricVaultOutcome> unlock({required String expectedUserId}) {
    return _perform(method: 'unlock', expectedUserId: expectedUserId);
  }

  @override
  Future<BiometricVaultOutcome> deactivate({
    required String expectedUserId,
  }) async {
    if (!_isValidUserId(expectedUserId)) {
      return BiometricVaultOutcome.denied;
    }

    // Comprobar que la vinculacion existente
    // corresponde a la cuenta esperada.
    final before = await readBinding();

    if (before is! BiometricBindingEnabled || before.userId != expectedUserId) {
      return BiometricVaultOutcome.denied;
    }

    final result = await _perform(
      method: 'deactivate',
      expectedUserId: expectedUserId,
    );

    if (result != BiometricVaultOutcome.verified) {
      return result;
    }

    // La respuesta del canal no basta.
    // Android debe confirmar tambien que el
    // almacenamiento ya no contiene la clave.
    final after = await readBinding();

    if (after is! BiometricBindingDisabled) {
      return BiometricVaultOutcome.denied;
    }

    return BiometricVaultOutcome.verified;
  }

  @override
  Future<bool> clearBinding() async {
    // Compatibilidad temporal con la interfaz
    // antigua sin permitir una eliminacion silenciosa.
    //
    // La desvinculacion real utiliza deactivate(),
    // que exige BiometricPrompt criptografico.
    return false;
  }

  Future<BiometricVaultOutcome> _perform({
    required String method,
    required String expectedUserId,
  }) async {
    if (!_isValidUserId(expectedUserId)) {
      return BiometricVaultOutcome.denied;
    }

    try {
      final response = await _channel.invokeMethod<Object?>(
        method,
        <String, String>{'uid': expectedUserId},
      );

      if (response is! Map) {
        return BiometricVaultOutcome.denied;
      }

      final status = response['status'];

      if (status == 'verified') {
        // Una respuesta sin UID o correspondiente
        // a otra cuenta no autoriza nada.
        if (response['uid'] != expectedUserId) {
          return BiometricVaultOutcome.denied;
        }

        return BiometricVaultOutcome.verified;
      }

      if (status == 'cancelled') {
        return BiometricVaultOutcome.cancelled;
      }

      if (status == 'unavailable') {
        return BiometricVaultOutcome.unavailable;
      }

      return BiometricVaultOutcome.denied;
    } on MissingPluginException {
      return BiometricVaultOutcome.unavailable;
    } on PlatformException catch (error) {
      if (error.code == 'biometric_unavailable') {
        return BiometricVaultOutcome.unavailable;
      }

      if (error.code == 'user_cancelled') {
        return BiometricVaultOutcome.cancelled;
      }

      return BiometricVaultOutcome.denied;
    } catch (_) {
      return BiometricVaultOutcome.denied;
    }
  }

  static bool _isValidUserId(Object? value) {
    return value is String && value.isNotEmpty && value.trim() == value;
  }
}
