import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_active_session_checkpoint.dart';
import 'package:sendaris/app/session/account_biometric_access_coordinator.dart';
import 'package:sendaris/app/session/account_session_persistence_journal.dart';
import 'package:sendaris/app/session/account_session_startup_assessment.dart';
import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';

final class _FakeFirebaseSession implements AccountFirebaseSessionVerifier {
  _FakeFirebaseSession(this.currentUserId);

  @override
  String? currentUserId;

  bool accepted = true;
  int validationCalls = 0;

  Future<bool> Function(String expectedUserId)? onValidate;

  @override
  Future<bool> validate({required String expectedUserId}) async {
    validationCalls++;

    final callback = onValidate;

    if (callback != null) {
      return callback(expectedUserId);
    }

    return accepted && currentUserId == expectedUserId;
  }
}

void main() {
  final start = DateTime.utc(2026, 10, 22, 12);

  late DateTime now;
  late _FakeFirebaseSession primary;
  late _FakeFirebaseSession secondary;

  late AccountSessionPersistenceSnapshot snapshot;
  late BiometricBindingState binding;
  late AccountSessionStartupAssessment assessment;

  AccountActiveSessionCheckpoint checkpoint(
    FirebaseAccountSlot slot,
    String userId,
  ) {
    return AccountActiveSessionCheckpoint(slot: slot, userId: userId);
  }

  SessionTimeoutRecord record(
    String userId, {
    DateTime? startedAt,
    DateTime? lastActivityAt,
    DateTime? backgroundAt,
  }) {
    return SessionTimeoutRecord(
      userId: userId,
      startedAt: startedAt ?? start,
      lastActivityAt: lastActivityAt ?? start,
      backgroundAt: backgroundAt,
    );
  }

  /// B esta en PRIMARY y no existe vinculacion.
  void configureBWithoutBinding() {
    primary.currentUserId = 'uid-b';
    secondary.currentUserId = null;

    binding = const BiometricBindingDisabled();

    snapshot = AccountSessionPersistenceSnapshot(
      active: checkpoint(FirebaseAccountSlot.primary, 'uid-b'),
      primary: record('uid-b'),
      secondary: null,
    );
  }

  /// A esta vinculada en PRIMARY.
  void configureLinkedA() {
    primary.currentUserId = 'uid-a';
    secondary.currentUserId = null;

    binding = const BiometricBindingEnabled(userId: 'uid-a');

    snapshot = AccountSessionPersistenceSnapshot(
      active: checkpoint(FirebaseAccountSlot.primary, 'uid-a'),
      primary: record('uid-a'),
      secondary: null,
    );
  }

  /// A esta vinculada en PRIMARY y B es convencional
  /// en SECONDARY. La ultima cuenta activa es B.
  void configureConventionalB() {
    primary.currentUserId = 'uid-a';
    secondary.currentUserId = 'uid-b';

    binding = const BiometricBindingEnabled(userId: 'uid-a');

    snapshot = AccountSessionPersistenceSnapshot(
      active: checkpoint(FirebaseAccountSlot.secondary, 'uid-b'),
      primary: record('uid-a'),
      secondary: record('uid-b'),
    );
  }

  setUp(() {
    now = start.add(const Duration(minutes: 10));

    primary = _FakeFirebaseSession(null);
    secondary = _FakeFirebaseSession(null);

    binding = const BiometricBindingDisabled();

    snapshot = const AccountSessionPersistenceSnapshot(
      active: null,
      primary: null,
      secondary: null,
    );

    assessment = AccountSessionStartupAssessment(
      readSnapshot: () async => snapshot,
      readBinding: () async => binding,
      primarySession: primary,
      secondarySession: secondary,
      clock: () => now,
    );
  });

  group('AUTH-03 B8.10B.10A - Evaluacion del arranque', () {
    test('sin checkpoint exige iniciar sesion', () async {
      final result = await assessment.evaluate();

      expect(result.decision, AccountSessionResumeDecision.requireSignIn);
      expect(result.slot, isNull);
      expect(result.userId, isNull);
      expect(primary.validationCalls, 0);
      expect(secondary.validationCalls, 0);
    });

    test('B sin vinculacion valida Firebase en PRIMARY', () async {
      configureBWithoutBinding();

      final result = await assessment.evaluate();

      expect(result.hasConventionalCandidate, isTrue);
      expect(result.requiresLinkedProof, isFalse);
      expect(result.decision, AccountSessionResumeDecision.restoreConventional);
      expect(result.slot, FirebaseAccountSlot.primary);
      expect(result.userId, 'uid-b');
      expect(result.record?.startedAt, start);
      expect(primary.validationCalls, 1);
      expect(secondary.validationCalls, 0);
    });

    test('B con A vinculada valida Firebase en SECONDARY', () async {
      configureConventionalB();

      final result = await assessment.evaluate();

      expect(result.hasConventionalCandidate, isTrue);
      expect(result.slot, FirebaseAccountSlot.secondary);
      expect(result.userId, 'uid-b');
      expect(primary.validationCalls, 0);
      expect(secondary.validationCalls, 1);
    });

    test('A vinculada no recibe acceso sin prueba nativa', () async {
      configureLinkedA();

      final result = await assessment.evaluate();

      expect(result.hasConventionalCandidate, isFalse);
      expect(result.requiresLinkedProof, isTrue);
      expect(
        result.decision,
        AccountSessionResumeDecision.requireLinkedAuthorization,
      );
      expect(result.slot, FirebaseAccountSlot.primary);
      expect(result.userId, 'uid-a');
      expect(primary.validationCalls, 1);
    });

    test('SECONDARY no se restaura sin A vinculada', () async {
      configureConventionalB();
      binding = const BiometricBindingDisabled();

      final result = await assessment.evaluate();

      expect(result.decision, AccountSessionResumeDecision.denyAccess);
      expect(result.hasConventionalCandidate, isFalse);
    });

    test('UID Firebase diferente impide continuar', () async {
      configureConventionalB();
      secondary.currentUserId = 'uid-c';

      final result = await assessment.evaluate();

      expect(result.decision, AccountSessionResumeDecision.requireSignIn);
      expect(result.hasConventionalCandidate, isFalse);
    });

    test('Firebase rechazado impide continuar', () async {
      configureConventionalB();
      secondary.accepted = false;

      final result = await assessment.evaluate();

      expect(result.decision, AccountSessionResumeDecision.requireSignIn);
      expect(result.hasConventionalCandidate, isFalse);
      expect(secondary.validationCalls, 1);
    });

    test('una sesion vencida no es candidata', () async {
      configureConventionalB();
      now = start.add(SessionTimeoutPolicy.absolute);

      final result = await assessment.evaluate();

      expect(result.decision, AccountSessionResumeDecision.requireSignIn);
      expect(result.record, isNull);
      expect(secondary.validationCalls, 0);
    });

    test('vinculacion ilegible bloquea restauracion', () async {
      configureLinkedA();
      binding = const BiometricBindingUnavailable();

      final result = await assessment.evaluate();

      expect(result.decision, AccountSessionResumeDecision.denyAccess);
      expect(result.requiresLinkedProof, isFalse);
    });

    test('dos contextos con el mismo UID se rechazan', () async {
      configureLinkedA();
      secondary.currentUserId = 'uid-a';

      final result = await assessment.evaluate();

      expect(result.decision, AccountSessionResumeDecision.denyAccess);
      expect(result.slot, isNull);
    });

    test('cerrar B durante Firebase impide restaurar', () async {
      configureConventionalB();

      secondary.onValidate = (expectedUserId) async {
        snapshot = const AccountSessionPersistenceSnapshot(
          active: null,
          primary: null,
          secondary: null,
        );

        return true;
      };

      final result = await assessment.evaluate();

      expect(result.decision, AccountSessionResumeDecision.requireSignIn);
      expect(result.hasConventionalCandidate, isFalse);
    });

    test('cambiar vinculacion durante Firebase bloquea', () async {
      configureLinkedA();

      primary.onValidate = (expectedUserId) async {
        binding = const BiometricBindingUnavailable();
        return true;
      };

      final result = await assessment.evaluate();

      expect(result.decision, AccountSessionResumeDecision.denyAccess);
      expect(result.requiresLinkedProof, isFalse);
    });

    test('cambiar UID durante Firebase impide continuar', () async {
      configureConventionalB();

      secondary.onValidate = (expectedUserId) async {
        secondary.currentUserId = 'uid-c';
        return true;
      };

      final result = await assessment.evaluate();

      expect(result.decision, AccountSessionResumeDecision.requireSignIn);
      expect(result.hasConventionalCandidate, isFalse);
    });

    test('alterar el registro durante Firebase invalida candidato', () async {
      configureConventionalB();

      secondary.onValidate = (expectedUserId) async {
        final changedStart = start.add(const Duration(seconds: 1));

        snapshot = AccountSessionPersistenceSnapshot(
          active: checkpoint(FirebaseAccountSlot.secondary, 'uid-b'),
          primary: record('uid-a'),
          secondary: record(
            'uid-b',
            startedAt: changedStart,
            lastActivityAt: changedStart,
          ),
        );

        return true;
      };

      final result = await assessment.evaluate();

      expect(result.decision, AccountSessionResumeDecision.requireSignIn);
      expect(result.hasConventionalCandidate, isFalse);
    });

    test('expirar durante Firebase impide continuar', () async {
      configureConventionalB();

      secondary.onValidate = (expectedUserId) async {
        now = start.add(SessionTimeoutPolicy.absolute);
        return true;
      };

      final result = await assessment.evaluate();

      expect(result.decision, AccountSessionResumeDecision.requireSignIn);
      expect(result.record, isNull);
    });

    test('un error de Firebase impide restaurar', () async {
      configureConventionalB();

      secondary.onValidate = (expectedUserId) async {
        throw StateError('Firebase no disponible.');
      };

      final result = await assessment.evaluate();

      expect(result.decision, AccountSessionResumeDecision.denyAccess);
      expect(result.hasConventionalCandidate, isFalse);
    });
  });
}
