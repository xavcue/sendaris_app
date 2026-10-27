import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_active_session_checkpoint.dart';
import 'package:sendaris/app/session/account_biometric_access_coordinator.dart';
import 'package:sendaris/app/session/account_linked_session_continuity_assessment.dart';
import 'package:sendaris/app/session/account_linked_session_restore_coordinator.dart';
import 'package:sendaris/app/session/account_session_persistence_journal.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/account_session_startup_assessment.dart';
import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';

final class _Identity implements AccountIdentitySource {
  _Identity(this._userId);

  String? _userId;

  final StreamController<String?> _changes =
      StreamController<String?>.broadcast(sync: true);

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> get userIdChanges => _changes.stream;

  void changeTo(String? userId) {
    _userId = userId;
    _changes.add(userId);
  }

  Future<void> dispose() => _changes.close();
}

final class _FirebaseVerifier implements AccountFirebaseSessionVerifier {
  _FirebaseVerifier(this.identity);

  final _Identity identity;

  int calls = 0;
  bool accepted = true;

  @override
  String? get currentUserId => identity.currentUserId;

  @override
  Future<bool> validate({required String expectedUserId}) async {
    calls++;

    return accepted && identity.currentUserId == expectedUserId;
  }
}

final class _ContinuityProof implements AccountLinkedContinuityProof {
  int calls = 0;
  bool accepted = true;

  Future<void> Function(int call)? onVerify;

  @override
  Future<bool> verify({
    required FirebaseAccountSlot slot,
    required String expectedUserId,
    required DateTime sessionStartedAt,
  }) async {
    calls++;

    final callback = onVerify;

    if (callback != null) {
      await callback(calls);
    }

    return accepted &&
        slot == FirebaseAccountSlot.primary &&
        expectedUserId == 'uid-a';
  }
}

