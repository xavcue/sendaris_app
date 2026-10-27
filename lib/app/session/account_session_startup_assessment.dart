import 'account_active_session_checkpoint.dart';
import 'account_biometric_access_coordinator.dart';
import 'account_session_persistence_journal.dart';
import 'biometric_binding_policy.dart';
import 'firebase_account_contexts.dart';
import 'session_timeout_policy.dart';

/// Resultado de evaluar una posible restauracion.
///
/// No representa un permiso de acceso privado.
///
/// La raiz debe completar la autorizacion con
/// AccountSessionSelectionController y configurar
/// el guard temporal correspondiente.
final class AccountSessionStartupAssessmentResult {
  const AccountSessionStartupAssessmentResult({
    required this.decision,
    this.slot,
    this.userId,
    this.record,
  });

  final AccountSessionResumeDecision decision;
  final FirebaseAccountSlot? slot;
  final String? userId;
  final SessionTimeoutRecord? record;

  /// Solo indica que B puede intentar continuar.
  ///
  /// La raiz debe volver a validar la identidad
  /// al conceder el acceso privado.
  bool get hasConventionalCandidate =>
      decision == AccountSessionResumeDecision.restoreConventional &&
      slot != null &&
      userId != null &&
      record != null;

  /// A necesita una prueba de autorizacion segura.
  ///
  /// Firebase y los tiempos, por si solos,
  /// nunca desbloquean la cuenta vinculada.
  bool get requiresLinkedProof =>
      decision == AccountSessionResumeDecision.requireLinkedAuthorization &&
      slot != null &&
      userId != null &&
      record != null;
}

