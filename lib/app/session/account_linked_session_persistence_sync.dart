import 'account_linked_continuity_emission.dart';
import 'account_session_persistence_journal.dart';
import 'account_session_selection_controller.dart';
import 'android_linked_continuity_gateway.dart';
import 'firebase_account_contexts.dart';
import 'linked_account_session_lifecycle_controller.dart';
import 'session_timeout_policy.dart';

/// Compara registros usando la precisión real del
/// formato persistido por SessionTimeoutRecord.toJson().
///
/// El almacenamiento utiliza milisegundos desde Epoch.
/// DateTime.now() puede contener microsegundos adicionales.
///
/// Comparar directamente ambos DateTime produciría
/// diferencias artificiales después de serializar
/// y recuperar una sesión válida.
///
/// La comparación incluye identidad, inicio original,
/// última actividad y entrada en segundo plano.
bool samePersistedLinkedSessionRecord(
  SessionTimeoutRecord first,
  SessionTimeoutRecord second,
) {
  return first.userId == second.userId &&
      first.startedAt.millisecondsSinceEpoch ==
          second.startedAt.millisecondsSinceEpoch &&
      first.lastActivityAt.millisecondsSinceEpoch ==
          second.lastActivityAt.millisecondsSinceEpoch &&
      first.backgroundAt?.millisecondsSinceEpoch ==
          second.backgroundAt?.millisecondsSinceEpoch;
}

/// Sincroniza los tiempos de A con el diario persistente.
///
/// No autentica, no selecciona cuentas y no concede acceso.
///
/// El controlador de ciclo de vida es la fuente de los
/// tiempos de A. Este componente no modifica los límites
/// de expiración ni genera otra sesión independiente.
///
/// Responsabilidades:
/// - Confirmar una autorización biométrica existente.
/// - Persistir sus tiempos originales.
/// - Actualizar la actividad y el ciclo de vida.
/// - Emitir continuidad después de confirmar el diario.
/// - Rechazar cambios de identidad o de sesión.
///
/// Un fallo de continuidad nativa no invalida el acceso
/// actual de A mientras siga autorizado en memoria.
final class AccountLinkedSessionPersistenceSync {
  AccountLinkedSessionPersistenceSync({
    required this.selection,
    required this.lifecycle,
    required this.journal,
    required this.linkedSlot,
    DateTime Function()? clock,
    this.activityWriteInterval = const Duration(seconds: 30),
    AccountLinkedContinuityEmission? continuityEmission,
  }) : _clock = clock ?? DateTime.now,
       _continuityEmission =
           continuityEmission ??
           AccountLinkedContinuityEmission(
             activate: AndroidLinkedContinuityGateway().activateAfterUnlock,
             revoke: AndroidLinkedContinuityGateway().revoke,
           );

  final AccountSessionSelectionController selection;
  final LinkedAccountSessionLifecycleController lifecycle;
  final AccountSessionPersistenceJournal journal;

  /// Consulta el contexto vinculado actual.
  ///
  /// No utiliza una copia fija porque la vinculación
  /// puede cambiar durante la ejecución.
  final FirebaseAccountSlot? Function() linkedSlot;

  final DateTime Function() _clock;
  final Duration activityWriteInterval;

  final AccountLinkedContinuityEmission _continuityEmission;

  Future<bool>? _pendingBegin;
  DateTime? _lastSuccessfulWrite;

  bool _disposed = false;

  DateTime _now() => _clock().toUtc();

  /// Obtiene un registro temporal únicamente cuando
  /// pertenece a A y su autorización sigue vigente.
  ({FirebaseAccountSlot slot, SessionTimeoutRecord record})?
  _authorizedSnapshot() {
    if (_disposed || !selection.value) {
      return null;
    }

    final slot = linkedSlot();
    final selectedSlot = selection.selectedSlot;
    final userId = selection.selectedUserId;
    final record = lifecycle.record;

    if (slot == null ||
        slot != selectedSlot ||
        userId == null ||
        record == null ||
        record.userId != userId ||
        !lifecycle.hasValidLinkedAccess ||
        record.isExpired(_now())) {
      return null;
    }

    return (slot: slot, record: record);
  }

  /// Comprueba que el acceso actual y el diario
  /// persistente pertenecen a la misma sesión.
  ///
  /// Se comprueba antes y después de la lectura
  /// asíncrona para detectar revocaciones y cambios.
  ///
  /// Las fechas se comparan a nivel de milisegundos,
  /// que es la precisión del almacenamiento real.
  Future<bool> _confirmStoredAuthorization({
    required FirebaseAccountSlot slot,
    required SessionTimeoutRecord record,
  }) async {
    final live = _authorizedSnapshot();

    if (live == null ||
        live.slot != slot ||
        !samePersistedLinkedSessionRecord(live.record, record)) {
      return false;
    }

    try {
      final persisted = await journal.readSnapshot();

      final checkpoint = persisted.active;

      final storedRecord = switch (slot) {
        FirebaseAccountSlot.primary => persisted.primary,
        FirebaseAccountSlot.secondary => persisted.secondary,
      };

      if (checkpoint == null ||
          checkpoint.slot != slot ||
          checkpoint.userId != record.userId ||
          storedRecord == null ||
          !samePersistedLinkedSessionRecord(storedRecord, record)) {
        return false;
      }

      // El registro almacenado también debe seguir
      // dentro de su vigencia al finalizar la lectura.
      if (storedRecord.isExpired(_now(), restoring: true)) {
        return false;
      }

      // Una lectura correcta no basta si la sesión
      // cambió durante el await anterior.
      final confirmedLive = _authorizedSnapshot();

      return confirmedLive != null &&
          confirmedLive.slot == slot &&
          samePersistedLinkedSessionRecord(confirmedLive.record, record);
    } catch (_) {
      return false;
    }
  }

