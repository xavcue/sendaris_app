import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_active_session_checkpoint.dart';
import 'package:sendaris/app/session/account_biometric_access_coordinator.dart';
import 'package:sendaris/app/session/account_conventional_session_restore_coordinator.dart';
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

  int validationCalls = 0;
  bool accepted = true;

  Future<bool> Function(String expectedUserId)? onValidate;

  @override
  String? get currentUserId => identity.currentUserId;

  @override
  Future<bool> validate({required String expectedUserId}) async {
    validationCalls++;

    final callback = onValidate;

    if (callback != null) {
      return callback(expectedUserId);
    }

    return accepted && identity.currentUserId == expectedUserId;
  }
}

void main() {
  final start = DateTime.utc(2026, 10, 22, 12);

  late DateTime now;

  late _Identity identityA;
  late _Identity identityB;

  late _FirebaseVerifier primary;
  late _FirebaseVerifier secondary;

  late AccountSessionSelectionController selection;

  late AccountSessionPersistenceSnapshot snapshot;
  late BiometricBindingState binding;

  late AccountSessionStartupAssessment assessment;
  late AccountConventionalSessionRestoreCoordinator restore;

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

  AccountSessionPersistenceSnapshot withRecords({
    required FirebaseAccountSlot activeSlot,
    required String activeUserId,
    SessionTimeoutRecord? primaryRecord,
    SessionTimeoutRecord? secondaryRecord,
  }) {
    return AccountSessionPersistenceSnapshot(
      active: AccountActiveSessionCheckpoint(
        slot: activeSlot,
        userId: activeUserId,
      ),
      primary: primaryRecord,
      secondary: secondaryRecord,
    );
  }

  void configureBPrimary() {
    identityA.changeTo('uid-b');
    identityB.changeTo(null);

    binding = const BiometricBindingDisabled();

    snapshot = withRecords(
      activeSlot: FirebaseAccountSlot.primary,
      activeUserId: 'uid-b',
      primaryRecord: record('uid-b'),
    );
  }

  void configureBSecondary() {
    identityA.changeTo('uid-a');
    identityB.changeTo('uid-b');

    binding = const BiometricBindingEnabled(userId: 'uid-a');

    snapshot = withRecords(
      activeSlot: FirebaseAccountSlot.secondary,
      activeUserId: 'uid-b',
      primaryRecord: record('uid-a'),
      secondaryRecord: record('uid-b'),
    );
  }

  void configureLinkedA() {
    identityA.changeTo('uid-a');
    identityB.changeTo(null);

    binding = const BiometricBindingEnabled(userId: 'uid-a');

    snapshot = withRecords(
      activeSlot: FirebaseAccountSlot.primary,
      activeUserId: 'uid-a',
      primaryRecord: record('uid-a'),
    );
  }

  setUp(() {
    now = start.add(const Duration(minutes: 10));

    identityA = _Identity(null);
    identityB = _Identity(null);

    primary = _FirebaseVerifier(identityA);
    secondary = _FirebaseVerifier(identityB);

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

    assessment = AccountSessionStartupAssessment(
      readSnapshot: () async => snapshot,
      readBinding: () async => binding,
      primarySession: primary,
      secondarySession: secondary,
      clock: () => now,
    );

    restore = AccountConventionalSessionRestoreCoordinator(
      selection: selection,
      assessment: assessment,
      clock: () => now,
    );
  });

  tearDown(() async {
    selection.dispose();

    await identityA.dispose();
    await identityB.dispose();
  });

  group('AUTH-03 B8.10B.10B.1 - Restauracion de B', () {
    test('sin checkpoint no autoriza ninguna cuenta', () async {
      final result = await restore.restoreConventional();

      expect(result, isNull);
      expect(selection.value, isFalse);
      expect(primary.validationCalls, 0);
      expect(secondary.validationCalls, 0);
    });

    test('autoriza B en PRIMARY sin vinculacion biometrica', () async {
      configureBPrimary();

      final result = await restore.restoreConventional();

      expect(result, isNotNull);
      expect(result!.slot, FirebaseAccountSlot.primary);
      expect(result.userId, 'uid-b');
      expect(result.record.startedAt, start);

      expect(selection.value, isTrue);
      expect(selection.selectedSlot, FirebaseAccountSlot.primary);
      expect(selection.selectedUserId, 'uid-b');

      // Una verificacion inicial y otra dentro de
      // AccountSessionSelectionController.select().
      expect(primary.validationCalls, 2);
      expect(secondary.validationCalls, 0);
    });

    test('autoriza solo B en SECONDARY con A vinculada', () async {
      configureBSecondary();

      final result = await restore.restoreConventional();

      expect(result, isNotNull);
      expect(result!.slot, FirebaseAccountSlot.secondary);
      expect(result.userId, 'uid-b');

      expect(selection.value, isTrue);
      expect(selection.selectedSlot, FirebaseAccountSlot.secondary);
      expect(selection.selectedUserId, 'uid-b');

      // La cuenta A existe, pero no fue seleccionada
      // ni utilizada para autorizar B.
      expect(identityA.currentUserId, 'uid-a');
      expect(primary.validationCalls, 0);
      expect(secondary.validationCalls, 2);
    });

    test('nunca convierte la vinculacion de A en acceso', () async {
      configureLinkedA();

      final result = await restore.restoreConventional();

      expect(result, isNull);
      expect(selection.value, isFalse);

      // El evaluador puede reconocer A,
      // pero exige su autorizacion nativa.
      expect(primary.validationCalls, 1);
    });

    test('un UID diferente impide la restauracion', () async {
      configureBSecondary();

      identityB.changeTo('uid-c');

      final result = await restore.restoreConventional();

      expect(result, isNull);
      expect(selection.value, isFalse);
    });

    test('Firebase rechazado no permite seleccionar B', () async {
      configureBSecondary();

      secondary.accepted = false;

      final result = await restore.restoreConventional();

      expect(result, isNull);
      expect(selection.value, isFalse);
    });

    test('registro vencido nunca genera una nueva sesion', () async {
      configureBSecondary();

      now = start.add(SessionTimeoutPolicy.absolute);

      final result = await restore.restoreConventional();

      expect(result, isNull);
      expect(selection.value, isFalse);
      expect(secondary.validationCalls, 0);
    });

    test(
      'un cambio de registro durante la segunda revision se rechaza',
      () async {
        configureBSecondary();

        secondary.onValidate = (expectedUserId) async {
          if (secondary.validationCalls == 2) {
            final changedStart = start.add(const Duration(seconds: 1));

            snapshot = withRecords(
              activeSlot: FirebaseAccountSlot.secondary,
              activeUserId: 'uid-b',
              primaryRecord: record('uid-a'),
              secondaryRecord: record(
                'uid-b',
                startedAt: changedStart,
                lastActivityAt: changedStart,
              ),
            );
          }

          return expectedUserId == 'uid-b';
        };

        final result = await restore.restoreConventional();

        expect(result, isNull);
        expect(selection.value, isFalse);
        expect(secondary.validationCalls, 2);
      },
    );

    test('un cambio de UID durante la segunda revision se rechaza', () async {
      configureBSecondary();

      secondary.onValidate = (expectedUserId) async {
        if (secondary.validationCalls == 2) {
          identityB.changeTo('uid-c');
        }

        return true;
      };

      final result = await restore.restoreConventional();

      expect(result, isNull);
      expect(selection.value, isFalse);
      expect(identityB.currentUserId, 'uid-c');
    });

    test('un bloqueo concurrente cancela la autorizacion', () async {
      configureBSecondary();

      secondary.onValidate = (expectedUserId) async {
        if (secondary.validationCalls == 2) {
          selection.lock();
        }

        return true;
      };

      final result = await restore.restoreConventional();

      expect(result, isNull);
      expect(selection.value, isFalse);
    });

    test('si vence mientras se autoriza no se concede acceso', () async {
      configureBSecondary();

      secondary.onValidate = (expectedUserId) async {
        if (secondary.validationCalls == 2) {
          now = start.add(SessionTimeoutPolicy.absolute);
        }

        return true;
      };

      final result = await restore.restoreConventional();

      expect(result, isNull);
      expect(selection.value, isFalse);
    });

    test('un cambio de vinculacion impide restaurar B', () async {
      configureBSecondary();

      secondary.onValidate = (expectedUserId) async {
        if (secondary.validationCalls == 2) {
          binding = const BiometricBindingDisabled();
        }

        return true;
      };

      final result = await restore.restoreConventional();

      expect(result, isNull);
      expect(selection.value, isFalse);
    });

    test('no sustituye una seleccion privada ya autorizada', () async {
      configureBSecondary();

      final first = await restore.restoreConventional();

      expect(first, isNotNull);
      expect(selection.value, isTrue);

      final validations = secondary.validationCalls;

      final second = await restore.restoreConventional();

      expect(second, isNull);
      expect(selection.value, isTrue);
      expect(selection.selectedUserId, 'uid-b');
      expect(secondary.validationCalls, validations);
    });

    test('un cierre de sesion elimina el permiso restaurado', () async {
      configureBSecondary();

      final result = await restore.restoreConventional();

      expect(result, isNotNull);
      expect(selection.value, isTrue);

      selection.lock();

      expect(selection.value, isFalse);
      expect(selection.selectedUserId, isNull);

      // Ninguna operacion del coordinador vuelve
      // a seleccionar automaticamente la cuenta.
    });
  });
}
