import 'firebase_account_contexts.dart';
import 'session_timeout_policy.dart';

typedef LinkedContinuityActivator = Future<bool> Function({
  required FirebaseAccountSlot slot,
  required String expectedUserId,
  required DateTime sessionStartedAt,
});

typedef LinkedContinuityRevoker = Future<bool> Function({
  required FirebaseAccountSlot slot,
  required String expectedUserId,
});

/// Emite una credencial nativa solo cuando el llamador
/// confirma que A conserva su autorizacion persistente.
///
/// No autentica usuarios, no selecciona cuentas y no
/// modifica los tiempos originales de la sesion.
///
/// Si el estado cambia durante la emision, intenta
/// revocar la credencial que acaba de generarse.
///
/// Una emision fallida nunca concede acceso privado.
final class AccountLinkedContinuityEmission {
  AccountLinkedContinuityEmission({
    required this.activate,
    required this.revoke,
  });

  final LinkedContinuityActivator activate;
  final LinkedContinuityRevoker revoke;

  bool _busy = false;

  bool get isBusy => _busy;

  /// [confirmAuthorized] debe verificar conjuntamente:
  ///
  /// - La seleccion privada vigente.
  /// - El UID y contexto de A.
  /// - La vigencia temporal.
  /// - El checkpoint persistido.
  /// - La coincidencia del registro original.
  ///
  /// Se comprueba antes y despues de emitir.
  Future<bool> issue({
    required FirebaseAccountSlot slot,
    required SessionTimeoutRecord record,
    required Future<bool> Function() confirmAuthorized,
  }) async {
    if (_busy) {
      return false;
    }

    final userId = record.userId;

    if (userId.isEmpty ||
        userId.trim() != userId ||
        record.startedAt.millisecondsSinceEpoch <= 0) {
      return false;
    }

    _busy = true;

    try {
      if (!await _confirm(confirmAuthorized)) {
        return false;
      }

      final emitted = await activate(
        slot: slot,
        expectedUserId: userId,
        sessionStartedAt: record.startedAt.toUtc(),
      );

      if (!emitted) {
        return false;
      }

      if (await _confirm(confirmAuthorized)) {
        return true;
      }

      // La autorizacion cambio mientras Android
      // ejecutaba una operacion asincrona.
      //
      // No conservar una prueba nativa cuyo
      // checkpoint ya no esta confirmado.
      await _revokeSafely(slot: slot, userId: userId);

      return false;
    } catch (_) {
      // Una excepcion anterior a la emision no
      // genera una prueba. Si ocurre despues de
      // emitir, _confirm() ya falla sin lanzar.
      return false;
    } finally {
      _busy = false;
    }
  }

  Future<bool> _confirm(Future<bool> Function() confirmation) async {
    try {
      return await confirmation();
    } catch (_) {
      return false;
    }
  }

  Future<void> _revokeSafely({
    required FirebaseAccountSlot slot,
    required String userId,
  }) async {
    try {
      await revoke(slot: slot, expectedUserId: userId);
    } catch (_) {
      // La restauracion siempre debera confirmar
      // nuevamente el checkpoint y el UID.
      //
      // Este resultado nunca autoriza acceso.
    }
  }
}
