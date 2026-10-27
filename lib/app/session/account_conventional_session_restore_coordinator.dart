import 'account_session_selection_controller.dart';
import 'account_session_startup_assessment.dart';
import 'firebase_account_contexts.dart';
import 'session_timeout_policy.dart';

/// Autorizacion convencional obtenida durante el arranque.
///
/// No debe almacenarse como una credencial permanente.
/// Su uso corresponde exclusivamente al arranque actual.
///
/// El SessionTimeoutGuard debe recibir [record] y volver
/// a comprobar su vigencia antes de construir el
/// contenido privado de la cuenta.
final class AccountConventionalSessionRestoration {
  const AccountConventionalSessionRestoration({
    required this.slot,
    required this.userId,
    required this.record,
  });

  final FirebaseAccountSlot slot;
  final String userId;
  final SessionTimeoutRecord record;
}

/// Conecta la evaluacion segura de arranque con
/// AccountSessionSelectionController.
///
/// Nunca autoriza la cuenta biometrica.
///
/// Para B, verifica:
/// - Un candidato convencional inicial.
/// - La identidad y vigencia de ese candidato.
/// - Una segunda evaluacion durante select().
/// - La inmutabilidad de las fechas observadas.
/// - La seleccion final del mismo UID y contexto.
///
/// El selector controla la revision de autorizacion
/// y rechaza cambios de identidad durante los awaits.
///
/// Este componente no modifica Firebase, Firestore,
/// Keystore ni SharedPreferences.
///
/// No restaura por si mismo pantallas privadas:
/// el guard temporal debe validar la sesion antes
/// de permitir la construccion de su contenido.
final class AccountConventionalSessionRestoreCoordinator {
  AccountConventionalSessionRestoreCoordinator({
    required this.selection,
    required this.assessment,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AccountSessionSelectionController selection;
  final AccountSessionStartupAssessment assessment;

  final DateTime Function() _clock;

  DateTime _now() => _clock().toUtc();

  bool _validUserId(String? userId) {
    return userId != null && userId.isNotEmpty && userId.trim() == userId;
  }

  bool _sameRecord(SessionTimeoutRecord first, SessionTimeoutRecord second) {
    return first.userId == second.userId &&
        first.startedAt.toUtc() == second.startedAt.toUtc() &&
        first.lastActivityAt.toUtc() == second.lastActivityAt.toUtc() &&
        first.backgroundAt?.toUtc() == second.backgroundAt?.toUtc();
  }

  /// Compara dos evaluaciones independientes.
  ///
  /// No permite cambiar a otra cuenta ni sustituir
  /// silenciosamente el inicio absoluto de la sesion.
  bool _sameCandidate(
    AccountSessionStartupAssessmentResult first,
    AccountSessionStartupAssessmentResult second,
  ) {
    if (!first.hasConventionalCandidate || !second.hasConventionalCandidate) {
      return false;
    }

    final firstRecord = first.record;
    final secondRecord = second.record;

    return first.slot == second.slot &&
        first.userId == second.userId &&
        firstRecord != null &&
        secondRecord != null &&
        _sameRecord(firstRecord, secondRecord);
  }

  /// Intenta restaurar exclusivamente B.
  ///
  /// Devuelve null cuando no existe una autorizacion
  /// convencional verificable.
  ///
  /// En particular:
  /// - No convierte una vinculacion de A en permiso.
  /// - No sustituye un acceso ya autorizado.
  /// - No acepta una sesion temporal vencida.
  /// - No crea fechas nuevas para ocultar vencimientos.
  Future<AccountConventionalSessionRestoration?> restoreConventional() async {
    if (selection.value || selection.isVerifying) {
      return null;
    }

    final AccountSessionStartupAssessmentResult initial;

    try {
      initial = await assessment.evaluate();
    } catch (_) {
      return null;
    }

    if (!initial.hasConventionalCandidate) {
      return null;
    }

    final slot = initial.slot;
    final userId = initial.userId;
    final record = initial.record;

    if (slot == null ||
        !_validUserId(userId) ||
        record == null ||
        record.userId != userId ||
        record.isExpired(_now(), restoring: true)) {
      return null;
    }

    // La funcion verifyAccess no es un booleano de UI.
    //
    // Ejecuta nuevamente el evaluador que consulta
    // Firebase, la vinculacion y los metadatos.
    final bool accepted;

    try {
      accepted = await selection.select(
        slot: slot,
        expectedUserId: userId!,
        verifyAccess: () async {
          final verified = await assessment.evaluate();

          return _sameCandidate(initial, verified) &&
              !record.isExpired(_now(), restoring: true);
        },
      );
    } catch (_) {
      return null;
    }

    if (!accepted) {
      return null;
    }

    // Al terminar el callback puede haber transcurrido
    // tiempo suficiente para que expire el registro.
    //
    // No se permite utilizar una autorizacion obtenida
    // fuera de su ventana temporal.
    if (!selection.value ||
        selection.selectedSlot != slot ||
        selection.selectedUserId != userId ||
        record.isExpired(_now(), restoring: true)) {
      // Nunca bloquear otra identidad seleccionada
      // posteriormente por un flujo distinto.
      if (selection.value &&
          selection.selectedSlot == slot &&
          selection.selectedUserId == userId) {
        selection.lock();
      }

      return null;
    }

    return AccountConventionalSessionRestoration(
      slot: slot,
      userId: userId,
      record: record,
    );
  }
}
