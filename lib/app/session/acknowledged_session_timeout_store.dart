import 'package:flutter/foundation.dart';

import 'serialized_session_timeout_store.dart';
import 'session_timeout_policy.dart';
import 'session_timeout_store.dart';

/// Almacenamiento serializado con confirmaciones observables.
///
/// Las operaciones de lectura, escritura y eliminación
/// se ejecutan mediante una única cola FIFO.
///
/// Las confirmaciones se publican DENTRO de esa cola,
/// después de que el almacenamiento subyacente haya
/// completado satisfactoriamente la operación.
///
/// Esto impide que una escritura anterior publique
/// una confirmación después de una eliminación posterior.
///
/// Este componente no autentica usuarios, no valida
/// sesiones Firebase y no autoriza rutas privadas.
final class AcknowledgedSessionTimeoutStore extends ChangeNotifier
    implements SessionTimeoutStore {
  AcknowledgedSessionTimeoutStore({required SessionTimeoutStore delegate}) {
    _serialized = SerializedSessionTimeoutStore(
      delegate: _ConfirmingSessionTimeoutStore(
        delegate,
        _confirmWrite,
        _confirmClear,
      ),
    );
  }

  late final SerializedSessionTimeoutStore _serialized;

  SessionTimeoutRecord? _lastPersistedRecord;

  int _revision = 0;
  bool _disposed = false;

  /// Último registro cuya escritura fue confirmada.
  ///
  /// Se establece en null después de una eliminación
  /// confirmada.
  ///
  /// No constituye una autorización de acceso privado.
  SessionTimeoutRecord? get lastPersistedRecord => _lastPersistedRecord;

  /// Número de operaciones de escritura o eliminación
  /// completadas satisfactoriamente.
  ///
  /// Las lecturas y operaciones fallidas no incrementan
  /// esta revisión.
  int get revision => _revision;

  bool get isDisposed => _disposed;

  @override
  Future<SessionTimeoutRecord?> read() {
    return _serialized.read();
  }

  @override
  Future<void> write(SessionTimeoutRecord record) {
    // _ConfirmingSessionTimeoutStore publica el resultado
    // antes de liberar la cola para la siguiente operación.
    return _serialized.write(record);
  }

  @override
  Future<void> clear() {
    // La confirmación de eliminación también se ejecuta
    // dentro de la cola, después del clear persistente.
    return _serialized.clear();
  }

  void _confirmWrite(SessionTimeoutRecord record) {
    _lastPersistedRecord = record;
    _revision++;

    _notifyIfActive();
  }

  void _confirmClear() {
    _lastPersistedRecord = null;
    _revision++;

    _notifyIfActive();
  }

  void _notifyIfActive() {
    if (_disposed) {
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    // Las operaciones persistentes que ya comenzaron
    // conservan su ejecución.
    //
    // Ninguna confirmación posterior intentará notificar
    // a los observadores de este ChangeNotifier destruido.
    super.dispose();
  }
}

/// Delegado interno que confirma operaciones persistidas.
///
/// Al colocar este delegado DENTRO de
/// SerializedSessionTimeoutStore, tanto la mutación
/// persistente como su confirmación ocupan la misma
/// posición en la cola FIFO.
///
/// Ninguna eliminación posterior puede adelantarse
/// a la confirmación de una escritura anterior.
final class _ConfirmingSessionTimeoutStore implements SessionTimeoutStore {
  const _ConfirmingSessionTimeoutStore(
    this._delegate,
    this._onWriteConfirmed,
    this._onClearConfirmed,
  );

  final SessionTimeoutStore _delegate;

  final void Function(SessionTimeoutRecord) _onWriteConfirmed;
  final void Function() _onClearConfirmed;

  @override
  Future<SessionTimeoutRecord?> read() {
    // Las lecturas se serializan mediante el adaptador
    // externo y no producen confirmaciones.
    return _delegate.read();
  }

  @override
  Future<void> write(SessionTimeoutRecord record) async {
    // Si falla, la excepción se propaga y no se publica
    // una confirmación falsa.
    await _delegate.write(record);

    // Esta confirmación ocurre antes de que el
    // serializador comience la operación siguiente.
    _onWriteConfirmed(record);
  }

  @override
  Future<void> clear() async {
    // Si falla la eliminación, se conserva el estado
    // de confirmación anterior.
    await _delegate.clear();

    // Ninguna escritura anterior podrá volver a publicar
    // un registro después de esta confirmación.
    _onClearConfirmed();
  }
}
