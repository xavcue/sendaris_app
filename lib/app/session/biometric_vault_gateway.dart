import 'package:flutter/services.dart';

import 'biometric_binding_policy.dart';

enum BiometricVaultOutcome { verified, cancelled, unavailable, denied }

abstract interface class BiometricVaultGateway {
  Future<BiometricBindingState> readBinding();

  Future<BiometricVaultOutcome> enroll({required String userId});

  Future<BiometricVaultOutcome> unlock({required String expectedUserId});

  /// Se conserva para compatibilidad; no permite borrar
  /// una vinculacion sin autenticacion.
  Future<bool> clearBinding();
}

abstract interface class BiometricUnlinkGateway {
  Future<BiometricVaultOutcome> deactivate({required String expectedUserId});
}

/// Recuperacion excepcional de una clave invalidada permanentemente.
///
/// El controlador exige reautenticacion Firebase reciente.
/// Android solicita ademas credencial del dispositivo.
abstract interface class BiometricInvalidatedRecoveryGateway {
  Future<bool> isPermanentlyInvalidated({required String expectedUserId});

  Future<BiometricVaultOutcome> recoverInvalidated({
    required String expectedUserId,
  });
}

final class AndroidBiometricVaultGateway
    implements
        BiometricVaultGateway,
        BiometricUnlinkGateway,
        BiometricInvalidatedRecoveryGateway {
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

    final after = await readBinding();

    return after is BiometricBindingDisabled
        ? BiometricVaultOutcome.verified
        : BiometricVaultOutcome.denied;
  }

  @override
  Future<bool> isPermanentlyInvalidated({
    required String expectedUserId,
  }) async {
    if (!_isValidUserId(expectedUserId)) {
      return false;
    }

    try {
      final response = await _channel.invokeMethod<Object?>(
        'checkInvalidated',
        <String, String>{'uid': expectedUserId},
      );

      return response == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<BiometricVaultOutcome> recoverInvalidated({
    required String expectedUserId,
  }) async {
    if (!_isValidUserId(expectedUserId)) {
      return BiometricVaultOutcome.denied;
    }

    final before = await readBinding();

    if (before is! BiometricBindingEnabled || before.userId != expectedUserId) {
      return BiometricVaultOutcome.denied;
    }

    final result = await _perform(
      method: 'recoverInvalidated',
      expectedUserId: expectedUserId,
    );

    if (result != BiometricVaultOutcome.verified) {
      return result;
    }

    final after = await readBinding();

    return after is BiometricBindingDisabled
        ? BiometricVaultOutcome.verified
        : BiometricVaultOutcome.denied;
  }

  @override
  Future<bool> clearBinding() async {
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
