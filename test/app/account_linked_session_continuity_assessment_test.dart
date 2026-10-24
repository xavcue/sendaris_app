import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_active_session_checkpoint.dart';
import 'package:sendaris/app/session/account_biometric_access_coordinator.dart';
import 'package:sendaris/app/session/account_linked_session_continuity_assessment.dart';
import 'package:sendaris/app/session/account_session_persistence_journal.dart';
import 'package:sendaris/app/session/account_session_startup_assessment.dart';
import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';

final class _FakeFirebaseSession implements AccountFirebaseSessionVerifier {
  _FakeFirebaseSession(this.currentUserId);

  @override
  String? currentUserId;

  int validationCalls = 0;
  bool accepted = true;

  @override
  Future<bool> validate({required String expectedUserId}) async {
    validationCalls++;

    return accepted && currentUserId == expectedUserId;
  }
}

final class _FakeContinuityProof implements AccountLinkedContinuityProof {
  bool accepted = true;
  bool throwOnVerify = false;

  int verificationCalls = 0;

  FirebaseAccountSlot? receivedSlot;
  String? receivedUserId;
  DateTime? receivedStartedAt;

  Future<void> Function()? beforeResult;

  @override
  Future<bool> verify({
    required FirebaseAccountSlot slot,
    required String expectedUserId,
    required DateTime sessionStartedAt,
  }) async {
    verificationCalls++;

    receivedSlot = slot;
    receivedUserId = expectedUserId;
    receivedStartedAt = sessionStartedAt;

    final callback = beforeResult;

    if (callback != null) {
      await callback();
    }

    if (throwOnVerify) {
      throw StateError('Credencial nativa no disponible.');
    }

    return accepted;
  }
}

