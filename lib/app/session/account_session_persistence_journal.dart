import 'account_active_session_checkpoint.dart';
import 'account_scoped_session_timeout_store.dart';
import 'account_session_selection_controller.dart';
import 'firebase_account_contexts.dart';
import 'session_timeout_policy.dart';

/// Fotografia de los metadatos persistidos.
///
/// Ninguno de estos registros concede autorizacion privada.
final class AccountSessionPersistenceSnapshot {
  const AccountSessionPersistenceSnapshot({
    required this.active,
    required this.primary,
    required this.secondary,
  });

  final AccountActiveSessionCheckpoint? active;
  final SessionTimeoutRecord? primary;
  final SessionTimeoutRecord? secondary;
}

/// Coordina la persistencia de los dos contextos de cuenta.
///
/// Todas las operaciones utilizan una unica cola FIFO para
/// evitar que una escritura anterior se complete despues
/// de una revocacion posterior.
///
/// Este servicio no ejecuta Firebase Authentication, no
/// solicita huellas y no selecciona cuentas por si mismo.
///
/// La autorizacion debe haberse confirmado previamente
/// mediante AccountSessionSelectionController.
///
/// El componente raiz debera:
/// - Confirmar la autenticacion antes de guardar.
/// - Persistir actividad y segundo plano cuando corresponda.
/// - Revocar el registro al cerrar sesion manualmente.
/// - Verificar Firebase al restaurar una sesion.
/// - No utilizar los metadatos como permiso privado.
final class AccountSessionPersistenceJournal {
  AccountSessionPersistenceJournal({
    required this.selection,
    required this.primary,
    required this.secondary,
    required this.active,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AccountSessionSelectionController selection;

  final AccountScopedSessionTimeoutStore primary;
  final AccountScopedSessionTimeoutStore secondary;
  final AccountActiveSessionCheckpointStore active;

  final DateTime Function() _clock;

  Future<void> _pending = Future<void>.value();
  bool _disposed = false;

  DateTime _now() => _clock().toUtc();

  AccountScopedSessionTimeoutStore _storeFor(FirebaseAccountSlot slot) {
    return switch (slot) {
      FirebaseAccountSlot.primary => primary,
      FirebaseAccountSlot.secondary => secondary,
    };
  }

  bool _matchesSelection(FirebaseAccountSlot slot, String userId) {
    return !_disposed &&
        selection.value &&
        selection.selectedSlot == slot &&
        selection.selectedUserId == userId;
  }

  bool _eligible(FirebaseAccountSlot slot, SessionTimeoutRecord record) {
    return _matchesSelection(slot, record.userId) &&
        AccountSessionRestorationCandidatePolicy.isEligible(
          record: record,
          authenticatedUserId: selection.selectedUserId,
          now: _now(),
        );
  }

  /// Mantiene ordenadas incluso las operaciones fallidas.
  ///
  /// Un error se devuelve al llamador, pero no deja rota
  /// la cola para las operaciones posteriores.
  Future<T> _serialize<T>(Future<T> Function() operation) {
    if (_disposed) {
      return Future<T>.error(
        StateError('El diario de sesiones ya fue cerrado.'),
      );
    }

    final result = _pending.then<T>((_) {
      if (_disposed) {
        throw StateError('El diario de sesiones ya fue cerrado.');
      }

      return operation();
    });

    _pending = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return result;
  }

  /// Persiste una sesion que ya fue autorizada.
  ///
  /// Primero elimina la seleccion persistida anterior,
  /// despues confirma el registro temporal y finalmente
  /// guarda la identidad activa.
  ///
  /// Si el permiso cambia durante una escritura, no
  /// publica una nueva seleccion persistente.
  Future<bool> commitAuthorized({
    required FirebaseAccountSlot slot,
    required SessionTimeoutRecord record,
  }) {
    return _serialize<bool>(() async {
      if (!_eligible(slot, record)) {
        return false;
      }

      final scopedStore = _storeFor(slot);

      // Invalida la seleccion anterior antes de
      // intentar publicar una sesion nueva.
      await active.clear();

      try {
        await scopedStore.write(record);

        if (!_eligible(slot, record)) {
          await scopedStore.clear();
          return false;
        }

        await active.write(
          AccountActiveSessionCheckpoint(slot: slot, userId: record.userId),
        );

        if (!_eligible(slot, record)) {
          await active.clear();
          await scopedStore.clear();
          return false;
        }

        return true;
      } catch (_) {
        // Si no es posible limpiar, el error se propaga.
        // El componente raiz debera mantener bloqueado
        // el acceso y no intentar restaurarlo.
        await active.clear();
        await scopedStore.clear();
        rethrow;
      }
    });
  }

  /// Actualiza las fechas de una sesion ya persistida.
  ///
  /// No modifica startedAt ni permite cambiar de UID
  /// para extender artificialmente la duracion absoluta.
  ///
  /// La cuenta debe continuar seleccionada y vigente.
  Future<bool> updateAuthorized({
    required FirebaseAccountSlot slot,
    required SessionTimeoutRecord record,
  }) {
    return _serialize<bool>(() async {
      if (!_eligible(slot, record)) {
        return false;
      }

      final checkpoint = await active.read();

      if (checkpoint == null ||
          checkpoint.slot != slot ||
          checkpoint.userId != record.userId) {
        return false;
      }

      final scopedStore = _storeFor(slot);
      final previous = await scopedStore.read();

      if (previous == null ||
          previous.userId != record.userId ||
          // El formato persistido usa milisegundos desde Epoch.
          // DateTime en memoria puede conservar microsegundos adicionales.
          // Un mismo inicio no debe rechazarse tras serializarse.
          previous.startedAt.millisecondsSinceEpoch !=
              record.startedAt.millisecondsSinceEpoch ||
          record.lastActivityAt.toUtc().isBefore(
            previous.lastActivityAt.toUtc(),
          )) {
        return false;
      }

      await scopedStore.write(record);

      // La autorizacion pudo revocarse mientras
      // se esperaba la escritura persistente.
      if (!_eligible(slot, record)) {
        await active.clear();
        await scopedStore.clear();
        return false;
      }

      return true;
    });
  }

  /// Revoca los metadatos de una identidad concreta.
  ///
  /// Puede llamarse despues de selection.lock(), ya que
  /// el cierre manual primero debe bloquear la interfaz.
  ///
  /// No borra la cuenta ni sus datos Firebase.
  /// Tampoco borra el registro de otra identidad.
  Future<void> revoke({
    required FirebaseAccountSlot slot,
    required String userId,
  }) {
    return _serialize<void>(() async {
      final checkpoint = await active.read();

      if (checkpoint != null &&
          checkpoint.slot == slot &&
          checkpoint.userId == userId) {
        await active.clear();
      }

      final scopedStore = _storeFor(slot);
      final saved = await scopedStore.read();

      if (saved != null && saved.userId == userId) {
        await scopedStore.clear();
      }
    });
  }

  /// Elimina todos los candidatos persistidos.
  ///
  /// Se reserva para una invalidacion global explicita,
  /// no para cambiar de A a B o viceversa.
  Future<void> clearAll() {
    return _serialize<void>(() async {
      // El checkpoint desaparece antes de borrar
      // cualquiera de los registros temporales.
      await active.clear();
      await primary.clear();
      await secondary.clear();
    });
  }

  /// Lee un conjunto coherente de los metadatos
  /// una vez completadas las operaciones pendientes.
  ///
  /// El resultado debe evaluarse posteriormente mediante
  /// AccountActiveSessionRestorationPolicy y los
  /// coordinadores reales de autenticacion.
  Future<AccountSessionPersistenceSnapshot> readSnapshot() {
    return _serialize<AccountSessionPersistenceSnapshot>(() async {
      final checkpoint = await active.read();
      final primaryRecord = await primary.read();
      final secondaryRecord = await secondary.read();

      return AccountSessionPersistenceSnapshot(
        active: checkpoint,
        primary: primaryRecord,
        secondary: secondaryRecord,
      );
    });
  }

  /// No elimina sesiones al finalizar la instancia.
  ///
  /// Un reinicio normal del proceso no es un cierre
  /// manual de sesion.
  void dispose() {
    _disposed = true;
  }
}
