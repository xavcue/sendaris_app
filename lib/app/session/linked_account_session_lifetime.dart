import 'session_timeout_policy.dart';

/// Administra la vigencia temporal del acceso privado
/// de una cuenta vinculada a huella o reconocimiento facial.
///
/// Utiliza exactamente la misma politica temporal
/// que el acceso convencional de Sendaris.
///
/// No autentica con Firebase, no utiliza Android Keystore,
/// no concede autorizaciones y no desconecta cuentas.
///
/// El componente raiz es responsable de:
/// - Autorizar inicialmente la cuenta vinculada.
/// - Persistir y restaurar el registro cuando corresponda.
/// - Bloquear el acceso privado cuando expire.
/// - Mantener separadas las sesiones de A y B.
final class LinkedAccountSessionLifetime {
  SessionTimeoutRecord? _record;

  SessionTimeoutRecord? get record => _record;

  String? get userId => _record?.userId;

  bool get hasSession => _record != null;

  bool _validUserId(String userId) {
    return userId.isNotEmpty && userId.trim() == userId;
  }

  bool _matches(String userId) {
    return _validUserId(userId) && _record != null && _record!.userId == userId;
  }

  /// Comienza una vigencia nueva despues de una
  /// autenticacion autorizada de la cuenta vinculada.
  ///
  /// La vinculacion por si sola no puede iniciar
  /// una sesion privada.
  bool start({required String userId, required DateTime now}) {
    revoke();

    if (!_validUserId(userId)) {
      return false;
    }

    final instant = now.toUtc();

    _record = SessionTimeoutRecord(
      userId: userId,
      startedAt: instant,
      lastActivityAt: instant,
    );

    return true;
  }

  /// Comprueba la validez de un registro restaurado.
  ///
  /// No se permite restaurar otra identidad, un
  /// registro vencido o un registro mal formado.
  ///
  /// Esta comprobacion no sustituye la validacion
  /// Firebase ni la autorizacion del componente raiz.
  bool restore({
    required SessionTimeoutRecord record,
    required String expectedUserId,
    required DateTime now,
  }) {
    revoke();

    if (!_validUserId(expectedUserId) ||
        record.userId != expectedUserId ||
        record.isExpired(now.toUtc(), restoring: true)) {
      return false;
    }

    _record = record;

    return true;
  }

  /// Validez actual, sin renovar la actividad.
  bool isValid({required String userId, required DateTime now}) {
    final record = _record;

    return _matches(userId) && record != null && !record.isExpired(now.toUtc());
  }

  /// Registra una actividad real de la cuenta vinculada.
  ///
  /// La actividad de otra cuenta no renueva A.
  ///
  /// Tampoco renueva A mientras se encuentre
  /// marcada como aplicacion en segundo plano.
  bool registerActivity({required String userId, required DateTime now}) {
    if (!_matches(userId)) {
      revoke();
      return false;
    }

    final record = _record!;

    if (record.isExpired(now.toUtc())) {
      revoke();
      return false;
    }

    if (record.backgroundAt != null) {
      return false;
    }

    _record = record.activity(now);

    return true;
  }

  /// Marca la salida al segundo plano.
  ///
  /// No revoca inmediatamente una sesion vigente.
  bool enterBackground({required String userId, required DateTime now}) {
    if (!_matches(userId)) {
      revoke();
      return false;
    }

    final record = _record!;

    if (record.isExpired(now.toUtc())) {
      revoke();
      return false;
    }

    if (record.backgroundAt != null) {
      return true;
    }

    _record = record.backgrounded(now);

    return true;
  }

  /// Comprueba el tiempo transcurrido en segundo plano.
  ///
  /// Si A continua vigente, se puede regresar
  /// directamente sin solicitar otra huella.
  ///
  /// Si vencio, el componente raiz debe revocar
  /// el permiso privado y solicitar nueva autenticacion.
  bool resume({required String userId, required DateTime now}) {
    if (!_matches(userId)) {
      revoke();
      return false;
    }

    final record = _record!;

    if (record.isExpired(now.toUtc())) {
      revoke();
      return false;
    }

    _record = record.activity(now);

    return true;
  }

  /// Calcula el siguiente limite que debe vigilar
  /// el componente raiz.
  ///
  /// No renueva ni modifica el registro.
  DateTime? get nextDeadline {
    final record = _record;

    if (record == null) {
      return null;
    }

    final absoluteDeadline = record.startedAt.add(
      SessionTimeoutPolicy.absolute,
    );

    final backgroundAt = record.backgroundAt;

    final inactivityDeadline = backgroundAt != null
        ? backgroundAt.add(SessionTimeoutPolicy.background)
        : record.lastActivityAt.add(SessionTimeoutPolicy.foregroundIdle);

    return inactivityDeadline.isBefore(absoluteDeadline)
        ? inactivityDeadline
        : absoluteDeadline;
  }

  /// Invalida el registro privado sin cerrar Firebase
  /// ni modificar la vinculacion del dispositivo.
  ///
  /// La accion posterior corresponde al componente raiz.
  void revoke() {
    _record = null;
  }
}
