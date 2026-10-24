import 'dart:async';

import 'account_session_selection_controller.dart';
import 'firebase_account_contexts.dart';
import 'linked_account_session_lifetime.dart';
import 'session_timeout_policy.dart';

/// Supervisa la vigencia del acceso privado de la cuenta
/// vinculada a huella o reconocimiento facial.
///
/// Utiliza los mismos limites que la cuenta convencional.
///
/// No realiza operaciones Firebase ni solicita huellas.
/// Tampoco concede autorizaciones: observa una seleccion
/// que ya ha sido aprobada por el coordinador correspondiente.
///
/// Responsabilidades:
/// - Iniciar la vigencia despues de seleccionar A.
/// - Registrar actividad exclusivamente de A.
/// - Conservar una sesion vigente en segundo plano.
/// - Detectar expiraciones y revocar el acceso privado.
/// - Reaccionar al cierre manual o cambio de identidad.
/// - Impedir que la actividad de B renueve A.
///
/// La persistencia entre procesos se integra por separado.
final class LinkedAccountSessionLifecycleController {
  LinkedAccountSessionLifecycleController({
    required AccountSessionSelectionController selection,
    required FirebaseAccountSlot? linkedSlot,
    DateTime Function()? clock,
    void Function()? onExpired,
  }) : this._(selection, linkedSlot, clock ?? DateTime.now, onExpired);

  /// Inicializacion interna que conserva los nombres
  /// publicos de los parametros del constructor principal.
  ///
  /// De esta manera cumplimos prefer_initializing_formals
  /// sin cambiar los contratos de los consumidores.
  LinkedAccountSessionLifecycleController._(
    this._selection,
    this._linkedSlot,
    this._clock,
    this._onExpired,
  ) {
    _selection.addListener(_onSelectionChanged);
    _onSelectionChanged();
  }

  final AccountSessionSelectionController _selection;

  final LinkedAccountSessionLifetime _lifetime = LinkedAccountSessionLifetime();

  final DateTime Function() _clock;

  final void Function()? _onExpired;

  FirebaseAccountSlot? _linkedSlot;

  Timer? _deadlineTimer;

  bool _backgrounded = false;
  bool _disposed = false;

  DateTime _now() => _clock().toUtc();

  /// Registro actual, disponible para una futura capa
  /// de persistencia. No constituye una autorizacion.
  SessionTimeoutRecord? get record => _lifetime.record;

  /// Informa si hay una autorizacion vinculada vigente.
  ///
  /// Esta consulta no concede ni renueva el acceso.
  bool get hasValidLinkedAccess {
    if (!_isLinkedSelected()) {
      return false;
    }

    final userId = _selection.selectedUserId;

    return userId != null && _lifetime.isValid(userId: userId, now: _now());
  }

  bool get isBackgrounded => _backgrounded;

  /// Se exige una seleccion privada ya autorizada,
  /// perteneciente exactamente al contexto vinculado.
  bool _isLinkedSelected() {
    return !_disposed &&
        _linkedSlot != null &&
        _selection.value &&
        _selection.selectedSlot == _linkedSlot &&
        _selection.selectedUserId != null;
  }

  /// Se invoca al cambiar la identidad o el permiso privado.
  ///
  /// Un cambio A -> B o un cierre manual invalida la
  /// vigencia privada anterior, sin afectar Firebase.
  void _onSelectionChanged() {
    if (_disposed) {
      return;
    }

    if (!_isLinkedSelected()) {
      _resetLifetime();
      return;
    }

    final userId = _selection.selectedUserId!;

    final existing = _lifetime.record;

    if (existing == null) {
      // El selector ya verifico la identidad y
      // la operacion de autenticacion correspondiente.
      final started = _lifetime.start(userId: userId, now: _now());

      if (!started) {
        _expireLinkedAccess();
        return;
      }

      _scheduleDeadline();
      return;
    }

    if (existing.userId != userId ||
        !_lifetime.isValid(userId: userId, now: _now())) {
      _expireLinkedAccess();
      return;
    }

    _scheduleDeadline();
  }

  /// La vinculacion puede activarse o desactivarse
  /// desde Ajustes sin reconstruir los coordinadores.
  ///
  /// Si deja de existir una cuenta vinculada,
  /// se elimina exclusivamente su vigencia privada.
  void configureLinkedSlot(FirebaseAccountSlot? slot) {
    if (_disposed || _linkedSlot == slot) {
      return;
    }

    _linkedSlot = slot;
    _resetLifetime();

    if (slot != null) {
      _onSelectionChanged();
    }
  }

