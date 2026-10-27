import 'account_linked_continuity_emission.dart';
import 'firebase_account_contexts.dart';

typedef AccountSessionCheckpointRevoker = Future<void> Function(
  FirebaseAccountSlot slot,
  String userId,
);

typedef AccountLinkedWritesDrain = Future<void> Function();

/// Coordina la revocacion persistente de una cuenta.
///
/// Cuenta vinculada A:
/// - Espera las operaciones pendientes de emision.
/// - Revoca la credencial de Android Keystore.
/// - Revoca el checkpoint persistente.
///
/// Cuenta convencional B:
/// - Revoca exclusivamente su checkpoint.
/// - No modifica la vinculacion biometrica de A.
/// - No elimina la credencial nativa de A.
///
/// No autentica usuarios.
/// No modifica Firebase.
/// No concede permisos privados.
///
/// El llamador debe bloquear previamente la seleccion
/// privada si se trata de un cierre manual.
///
/// En una desactivacion biometrica, debe invocarse
/// antes de aceptar definitivamente la reconfiguracion.
///
/// Una falla de una operacion no omite el intento de
/// ejecutar la otra revocacion obligatoria.
final class AccountLinkedContinuityRevocation {
  AccountLinkedContinuityRevocation({
    required this.revokeCheckpoint,
    required this.revokeNative,
    required this.drainLinkedWrites,
  });

  final AccountSessionCheckpointRevoker revokeCheckpoint;
  final LinkedContinuityRevoker revokeNative;
  final AccountLinkedWritesDrain drainLinkedWrites;

  bool _busy = false;

  bool get isBusy => _busy;

  bool _validUserId(String value) {
    return value.isNotEmpty &&
        value.length <= 256 &&
        value.trim() == value &&
        !value.runes.any(
          (codePoint) =>
              codePoint < 32 || (codePoint >= 127 && codePoint <= 159),
        );
  }

  /// Revoca la autorizacion persistente indicada.
  ///
  /// [isLinked] debe proceder de la configuracion
  /// verificada de cuentas, nunca de la interfaz.
  ///
  /// Para una cuenta convencional no se invoca
  /// Android Keystore.
  ///
  /// Para una cuenta vinculada se intenta revocar
  /// la credencial nativa y el checkpoint.
  ///
  /// Lanza StateError ante fallas o concurrencia.
  /// No devuelve exito parcial.
  Future<void> revoke({
    required FirebaseAccountSlot slot,
    required String userId,
    required bool isLinked,
  }) async {
    if (!_validUserId(userId)) {
      throw ArgumentError.value(
        userId,
        'userId',
        'Identidad de sesion invalida.',
      );
    }

    if (_busy) {
      throw StateError('Existe una revocacion de sesion en curso.');
    }

    _busy = true;

    try {
      var drainFailed = false;
      var nativeFailed = false;
      var checkpointFailed = false;

      if (isLinked) {
        // Una emision que ya comenzo puede terminar
        // despues de un intento de revocacion.
        //
        // Primero esperar al sincronizador para evitar
        // que una escritura antigua vuelva a producir
        // una credencial tras el cierre.
        //
        // Si la espera falla, seguimos intentando
        // ambas revocaciones, pero no declaramos exito.
        try {
          await drainLinkedWrites();
        } catch (_) {
          drainFailed = true;
        }

        // Se revoca la credencial criptografica antes
        // de eliminar el checkpoint. Esto proporciona
        // una barrera adicional si la escritura del
        // checkpoint llega a fallar.
        try {
          final revoked = await revokeNative(
            slot: slot,
            expectedUserId: userId,
          );

          if (!revoked) {
            nativeFailed = true;
          }
        } catch (_) {
          nativeFailed = true;
        }
      }

      // Ejecutar SIEMPRE la revocacion persistente,
      // incluso cuando Android devuelve un error.
      //
      // El diario debe serializar esta operacion con
      // las escrituras previas de la sesion.
      try {
        await revokeCheckpoint(slot, userId);
      } catch (_) {
        checkpointFailed = true;
      }

      if (drainFailed || nativeFailed || checkpointFailed) {
        throw StateError(
          'No se pudo confirmar por completo '
          'la revocacion persistente de la sesion.',
        );
      }
    } finally {
      _busy = false;
    }
  }
}
