import 'session_timeout_policy.dart';
import 'session_timeout_store.dart';

/// Serializa las operaciones sobre un almacén de sesiones.
///
/// Las lecturas, escrituras y eliminaciones utilizan una
/// única cola FIFO para evitar que las operaciones que
/// comparten este adaptador se ejecuten simultáneamente.
///
/// No modifica la política de vencimiento ni concede
/// acceso a contenido privado.
///
/// IMPORTANTE:
/// Todos los componentes que deban compartir esta
/// garantía deben utilizar la misma instancia.
final class SerializedSessionTimeoutStore implements SessionTimeoutStore {
  SerializedSessionTimeoutStore({required this.delegate});

  final SessionTimeoutStore delegate;

  Future<void> _tail = Future<void>.value();

  /// Agrega una operación a la cola.
  ///
  /// El resultado original, incluido cualquier error,
  /// se devuelve al llamador.
  ///
  /// Un fallo anterior no impide que comiencen las
  /// siguientes operaciones encoladas.
  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());

    // La cola interna consume el resultado únicamente
    // para permitir que la siguiente operación continúe.
    //
    // Esto NO oculta el error al llamador: result conserva
    // la excepción original.
    _tail = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );

    return result;
  }

  @override
  Future<SessionTimeoutRecord?> read() {
    return _enqueue<SessionTimeoutRecord?>(() => delegate.read());
  }

  @override
  Future<void> write(SessionTimeoutRecord record) {
    return _enqueue<void>(() => delegate.write(record));
  }

  @override
  Future<void> clear() {
    return _enqueue<void>(() => delegate.clear());
  }
}