  /// Recupera la vigencia ORIGINAL de una sesion A autorizada.
  ///
  /// Debe llamarse sin esperas asincronas, inmediatamente despues
  /// de que el coordinador seguro seleccione A y ANTES de montar
  /// contenido privado. No concede autorizacion por si mismo.
  ///
  /// Verifica el registro ORIGINAL con las reglas de restauracion,
  /// que consideran el tiempo transcurrido fuera del proceso.
  /// Una vez aceptado el regreso al primer plano, restablece solo
  /// la ultima actividad; el inicio absoluto permanece intacto.
  ///
  /// El llamador debe confirmar la escritura de este registro
  /// actualizado en el diario antes de habilitar contenido privado.
  bool restoreAuthorized({
    required FirebaseAccountSlot slot,
    required String expectedUserId,
    required SessionTimeoutRecord record,
  }) {
    if (_disposed) {
      return false;
    }

    final selected = _isLinkedSelected();

    final sameIdentity =
        selected &&
        _linkedSlot == slot &&
        _selection.selectedSlot == slot &&
        _selection.selectedUserId == expectedUserId &&
        record.userId == expectedUserId;

    final now = _now();

    if (!sameIdentity || record.isExpired(now, restoring: true)) {
      // Si A ya estaba seleccionada, ninguna restauracion fallida
      // puede dejar vigente la sesion temporal nueva creada por
      // el listener de seleccion.
      if (selected) {
        closeLinkedAccess();
      }

      return false;
    }

    // Inicio original, no DateTime.now() como nuevo startedAt.
    // El regreso al primer plano renueva solo lastActivityAt.
    final resumedRecord = record.activity(now);

    if (!_lifetime.restore(
      record: resumedRecord,
      expectedUserId: expectedUserId,
      now: now,
    )) {
      closeLinkedAccess();
      return false;
    }

    _backgrounded = false;
    _scheduleDeadline();

    return hasValidLinkedAccess &&
        _lifetime.record?.startedAt.millisecondsSinceEpoch ==
            record.startedAt.millisecondsSinceEpoch;
  }

  /// Registra actividad real de la cuenta A.
  ///
  /// Las pulsaciones de B y las interacciones sin una
  /// cuenta vinculada seleccionada no producen cambios.
  void registerActivity() {
    if (!_isLinkedSelected() || _backgrounded) {
      return;
    }

    final userId = _selection.selectedUserId!;

    if (!_lifetime.registerActivity(userId: userId, now: _now())) {
      _expireLinkedAccess();
      return;
    }

    _scheduleDeadline();
  }

  /// Marca la salida al segundo plano.
  ///
  /// La aplicacion no solicita una nueva huella
  /// por esta transicion. Solamente comienza a
  /// contar el limite temporal de segundo plano.
  void enterBackground() {
    if (!_isLinkedSelected() || _backgrounded) {
      return;
    }

    final userId = _selection.selectedUserId!;

    if (!_lifetime.enterBackground(userId: userId, now: _now())) {
      _expireLinkedAccess();
      return;
    }

    _backgrounded = true;
    _scheduleDeadline();
  }

  /// Al regresar al primer plano:
  ///
  /// - Si la sesion sigue vigente, se conserva A.
  /// - Si esta vencida, se revoca su permiso privado.
  ///
  /// En ningun caso se cierra la sesion Firebase.
  void resume() {
    if (_disposed) {
      return;
    }

    if (!_isLinkedSelected()) {
      _resetLifetime();
      return;
    }

    final userId = _selection.selectedUserId!;

    if (_backgrounded) {
      _backgrounded = false;

      if (!_lifetime.resume(userId: userId, now: _now())) {
        _expireLinkedAccess();
        return;
      }
    } else if (!_lifetime.isValid(userId: userId, now: _now())) {
      _expireLinkedAccess();
      return;
    }

    _scheduleDeadline();
  }

  /// Verificacion explicita, util para recuperar
  /// el control tras temporizadores retrasados.
  ///
  /// No renueva la actividad de A.
  void checkCurrentValidity() {
    if (!_isLinkedSelected()) {
      _resetLifetime();
      return;
    }

    final userId = _selection.selectedUserId!;

    if (!_lifetime.isValid(userId: userId, now: _now())) {
      _expireLinkedAccess();
      return;
    }

    _scheduleDeadline();
  }

  void _scheduleDeadline() {
    _deadlineTimer?.cancel();
    _deadlineTimer = null;

    if (!_isLinkedSelected()) {
      return;
    }

    final deadline = _lifetime.nextDeadline;

    if (deadline == null) {
      _expireLinkedAccess();
      return;
    }

    final remaining = deadline.difference(_now());

    if (remaining <= Duration.zero) {
      _expireLinkedAccess();
      return;
    }

    _deadlineTimer = Timer(remaining, () {
      if (_disposed) {
        return;
      }

      checkCurrentValidity();
    });
  }

  /// Revoca exclusivamente el permiso privado
  /// de la identidad vinculada, nunca su Firebase.
  void _expireLinkedAccess() {
    if (_disposed) {
      return;
    }

    final wasLinkedSelected = _isLinkedSelected();

    _resetLifetime();

    if (!wasLinkedSelected) {
      return;
    }

    // lock() tambien notificara al controlador.
    // _resetLifetime() es idempotente.
    _selection.lock();

    _onExpired?.call();
  }

  void _resetLifetime() {
    _deadlineTimer?.cancel();
    _deadlineTimer = null;

    _backgrounded = false;
    _lifetime.revoke();
  }

  /// Cierre manual del acceso privado de A.
  ///
  /// Diferente de minimizar la aplicacion:
  /// esta operacion invalida inmediatamente A.
  void closeLinkedAccess() {
    if (_disposed) {
      return;
    }

    final wasLinkedSelected = _isLinkedSelected();

    _resetLifetime();

    if (wasLinkedSelected) {
      _selection.lock();
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _selection.removeListener(_onSelectionChanged);

    _resetLifetime();
  }
}
