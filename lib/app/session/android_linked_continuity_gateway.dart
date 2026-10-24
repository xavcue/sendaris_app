import 'package:flutter/services.dart';

import 'account_linked_session_continuity_assessment.dart';
import 'firebase_account_contexts.dart';

/// Puente hacia una credencial nativa de continuidad.
///
/// No almacena claves o secretos en Dart.
/// No concede acceso privado por si mismo.
///
/// La implementacion nativa comprueba la vinculacion
/// biometrica, la identidad y la autorizacion de
/// Android Keystore.
///
/// Las respuestas se aceptan exclusivamente cuando
/// coinciden el resultado, el UID, el contexto
/// Firebase y el inicio original de la sesion.
///
/// Ante errores o respuestas incompatibles se
/// devuelve false.
final class AndroidLinkedContinuityGateway
    implements AccountLinkedContinuityProof {
  AndroidLinkedContinuityGateway({MethodChannel? channel})
    : _channel =
          channel ??
          const MethodChannel('com.xavcue.sendaris/linked_continuity');

  final MethodChannel _channel;

  bool _validUserId(String value) {
    return value.isNotEmpty && value.trim() == value;
  }

  int? _validStart(DateTime value) {
    final milliseconds = value.toUtc().millisecondsSinceEpoch;

    return milliseconds > 0 ? milliseconds : null;
  }

  /// Emite una credencial mediante un nuevo
  /// BiometricPrompt nativo.
  ///
  /// Se conserva para compatibilidad y pruebas.
  ///
  /// No debe utilizarse en el acceso habitual de A
  /// si ya se completo el desbloqueo biometrico
  /// original, porque pediria otra huella.
  Future<bool> activate({
    required FirebaseAccountSlot slot,
    required String expectedUserId,
    required DateTime sessionStartedAt,
  }) {
    return _performSessionOperation(
      method: 'activate',
      expectedStatus: 'activated',
      slot: slot,
      expectedUserId: expectedUserId,
      sessionStartedAt: sessionStartedAt,
    );
  }

  /// Emite una credencial despues de un desbloqueo
  /// criptografico original confirmado.
  ///
  /// No solicita otra huella.
  ///
  /// Android debe haber registrado una autorizacion
  /// nativa pendiente y de un solo uso, procedente
  /// de BiometricVaultBridge.
  ///
  /// La capa que invoque esta operacion debera:
  /// - Verificar que A sigue seleccionada.
  /// - Confirmar la vigencia temporal de A.
  /// - Confirmar la escritura del registro original.
  /// - Comprobar que el UID y el contexto coincidan.
  ///
  /// Esta funcion nunca crea una autorizacion
  /// privada dentro de Flutter.
  Future<bool> activateAfterUnlock({
    required FirebaseAccountSlot slot,
    required String expectedUserId,
    required DateTime sessionStartedAt,
  }) {
    return _performSessionOperation(
      method: 'activateAfterUnlock',
      expectedStatus: 'activated',
      slot: slot,
      expectedUserId: expectedUserId,
      sessionStartedAt: sessionStartedAt,
    );
  }

  /// Comprueba la credencial previamente emitida.
  ///
  /// La verificacion nativa no solicita otro
  /// BiometricPrompt mientras Android Keystore
  /// mantenga su autorizacion temporal.
  @override
  Future<bool> verify({
    required FirebaseAccountSlot slot,
    required String expectedUserId,
    required DateTime sessionStartedAt,
  }) {
    return _performSessionOperation(
      method: 'verify',
      expectedStatus: 'verified',
      slot: slot,
      expectedUserId: expectedUserId,
      sessionStartedAt: sessionStartedAt,
    );
  }

  Future<bool> _performSessionOperation({
    required String method,
    required String expectedStatus,
    required FirebaseAccountSlot slot,
    required String expectedUserId,
    required DateTime sessionStartedAt,
  }) async {
    if (!_validUserId(expectedUserId)) {
      return false;
    }

    final startedAtMs = _validStart(sessionStartedAt);

    if (startedAtMs == null) {
      return false;
    }

    try {
      final response = await _channel.invokeMethod<Object?>(
        method,
        <String, Object>{
          'slot': slot.name,
          'uid': expectedUserId,
          'startedAtMs': startedAtMs,
        },
      );

      if (response is! Map) {
        return false;
      }

      return response['status'] == expectedStatus &&
          response['slot'] == slot.name &&
          response['uid'] == expectedUserId &&
          response['startedAtMs'] == startedAtMs;
    } catch (_) {
      // Errores del canal, ausencia del servicio
      // nativo o excepciones de Android nunca
      // conceden autorizacion.
      return false;
    }
  }

  /// Revoca una credencial nativa del contexto
  /// y UID indicados.
  ///
  /// La revocacion no requiere la fecha de inicio
  /// porque puede suceder despues de la expiracion
  /// de la sesion.
  ///
  /// Solo se declara correcta cuando Android
  /// confirma explicitamente la identidad revocada.
  Future<bool> revoke({
    required FirebaseAccountSlot slot,
    required String expectedUserId,
  }) async {
    if (!_validUserId(expectedUserId)) {
      return false;
    }

    try {
      final response = await _channel.invokeMethod<Object?>(
        'revoke',
        <String, Object>{'slot': slot.name, 'uid': expectedUserId},
      );

      if (response is! Map) {
        return false;
      }

      return response['status'] == 'revoked' &&
          response['slot'] == slot.name &&
          response['uid'] == expectedUserId;
    } catch (_) {
      return false;
    }
  }
}