/// Evalua los candidatos de restauracion de A y B.
///
/// Secuencia:
/// 1. Leer una fotografia de los metadatos.
/// 2. Consultar la vinculacion biometrica.
/// 3. Comprobar identidades, roles y tiempos.
/// 4. Validar la sesion Firebase de la cuenta activa.
/// 5. Volver a leer los metadatos y la vinculacion.
/// 6. Rechazar cambios ocurridos durante la validacion.
///
/// No selecciona cuentas ni muestra datos privados.
/// No desconecta Firebase.
/// No solicita huellas.
/// No modifica el almacenamiento.
///
/// El llamador debe tratar cualquier error como
/// una restauracion no autorizada.
final class AccountSessionStartupAssessment {
  AccountSessionStartupAssessment({
    required this.readSnapshot,
    required this.readBinding,
    required this.primarySession,
    required this.secondarySession,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Future<AccountSessionPersistenceSnapshot> Function() readSnapshot;

  final Future<BiometricBindingState> Function() readBinding;

  final AccountFirebaseSessionVerifier primarySession;
  final AccountFirebaseSessionVerifier secondarySession;

  final DateTime Function() _clock;

  DateTime _now() => _clock().toUtc();

  AccountFirebaseSessionVerifier _sessionFor(FirebaseAccountSlot slot) {
    return switch (slot) {
      FirebaseAccountSlot.primary => primarySession,
      FirebaseAccountSlot.secondary => secondarySession,
    };
  }

  AccountSessionResumeDecision _decide({
    required AccountSessionPersistenceSnapshot snapshot,
    required BiometricBindingState binding,
  }) {
    return AccountActiveSessionRestorationPolicy.decide(
      checkpoint: snapshot.active,
      primaryRecord: snapshot.primary,
      secondaryRecord: snapshot.secondary,
      primaryFirebaseUserId: primarySession.currentUserId,
      secondaryFirebaseUserId: secondarySession.currentUserId,
      binding: binding,
      now: _now(),
    );
  }

  SessionTimeoutRecord? _recordFor(
    AccountSessionPersistenceSnapshot snapshot,
    FirebaseAccountSlot slot,
  ) {
    return switch (slot) {
      FirebaseAccountSlot.primary => snapshot.primary,
      FirebaseAccountSlot.secondary => snapshot.secondary,
    };
  }

  bool _sameCheckpoint(
    AccountActiveSessionCheckpoint? before,
    AccountActiveSessionCheckpoint? after,
  ) {
    if (before == null || after == null) {
      return before == null && after == null;
    }

    return before.slot == after.slot && before.userId == after.userId;
  }

  bool _sameRecord(SessionTimeoutRecord? before, SessionTimeoutRecord? after) {
    if (before == null || after == null) {
      return before == null && after == null;
    }

    return before.userId == after.userId &&
        before.startedAt == after.startedAt &&
        before.lastActivityAt == after.lastActivityAt &&
        before.backgroundAt == after.backgroundAt;
  }

  AccountSessionStartupAssessmentResult _unavailable(
    AccountSessionResumeDecision decision,
  ) {
    return AccountSessionStartupAssessmentResult(decision: decision);
  }

  /// Determina si existe una cuenta candidata.
  ///
  /// La respuesta nunca establece selection.value=true.
  ///
  /// Un resultado favorable es solamente el primer
  /// paso del protocolo de restauracion.
  Future<AccountSessionStartupAssessmentResult> evaluate() async {
    try {
      final firstSnapshot = await readSnapshot();
      final firstBinding = await readBinding();

      final firstDecision = _decide(
        snapshot: firstSnapshot,
        binding: firstBinding,
      );

      if (firstDecision != AccountSessionResumeDecision.restoreConventional &&
          firstDecision !=
              AccountSessionResumeDecision.requireLinkedAuthorization) {
        return _unavailable(firstDecision);
      }

      final checkpoint = firstSnapshot.active;

      if (checkpoint == null) {
        return _unavailable(AccountSessionResumeDecision.requireSignIn);
      }

      final session = _sessionFor(checkpoint.slot);
      final record = _recordFor(firstSnapshot, checkpoint.slot);

      if (session.currentUserId != checkpoint.userId ||
          record == null ||
          record.userId != checkpoint.userId) {
        return _unavailable(AccountSessionResumeDecision.requireSignIn);
      }

      // No se utiliza una identidad cacheada como
      // prueba suficiente de sesion Firebase.
      final firebaseValid = await session.validate(
        expectedUserId: checkpoint.userId,
      );

      if (!firebaseValid || session.currentUserId != checkpoint.userId) {
        return _unavailable(AccountSessionResumeDecision.requireSignIn);
      }

      // Una validacion remota permite que ocurran
      // operaciones asincronas de otras sesiones.
      //
      // Es obligatorio volver a leer el estado.
      final secondSnapshot = await readSnapshot();
      final secondBinding = await readBinding();

      final secondDecision = _decide(
        snapshot: secondSnapshot,
        binding: secondBinding,
      );

      if (secondDecision != firstDecision ||
          !_sameCheckpoint(firstSnapshot.active, secondSnapshot.active) ||
          !_sameRecord(record, _recordFor(secondSnapshot, checkpoint.slot))) {
        return _unavailable(
          secondDecision == AccountSessionResumeDecision.denyAccess
              ? AccountSessionResumeDecision.denyAccess
              : AccountSessionResumeDecision.requireSignIn,
        );
      }

      // Una reconfiguracion A/B, un cierre manual
      // o un timeout no puede recuperarse utilizando
      // el resultado de la comprobacion anterior.
      if (session.currentUserId != checkpoint.userId ||
          secondSnapshot.active?.userId != checkpoint.userId ||
          secondSnapshot.active?.slot != checkpoint.slot) {
        return _unavailable(AccountSessionResumeDecision.requireSignIn);
      }

      return AccountSessionStartupAssessmentResult(
        decision: secondDecision,
        slot: checkpoint.slot,
        userId: checkpoint.userId,
        record: _recordFor(secondSnapshot, checkpoint.slot),
      );
    } catch (_) {
      // Un fallo del almacenamiento, de Keystore
      // o de los verificadores nunca autoriza acceso.
      return _unavailable(AccountSessionResumeDecision.denyAccess);
    }
  }
}
