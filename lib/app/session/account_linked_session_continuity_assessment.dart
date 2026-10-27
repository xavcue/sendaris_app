import 'account_session_startup_assessment.dart';
import 'firebase_account_contexts.dart';
import 'session_timeout_policy.dart';

/// Contrato de una prueba nativa de continuidad.
///
/// La implementacion definitiva debe verificar una
/// credencial protegida criptograficamente en Android.
///
/// El resultado no puede proceder solamente de un UID,
/// una preferencia local o una fecha almacenada.
///
/// La credencial debe quedar asociada al UID, contexto
/// Firebase y comienzo original de la sesion.
///
/// Su emision se realizara exclusivamente despues de
/// una autorizacion biometrica correcta.
abstract interface class AccountLinkedContinuityProof {
  Future<bool> verify({
    required FirebaseAccountSlot slot,
    required String expectedUserId,
    required DateTime sessionStartedAt,
  });
}

/// Candidato vinculado validado durante el arranque.
///
/// Esta clase no representa una autorizacion privada.
///
/// El coordinador posterior debera completar la
/// seleccion de A y restaurar sus fechas originales.
final class AccountLinkedContinuityCandidate {
  const AccountLinkedContinuityCandidate({
    required this.slot,
    required this.userId,
    required this.record,
  });

  final FirebaseAccountSlot slot;
  final String userId;
  final SessionTimeoutRecord record;
}

/// Evalua si una cuenta vinculada dispone de una
/// prueba verificable para continuar entre procesos.
///
/// Nunca muestra una pantalla, desbloquea Firebase
/// ni modifica AccountSessionSelectionController.
///
/// Comprueba la identidad y los tiempos antes y
/// despues de obtener la prueba criptografica.
final class AccountLinkedSessionContinuityAssessment {
  AccountLinkedSessionContinuityAssessment({
    required this.startup,
    required this.proof,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AccountSessionStartupAssessment startup;
  final AccountLinkedContinuityProof proof;
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

  bool _sameCandidate(
    AccountSessionStartupAssessmentResult first,
    AccountSessionStartupAssessmentResult second,
  ) {
    if (!first.requiresLinkedProof || !second.requiresLinkedProof) {
      return false;
    }

    final original = first.record;
    final updated = second.record;

    if (original == null || updated == null) {
      return false;
    }

    return first.slot == second.slot &&
        first.userId == second.userId &&
        _sameRecord(original, updated);
  }

  /// Solo devuelve un candidato si todas las
  /// comprobaciones de continuidad tienen exito.
  ///
  /// Aun cuando devuelva un candidato, el selector
  /// privado sigue bloqueado. La autorizacion real
  /// sera responsabilidad del siguiente coordinador.
  Future<AccountLinkedContinuityCandidate?> evaluate() async {
    try {
      final first = await startup.evaluate();

      final slot = first.slot;
      final userId = first.userId;
      final record = first.record;

      if (!first.requiresLinkedProof ||
          slot == null ||
          !_validUserId(userId) ||
          record == null ||
          record.userId != userId ||
          record.isExpired(_now(), restoring: true)) {
        return null;
      }

      // La prueba se vincula al inicio ABSOLUTO
      // de la sesion, no a la ultima actividad.
      //
      // Una actividad nueva nunca debe permitir
      // sustituir una sesion vencida por otra.
      final verified = await proof.verify(
        slot: slot,
        expectedUserId: userId!,
        sessionStartedAt: record.startedAt.toUtc(),
      );

      if (!verified) {
        return null;
      }

      // Una operacion nativa asincrona puede
      // finalizar despues de un cierre de sesion
      // o de un cambio de cuenta.
      //
      // Por ello se repite la evaluacion completa
      // antes de devolver el candidato.
      final second = await startup.evaluate();

      if (!_sameCandidate(first, second)) {
        return null;
      }

      final confirmed = second.record;

      if (confirmed == null || confirmed.isExpired(_now(), restoring: true)) {
        return null;
      }

      return AccountLinkedContinuityCandidate(
        slot: slot,
        userId: userId,
        record: confirmed,
      );
    } catch (_) {
      // Errores de Firebase, Android Keystore,
      // almacenamiento o validacion no producen
      // autorizaciones privadas.
      return null;
    }
  }
}
