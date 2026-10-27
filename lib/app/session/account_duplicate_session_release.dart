import 'account_session_exit_coordinator.dart';
import 'account_session_selection_controller.dart';
import 'firebase_account_contexts.dart';

/// Libera exclusivamente la copia convencional de
/// una cuenta ya conservada para biometria.
///
/// No modifica Android Keystore ni desconecta la
/// sesion reservada de la cuenta vinculada.
///
/// El coordinador convencional debe validar ambas
/// sesiones Firebase antes de solicitar la liberacion.
final class AccountDuplicateSessionRelease {
  AccountDuplicateSessionRelease({
    required this.selection,
    required this.linkedSlot,
    required this.primary,
    required this.secondary,
  });

  final AccountSessionSelectionController selection;
  final FirebaseAccountSlot linkedSlot;
  final AccountSessionExitTarget primary;
  final AccountSessionExitTarget secondary;

  bool _busy = false;
  bool _disposed = false;

  bool get isBusy => !_disposed && _busy;

  AccountSessionExitTarget _targetFor(FirebaseAccountSlot slot) {
    return switch (slot) {
      FirebaseAccountSlot.primary => primary,
      FirebaseAccountSlot.secondary => secondary,
    };
  }

  bool _validUid(String value) {
    return value.isNotEmpty && value.trim() == value;
  }

  /// Elimina una sesion convencional duplicada.
  ///
  /// Devuelve true solo cuando:
  /// - El contexto solicitado no es el reservado.
  /// - Ambos contextos contienen inicialmente el UID.
  /// - No existe contenido privado autorizado.
  /// - La sesion convencional se desconecto.
  /// - La sesion reservada conserva el mismo UID.
  /// - No se observo una transicion de identidad
  ///   inesperada durante la operacion.
  ///
  /// La identidad se verifica antes de llamar a
  /// signOut y nuevamente al finalizar.
  Future<bool> release(
    FirebaseAccountSlot conventionalSlot,
    String expectedUserId,
  ) async {
    if (_disposed ||
        _busy ||
        conventionalSlot == linkedSlot ||
        !_validUid(expectedUserId) ||
        selection.value) {
      return false;
    }

    final conventional = _targetFor(conventionalSlot);

    final reserved = _targetFor(linkedSlot);

    if (conventional.currentUserId != expectedUserId ||
        reserved.currentUserId != expectedUserId) {
      return false;
    }

    _busy = true;

    var unexpectedTransition = false;
    var conventionalWasCleared = false;

    /// Observa tambien los cambios intermedios.
    ///
    /// De este modo, una secuencia A -> B -> A
    /// no queda validada solamente por comprobar
    /// el mismo UID al principio y al final.
    void observeIdentity() {
      if (_disposed || selection.value) {
        unexpectedTransition = true;
        return;
      }

      if (reserved.currentUserId != expectedUserId) {
        unexpectedTransition = true;
      }

      final conventionalUserId = conventional.currentUserId;

      if (conventionalUserId == null) {
        conventionalWasCleared = true;
      } else if (conventionalUserId != expectedUserId ||
          conventionalWasCleared) {
        unexpectedTransition = true;
      }
    }

    selection.addListener(observeIdentity);

    try {
      // La llamada utiliza el repositorio Firebase
      // del contexto convencional. Su implementacion
      // debe serializar el cierre por identidad.
      await conventional.signOut();

      observeIdentity();

      return !_disposed &&
          !unexpectedTransition &&
          !selection.value &&
          conventional.currentUserId == null &&
          reserved.currentUserId == expectedUserId;
    } catch (_) {
      return false;
    } finally {
      selection.removeListener(observeIdentity);
      _busy = false;
    }
  }

  void dispose() {
    _disposed = true;
  }
}
