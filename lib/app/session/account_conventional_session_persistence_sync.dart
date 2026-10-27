import 'acknowledged_session_timeout_store.dart';
import 'account_session_persistence_journal.dart';
import 'account_session_selection_controller.dart';
import 'firebase_account_contexts.dart';
import 'session_timeout_policy.dart';

/// Sincroniza la cuenta convencional con su registro
/// de restauracion, sin crear otro temporizador.
///
/// La fuente de tiempos es SessionTimeoutGuard, que
/// publica escrituras confirmadas a traves de
/// AcknowledgedSessionTimeoutStore.
///
/// Este componente:
/// - No autentica usuarios.
/// - No concede permisos privados.
/// - No modifica Firebase.
/// - No renueva fechas de actividad.
/// - No interviene sobre el contexto biometrico.
///
/// El guard convencional conserva la responsabilidad
/// exclusiva de bloquear sesiones vencidas.
final class AccountConventionalSessionPersistenceSync {
  AccountConventionalSessionPersistenceSync({
    required this.selection,
    required this.source,
    required this.journal,
    required this.conventionalSlot,
    this.onCriticalFailure,
  }) {
    selection.addListener(_observe);
    source.addListener(_observe);
    _observe();
  }

  final AccountSessionSelectionController selection;
  final AcknowledgedSessionTimeoutStore source;
  final AccountSessionPersistenceJournal journal;

  /// Se consulta en cada evento porque los roles
  /// pueden cambiar al activar o desactivar biometria.
  final FirebaseAccountSlot Function() conventionalSlot;

  /// Se invoca cuando ni siquiera es posible revocar
  /// un candidato cuya sincronizacion ha fallado.
  ///
  /// La raiz debe mantener protegido el acceso
  /// ante un fallo critico de almacenamiento.
  final void Function()? onCriticalFailure;

  Future<void> _pending = Future<void>.value();

  FirebaseAccountSlot? _observedSlot;
  String? _observedUserId;

  int _authorizationRevision = 0;
  int _lastQueuedAuthorization = -1;
  int _lastQueuedSourceRevision = -1;

  bool _restorationUnavailable = false;
  bool _disposed = false;

  bool get restorationUnavailable => _restorationUnavailable;

  bool _currentAuthorization({
    required FirebaseAccountSlot slot,
    required String userId,
    required int revision,
  }) {
    return !_disposed &&
        revision == _authorizationRevision &&
        selection.value &&
        selection.selectedSlot == slot &&
        selection.selectedUserId == userId &&
        conventionalSlot() == slot;
  }

  /// Reacciona tanto a los cambios de seleccion
  /// como a las escrituras confirmadas del guard.
  ///
  /// Una escritura previa al fin de la autenticacion
  /// se procesara cuando el selector autorice B.
  void _observe() {
    if (_disposed) {
      return;
    }

    final slot = conventionalSlot();
    final selectedSlot = selection.selectedSlot;
    final selectedUserId = selection.selectedUserId;

    final authorized =
        selection.value &&
        selectedSlot == slot &&
        selectedUserId != null &&
        selectedUserId.isNotEmpty &&
        selectedUserId.trim() == selectedUserId;

    if (!authorized) {
      if (_observedSlot != null || _observedUserId != null) {
        _authorizationRevision++;
      }

      _observedSlot = null;
      _observedUserId = null;
      _restorationUnavailable = false;
      return;
    }

    final userId = selectedUserId;

    if (_observedSlot != slot || _observedUserId != userId) {
      _observedSlot = slot;
      _observedUserId = userId;
      _authorizationRevision++;
      _restorationUnavailable = false;
    }

    if (_restorationUnavailable) {
      return;
    }

    final record = source.lastPersistedRecord;

    // La notificacion puede ser una eliminacion,
    // o corresponder a un UID anterior.
    if (record == null || record.userId != userId) {
      return;
    }

    final authorizationRevision = _authorizationRevision;
    final sourceRevision = source.revision;

    // Evita procesar varias veces la misma escritura
    // dentro de una autorizacion concreta.
    if (_lastQueuedAuthorization == authorizationRevision &&
        _lastQueuedSourceRevision == sourceRevision) {
      return;
    }

    _lastQueuedAuthorization = authorizationRevision;
    _lastQueuedSourceRevision = sourceRevision;

    final operation = _pending.then((_) {
      return _persist(
        slot: slot,
        userId: userId,
        record: record,
        revision: authorizationRevision,
      );
    });

    // Una escritura fallida no rompe la cola.
    // _persist maneja la invalidacion del candidato.
    _pending = operation.catchError((Object error, StackTrace stackTrace) {
      if (_currentAuthorization(
        slot: slot,
        userId: userId,
        revision: authorizationRevision,
      )) {
        _restorationUnavailable = true;
        onCriticalFailure?.call();
      }
    });
  }

  Future<void> _persist({
    required FirebaseAccountSlot slot,
    required String userId,
    required SessionTimeoutRecord record,
    required int revision,
  }) async {
    if (!_currentAuthorization(
          slot: slot,
          userId: userId,
          revision: revision,
        ) ||
        _restorationUnavailable) {
      return;
    }

    try {
      final snapshot = await journal.readSnapshot();

      if (!_currentAuthorization(
            slot: slot,
            userId: userId,
            revision: revision,
          ) ||
          _restorationUnavailable) {
        return;
      }

      final previous = switch (slot) {
        FirebaseAccountSlot.primary => snapshot.primary,
        FirebaseAccountSlot.secondary => snapshot.secondary,
      };

      final active = snapshot.active;

      final sameSession =
          active != null &&
          active.slot == slot &&
          active.userId == userId &&
          previous != null &&
          previous.userId == userId &&
          previous.startedAt.toUtc() == record.startedAt.toUtc();

      final saved = sameSession
          ? await journal.updateAuthorized(slot: slot, record: record)
          : await journal.commitAuthorized(slot: slot, record: record);

      if (!saved &&
          _currentAuthorization(
            slot: slot,
            userId: userId,
            revision: revision,
          )) {
        await _discardRestoration(
          slot: slot,
          userId: userId,
          revision: revision,
        );
      }
    } catch (_) {
      if (_currentAuthorization(
        slot: slot,
        userId: userId,
        revision: revision,
      )) {
        await _discardRestoration(
          slot: slot,
          userId: userId,
          revision: revision,
        );
      }
    }
  }

  /// Un fallo de persistencia no se interpreta como
  /// expiracion del acceso vigente en memoria.
  ///
  /// Se elimina el candidato de restauracion y se
  /// deshabilitan nuevas escrituras para esta
  /// autorizacion, hasta un nuevo ingreso valido.
  Future<void> _discardRestoration({
    required FirebaseAccountSlot slot,
    required String userId,
    required int revision,
  }) async {
    if (!_currentAuthorization(
      slot: slot,
      userId: userId,
      revision: revision,
    )) {
      return;
    }

    _restorationUnavailable = true;

    try {
      await journal.revoke(slot: slot, userId: userId);
    } catch (_) {
      if (_currentAuthorization(
        slot: slot,
        userId: userId,
        revision: revision,
      )) {
        onCriticalFailure?.call();
      }
    }
  }

  /// Barrera para pruebas y futuras operaciones
  /// que deban esperar las escrituras observadas.
  ///
  /// No concede ni renueva una autorizacion.
  Future<void> waitForIdle() => _pending;

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _authorizationRevision++;

    selection.removeListener(_observe);
    source.removeListener(_observe);
  }
}