  /// Publica una autorización biométrica que ya fue
  /// comprobada por los coordinadores existentes.
  ///
  /// Primero confirma su almacenamiento.
  /// Después intenta emitir la credencial nativa
  /// utilizando la autorización biométrica pendiente.
  ///
  /// No presenta un segundo diálogo de huella.
  Future<bool> beginAuthorized() {
    if (_disposed) {
      return Future<bool>.value(false);
    }

    final pending = _pendingBegin;

    if (pending != null) {
      return pending;
    }

    final snapshot = _authorizedSnapshot();

    if (snapshot == null) {
      return Future<bool>.value(false);
    }

    final operation = _begin(snapshot.slot, snapshot.record);

    _pendingBegin = operation;

    return operation;
  }

  Future<bool> _begin(
    FirebaseAccountSlot slot,
    SessionTimeoutRecord record,
  ) async {
    try {
      final saved = await journal.commitAuthorized(slot: slot, record: record);

      if (!saved) {
        return false;
      }

      _lastSuccessfulWrite = _now();

      // La persistencia ya se confirmó.
      //
      // La emisión de continuidad se considera
      // independiente: si Android la rechaza,
      // A conserva su acceso actual en memoria.
      await _continuityEmission.issue(
        slot: slot,
        record: record,
        confirmAuthorized: () =>
            _confirmStoredAuthorization(slot: slot, record: record),
      );

      return true;
    } finally {
      _pendingBegin = null;
    }
  }

  /// Actualiza periódicamente la actividad guardada.
  ///
  /// No intenta emitir nuevas credenciales ni renueva
  /// el inicio absoluto de la sesión.
  Future<bool> persistActivity() {
    return _persist(force: false);
  }

  /// Persiste una transición de primer o segundo plano.
  ///
  /// El controlador de ciclo de vida debe actualizarse
  /// antes de solicitar esta operación.
  Future<bool> persistTransition() {
    return _persist(force: true);
  }

  Future<bool> _persist({required bool force}) async {
    if (_disposed) {
      return false;
    }

    final beginning = _pendingBegin;

    if (beginning != null) {
      final started = await beginning;

      if (!started) {
        return false;
      }
    }

    final snapshot = _authorizedSnapshot();

    if (snapshot == null || _lastSuccessfulWrite == null) {
      return false;
    }

    final now = _now();

    if (!force &&
        now.difference(_lastSuccessfulWrite!) < activityWriteInterval) {
      return false;
    }

    final saved = await journal.updateAuthorized(
      slot: snapshot.slot,
      record: snapshot.record,
    );

    if (saved) {
      _lastSuccessfulWrite = _now();
    }

    return saved;
  }

  /// Confirma el registro de A despues de recuperar una sesion
  /// verificada durante el arranque.
  ///
  /// No crea un nuevo inicio, no solicita otra huella y no emite
  /// otra credencial. Requiere que el lifecycle ya haya restaurado
  /// y reanudado el registro original antes de esta llamada.
  ///
  /// El componente raiz debe esperar true ANTES de publicar
  /// cualquier contenido privado de A.
  Future<bool> persistRestored() async {
    if (_disposed || _pendingBegin != null) {
      return false;
    }

    final snapshot = _authorizedSnapshot();

    if (snapshot == null) {
      return false;
    }

    try {
      final saved = await journal.updateAuthorized(
        slot: snapshot.slot,
        record: snapshot.record,
      );

      if (!saved) {
        return false;
      }

      final confirmed = _authorizedSnapshot();

      if (confirmed == null ||
          confirmed.slot != snapshot.slot ||
          !samePersistedLinkedSessionRecord(
            confirmed.record,
            snapshot.record,
          )) {
        return false;
      }

      _lastSuccessfulWrite = _now();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Espera a que termine la emision de continuidad iniciada
  /// por beginAuthorized().
  ///
  /// El cierre ya debe haber bloqueado la seleccion
  /// privada antes de invocar este metodo.
  ///
  /// Las escrituras de actividad y los cambios de segundo
  /// plano se ordenan posteriormente mediante la cola
  /// serializada de AccountSessionPersistenceJournal.
  Future<void> waitForIdle() async {
    final pending = _pendingBegin;

    if (pending != null) {
      await pending;
    }
  }

  /// Libera esta instancia.
  ///
  /// No cierra Firebase ni elimina una vinculación.
  /// Las revocaciones corresponden al coordinador
  /// de cierre de sesión y a los controles de seguridad.
  void dispose() {
    _disposed = true;
    _lastSuccessfulWrite = null;
  }
}