void main() {
  final start = DateTime.utc(2026, 10, 22, 12);

  late DateTime now;

  late _Identity identityA;
  late _Identity identityB;

  late _FirebaseVerifier primary;
  late _FirebaseVerifier secondary;
  late _ContinuityProof proof;

  late AccountSessionSelectionController selection;

  late AccountSessionPersistenceSnapshot snapshot;
  late BiometricBindingState binding;

  late AccountLinkedSessionRestoreCoordinator coordinator;

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

  AccountSessionPersistenceSnapshot snapshotFor({
    required FirebaseAccountSlot activeSlot,
    required String activeUid,
    SessionTimeoutRecord? primaryRecord,
    SessionTimeoutRecord? secondaryRecord,
  }) {
    return AccountSessionPersistenceSnapshot(
      active: AccountActiveSessionCheckpoint(
        slot: activeSlot,
        userId: activeUid,
      ),
      primary: primaryRecord,
      secondary: secondaryRecord,
    );
  }

  void configureA() {
    identityA.changeTo('uid-a');
    identityB.changeTo(null);

    binding = const BiometricBindingEnabled(userId: 'uid-a');

    snapshot = snapshotFor(
      activeSlot: FirebaseAccountSlot.primary,
      activeUid: 'uid-a',
      primaryRecord: record('uid-a'),
    );
  }

  void configureBActive() {
    identityA.changeTo('uid-a');
    identityB.changeTo('uid-b');

    binding = const BiometricBindingEnabled(userId: 'uid-a');

    snapshot = snapshotFor(
      activeSlot: FirebaseAccountSlot.secondary,
      activeUid: 'uid-b',
      primaryRecord: record('uid-a'),
      secondaryRecord: record('uid-b'),
    );
  }

  setUp(() {
    now = start.add(const Duration(minutes: 10));

    identityA = _Identity(null);
    identityB = _Identity(null);

    primary = _FirebaseVerifier(identityA);
    secondary = _FirebaseVerifier(identityB);
    proof = _ContinuityProof();

    selection = AccountSessionSelectionController(
      primary: identityA,
      secondary: identityB,
    );

    snapshot = const AccountSessionPersistenceSnapshot(
      active: null,
      primary: null,
      secondary: null,
    );

    binding = const BiometricBindingDisabled();

    final startup = AccountSessionStartupAssessment(
      readSnapshot: () async => snapshot,
      readBinding: () async => binding,
      primarySession: primary,
      secondarySession: secondary,
      clock: () => now,
    );

    final continuity = AccountLinkedSessionContinuityAssessment(
      startup: startup,
      proof: proof,
      clock: () => now,
    );

    coordinator = AccountLinkedSessionRestoreCoordinator(
      selection: selection,
      continuity: continuity,
      linkedSlot: FirebaseAccountSlot.primary,
      clock: () => now,
    );
  });

  tearDown(() async {
    selection.dispose();

    await identityA.dispose();
    await identityB.dispose();
  });

  group('AUTH-03 B8.10B.10C.3A - Restauracion de A', () {
    test('sin checkpoint no se autoriza A', () async {
      final result = await coordinator.restoreLinked();

      expect(result, isNull);
      expect(selection.value, isFalse);
      expect(proof.calls, 0);
    });

    test('autoriza A con prueba nativa y fechas vigentes', () async {
      configureA();

      final result = await coordinator.restoreLinked();

      expect(result, isNotNull);
      expect(result!.slot, FirebaseAccountSlot.primary);
      expect(result.userId, 'uid-a');
      expect(result.record.startedAt, start);

      expect(selection.value, isTrue);
      expect(selection.selectedSlot, FirebaseAccountSlot.primary);
      expect(selection.selectedUserId, 'uid-a');

      // Una evaluacion inicial y otra protegida
      // dentro del selector privado.
      expect(proof.calls, 2);

      // Cada evaluacion de continuidad comprueba
      // Firebase antes y despues de Android.
      expect(primary.calls, 4);
      expect(secondary.calls, 0);
    });

    test('B activa no puede restaurarse como A', () async {
      configureBActive();

      final result = await coordinator.restoreLinked();

      expect(result, isNull);
      expect(selection.value, isFalse);
      expect(proof.calls, 0);
    });

    test('no autoriza sin prueba nativa', () async {
      configureA();
      proof.accepted = false;

      final result = await coordinator.restoreLinked();

      expect(result, isNull);
      expect(selection.value, isFalse);
    });

    test('Firebase rechazada impide restaurar A', () async {
      configureA();
      primary.accepted = false;

      final result = await coordinator.restoreLinked();

      expect(result, isNull);
      expect(selection.value, isFalse);
    });

    test('vinculacion desactivada impide restaurar A', () async {
      configureA();
      binding = const BiometricBindingDisabled();

      final result = await coordinator.restoreLinked();

      expect(result, isNull);
      expect(selection.value, isFalse);
      expect(proof.calls, 0);
    });

    test('una sesion absoluta vencida no se restaura', () async {
      configureA();
      now = start.add(SessionTimeoutPolicy.absolute);

      final result = await coordinator.restoreLinked();

      expect(result, isNull);
      expect(selection.value, isFalse);
    });

    test('segundo plano vencido impide continuar', () async {
      configureA();

      snapshot = snapshotFor(
        activeSlot: FirebaseAccountSlot.primary,
        activeUid: 'uid-a',
        primaryRecord: record('uid-a', backgroundAt: start),
      );

      now = start.add(
        SessionTimeoutPolicy.background + const Duration(minutes: 1),
      );

      final result = await coordinator.restoreLinked();

      expect(result, isNull);
      expect(selection.value, isFalse);
    });

    test('segundo plano vigente mantiene el inicio original', () async {
      configureA();

      final background = start.add(const Duration(minutes: 5));

      snapshot = snapshotFor(
        activeSlot: FirebaseAccountSlot.primary,
        activeUid: 'uid-a',
        primaryRecord: record('uid-a', backgroundAt: background),
      );

      final result = await coordinator.restoreLinked();

      expect(result, isNotNull);
      expect(result!.record.startedAt, start);
      expect(result.record.backgroundAt, background);
      expect(selection.value, isTrue);
    });

    test('cierre concurrente invalida restauracion', () async {
      configureA();

      proof.onVerify = (call) async {
        if (call == 2) {
          snapshot = const AccountSessionPersistenceSnapshot(
            active: null,
            primary: null,
            secondary: null,
          );
        }
      };

      final result = await coordinator.restoreLinked();

      expect(result, isNull);
      expect(selection.value, isFalse);
    });

    test('cambio de UID durante la prueba se rechaza', () async {
      configureA();

      proof.onVerify = (call) async {
        if (call == 2) {
          identityA.changeTo('uid-c');
        }
      };

      final result = await coordinator.restoreLinked();

      expect(result, isNull);
      expect(selection.value, isFalse);
    });

    test('un cambio de fechas durante la prueba se rechaza', () async {
      configureA();

      proof.onVerify = (call) async {
        if (call == 2) {
          final updated = start.add(const Duration(minutes: 1));

          snapshot = snapshotFor(
            activeSlot: FirebaseAccountSlot.primary,
            activeUid: 'uid-a',
            primaryRecord: record('uid-a', lastActivityAt: updated),
          );
        }
      };

      final result = await coordinator.restoreLinked();

      expect(result, isNull);
      expect(selection.value, isFalse);
    });

    test('un bloqueo concurrente cancela la seleccion', () async {
      configureA();

      proof.onVerify = (call) async {
        if (call == 2) {
          selection.lock();
        }
      };

      final result = await coordinator.restoreLinked();

      expect(result, isNull);
      expect(selection.value, isFalse);
    });

    test('vencimiento durante la seleccion impide A', () async {
      configureA();

      proof.onVerify = (call) async {
        if (call == 2) {
          now = start.add(SessionTimeoutPolicy.absolute);
        }
      };

      final result = await coordinator.restoreLinked();

      expect(result, isNull);
      expect(selection.value, isFalse);
    });

    test('no sustituye una autorizacion privada existente', () async {
      configureA();

      final first = await coordinator.restoreLinked();

      expect(first, isNotNull);
      expect(selection.value, isTrue);

      final previousCalls = proof.calls;

      final second = await coordinator.restoreLinked();

      expect(second, isNull);
      expect(selection.value, isTrue);
      expect(selection.selectedUserId, 'uid-a');
      expect(proof.calls, previousCalls);
    });

    test('el cierre manual revoca la seleccion', () async {
      configureA();

      final result = await coordinator.restoreLinked();

      expect(result, isNotNull);
      expect(selection.value, isTrue);

      selection.lock();

      expect(selection.value, isFalse);
      expect(selection.selectedSlot, isNull);
      expect(selection.selectedUserId, isNull);
    });
  });
}