void main() {
  final start = DateTime.utc(2026, 10, 22, 12);

  late DateTime now;
  late _FakeFirebaseSession primary;
  late _FakeFirebaseSession secondary;
  late _FakeContinuityProof proof;

  late AccountSessionPersistenceSnapshot snapshot;
  late BiometricBindingState binding;

  late AccountSessionStartupAssessment startup;
  late AccountLinkedSessionContinuityAssessment continuity;

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

  void configureA() {
    primary.currentUserId = 'uid-a';
    secondary.currentUserId = null;

    binding = const BiometricBindingEnabled(userId: 'uid-a');

    snapshot = AccountSessionPersistenceSnapshot(
      active: checkpoint(FirebaseAccountSlot.primary, 'uid-a'),
      primary: record('uid-a'),
      secondary: null,
    );
  }

  void configureBWithA() {
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
    proof = _FakeContinuityProof();

    binding = const BiometricBindingDisabled();

    snapshot = const AccountSessionPersistenceSnapshot(
      active: null,
      primary: null,
      secondary: null,
    );

    startup = AccountSessionStartupAssessment(
      readSnapshot: () async => snapshot,
      readBinding: () async => binding,
      primarySession: primary,
      secondarySession: secondary,
      clock: () => now,
    );

    continuity = AccountLinkedSessionContinuityAssessment(
      startup: startup,
      proof: proof,
      clock: () => now,
    );
  });

  group('AUTH-03 B8.10B.10C.1 - Continuidad de A', () {
    test('sin sesion almacenada no existe candidato', () async {
      final result = await continuity.evaluate();

      expect(result, isNull);
      expect(proof.verificationCalls, 0);
    });

    test('B convencional no puede utilizar la prueba de A', () async {
      configureBWithA();

      final result = await continuity.evaluate();

      expect(result, isNull);
      expect(proof.verificationCalls, 0);
    });

    test('A exige prueba nativa y conserva el inicio original', () async {
      configureA();

      final result = await continuity.evaluate();

      expect(result, isNotNull);
      expect(result!.slot, FirebaseAccountSlot.primary);
      expect(result.userId, 'uid-a');
      expect(result.record.startedAt, start);

      expect(proof.verificationCalls, 1);
      expect(proof.receivedSlot, FirebaseAccountSlot.primary);
      expect(proof.receivedUserId, 'uid-a');
      expect(proof.receivedStartedAt, start);

      // El evaluador consulta Firebase antes y
      // despues de la verificacion nativa.
      expect(primary.validationCalls, 2);
      expect(secondary.validationCalls, 0);
    });

    test('prueba nativa rechazada impide continuar', () async {
      configureA();
      proof.accepted = false;

      final result = await continuity.evaluate();

      expect(result, isNull);
      expect(proof.verificationCalls, 1);
    });

    test('fallo del servicio nativo no autoriza A', () async {
      configureA();
      proof.throwOnVerify = true;

      final result = await continuity.evaluate();

      expect(result, isNull);
      expect(proof.verificationCalls, 1);
    });

    test('registro vencido no utiliza la prueba nativa', () async {
      configureA();

      now = start.add(SessionTimeoutPolicy.absolute);

      final result = await continuity.evaluate();

      expect(result, isNull);
      expect(proof.verificationCalls, 0);
    });

    test('UID de Firebase incorrecto impide continuar', () async {
      configureA();

      primary.currentUserId = 'uid-c';

      final result = await continuity.evaluate();

      expect(result, isNull);
      expect(proof.verificationCalls, 0);
    });

    test('vinculacion ilegible impide verificar A', () async {
      configureA();

      binding = const BiometricBindingUnavailable();

      final result = await continuity.evaluate();

      expect(result, isNull);
      expect(proof.verificationCalls, 0);
    });

    test('cierre manual durante la prueba invalida A', () async {
      configureA();

      proof.beforeResult = () async {
        snapshot = const AccountSessionPersistenceSnapshot(
          active: null,
          primary: null,
          secondary: null,
        );
      };

      final result = await continuity.evaluate();

      expect(result, isNull);
      expect(proof.verificationCalls, 1);
    });

    test('cambio de UID durante la prueba invalida A', () async {
      configureA();

      proof.beforeResult = () async {
        primary.currentUserId = 'uid-c';
      };

      final result = await continuity.evaluate();

      expect(result, isNull);
    });

    test('desactivacion biometrica durante la prueba invalida A', () async {
      configureA();

      proof.beforeResult = () async {
        binding = const BiometricBindingDisabled();
      };

      final result = await continuity.evaluate();

      expect(result, isNull);
    });

    test('sustituir el inicio original invalida el candidato', () async {
      configureA();

      proof.beforeResult = () async {
        final changed = start.add(const Duration(seconds: 1));

        snapshot = AccountSessionPersistenceSnapshot(
          active: checkpoint(FirebaseAccountSlot.primary, 'uid-a'),
          primary: record('uid-a', startedAt: changed, lastActivityAt: changed),
          secondary: null,
        );
      };

      final result = await continuity.evaluate();

      expect(result, isNull);
    });

    test(
      'cambiar la ultima actividad durante la prueba exige reevaluacion',
      () async {
        configureA();

        proof.beforeResult = () async {
          final activity = start.add(const Duration(minutes: 5));

          snapshot = AccountSessionPersistenceSnapshot(
            active: checkpoint(FirebaseAccountSlot.primary, 'uid-a'),
            primary: record('uid-a', lastActivityAt: activity),
            secondary: null,
          );
        };

        final result = await continuity.evaluate();

        expect(result, isNull);
      },
    );

    test('vencimiento mientras verifica impide continuar', () async {
      configureA();

      proof.beforeResult = () async {
        now = start.add(SessionTimeoutPolicy.absolute);
      };

      final result = await continuity.evaluate();

      expect(result, isNull);
    });

    test('segundo plano vigente conserva las fechas originales', () async {
      configureA();

      final background = start.add(const Duration(minutes: 5));

      snapshot = AccountSessionPersistenceSnapshot(
        active: checkpoint(FirebaseAccountSlot.primary, 'uid-a'),
        primary: record('uid-a', backgroundAt: background),
        secondary: null,
      );

      final result = await continuity.evaluate();

      expect(result, isNotNull);
      expect(result!.record.backgroundAt, background);
      expect(result.record.startedAt, start);
    });

    test('segundo plano vencido impide utilizar credencial', () async {
      configureA();

      now = start.add(
        SessionTimeoutPolicy.background + const Duration(minutes: 1),
      );

      snapshot = AccountSessionPersistenceSnapshot(
        active: checkpoint(FirebaseAccountSlot.primary, 'uid-a'),
        primary: record('uid-a', backgroundAt: start),
        secondary: null,
      );

      final result = await continuity.evaluate();

      expect(result, isNull);
      expect(proof.verificationCalls, 0);
    });
  });
}
