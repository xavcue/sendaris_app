import 'account_linked_session_continuity_assessment.dart';
import 'account_session_selection_controller.dart';
import 'firebase_account_contexts.dart';
import 'session_timeout_policy.dart';

/// Autorizacion vinculada obtenida durante el arranque.
///
/// Este resultado no debe persistirse como credencial.
///
/// Antes de mostrar datos privados, la raiz debe
/// restaurar la vigencia temporal original de A y
/// confirmar que el contexto seleccionado coincide.
final class AccountLinkedSessionRestoration {
  const AccountLinkedSessionRestoration({
    required this.slot,
    required this.userId,
    required this.record,
  });

  final FirebaseAccountSlot slot;
  final String userId;
  final SessionTimeoutRecord record;
}

/// Coordina la restauracion de una cuenta vinculada.
///
/// El evaluador de continuidad comprueba:
/// - Firebase y la identidad de la cuenta.
/// - La vinculacion biometrica.
/// - Los metadatos de sesion.
/// - La prueba nativa de Android Keystore.
///
/// La seleccion privada se realiza solamente despues
/// de esas comprobaciones.
///
/// La evaluacion se repite dentro de select() para
/// proteger las transiciones asincronas.
///
/// Este coordinador no emite credenciales nativas,
/// no modifica Firebase y no renueva las fechas.
final class AccountLinkedSessionRestoreCoordinator {
  AccountLinkedSessionRestoreCoordinator({
    required this.selection,
    required this.continuity,
    required this.linkedSlot,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AccountSessionSelectionController selection;
  final AccountLinkedSessionContinuityAssessment continuity;
  final FirebaseAccountSlot linkedSlot;

  final DateTime Function() _clock;

  DateTime _now() => _clock().toUtc();

  bool _validUserId(String value) {
    return value.isNotEmpty && value.trim() == value;
  }

  bool _sameRecord(SessionTimeoutRecord first, SessionTimeoutRecord second) {
    return first.userId == second.userId &&
        first.startedAt.toUtc() == second.startedAt.toUtc() &&
        first.lastActivityAt.toUtc() == second.lastActivityAt.toUtc() &&
        first.backgroundAt?.toUtc() == second.backgroundAt?.toUtc();
  }

  bool _sameCandidate(
    AccountLinkedContinuityCandidate first,
    AccountLinkedContinuityCandidate second,
  ) {
    return first.slot == second.slot &&
        first.userId == second.userId &&
        _sameRecord(first.record, second.record);
  }

  bool _validCandidate(AccountLinkedContinuityCandidate? candidate) {
    if (candidate == null) {
      return false;
    }

    return candidate.slot == linkedSlot &&
        _validUserId(candidate.userId) &&
        candidate.record.userId == candidate.userId &&
        !candidate.record.isExpired(_now(), restoring: true);
  }

  /// Intenta restaurar exclusivamente la cuenta
  /// vinculada al contexto indicado.
  ///
  /// Devuelve null si no existe prueba de continuidad,
  /// si alguna comprobacion falla o si cambia el
  /// estado durante la autorizacion.
  ///
  /// El resultado favorable debe entregarse al
  /// controlador temporal de A antes de montar
  /// contenido privado.
  Future<AccountLinkedSessionRestoration?> restoreLinked() async {
    if (selection.value || selection.isVerifying) {
      return null;
    }

    final AccountLinkedContinuityCandidate? initial;

    try {
      initial = await continuity.evaluate();
    } catch (_) {
      return null;
    }

    if (!_validCandidate(initial) || selection.value || selection.isVerifying) {
      return null;
    }

    final candidate = initial!;
    final slot = candidate.slot;
    final userId = candidate.userId;
    final record = candidate.record;

    final bool accepted;

    try {
      accepted = await selection.select(
        slot: slot,
        expectedUserId: userId,
        verifyAccess: () async {
          final verified = await continuity.evaluate();

          return _validCandidate(verified) &&
              _sameCandidate(candidate, verified!) &&
              !record.isExpired(_now(), restoring: true);
        },
      );
    } catch (_) {
      return null;
    }

    if (!accepted) {
      return null;
    }

    final sameSelection =
        selection.value &&
        selection.selectedSlot == slot &&
        selection.selectedUserId == userId;

    if (!sameSelection || record.isExpired(_now(), restoring: true)) {
      // Revocar exclusivamente la autorizacion que
      // este coordinador acaba de seleccionar.
      //
      // No bloquear una cuenta diferente que pueda
      // haberse seleccionado posteriormente.
      if (sameSelection) {
        selection.lock();
      }

      return null;
    }

    return AccountLinkedSessionRestoration(
      slot: slot,
      userId: userId,
      record: record,
    );
  }
}
