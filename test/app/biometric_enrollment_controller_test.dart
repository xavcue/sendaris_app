import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/biometric_enrollment_controller.dart';
import 'package:sendaris/app/session/biometric_enrollment_coordinator.dart';
import 'package:sendaris/app/session/biometric_vault_gateway.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';

void main() {
  group('AUTH-03 - Control de activación biométrica', () {
    test('una activación completada comunica la reevaluación', () async {
      final fixture = _Fixture();

      final result = await fixture.controller.activate();

      expect(result, BiometricEnrollmentResult.enabled);
      expect(fixture.controller.lastResult, result);
      expect(fixture.controller.isBusy, isFalse);

      expect(fixture.vault.enrollCalls, 1);

      expect(fixture.finishedResults, <BiometricEnrollmentResult>[
        BiometricEnrollmentResult.enabled,
      ]);

      await fixture.dispose();
    });

    test('dos solicitudes simultáneas comparten una operación', () async {
      final fixture = _Fixture();

      final pending = Completer<BiometricVaultOutcome>();
      fixture.vault.pendingEnrollment = pending;

      final first = fixture.controller.activate();
      final second = fixture.controller.activate();

      expect(identical(first, second), isTrue);
      expect(fixture.controller.isBusy, isTrue);

      await Future<void>.delayed(Duration.zero);

      expect(fixture.vault.enrollCalls, 1);

      pending.complete(BiometricVaultOutcome.verified);

      expect(await first, BiometricEnrollmentResult.enabled);
      expect(await second, BiometricEnrollmentResult.enabled);

      expect(fixture.finishedResults.length, 1);
      expect(fixture.controller.isBusy, isFalse);

      await fixture.dispose();
    });

    test('una cancelación también comunica la finalización', () async {
      final fixture = _Fixture();

      fixture.vault.outcome = BiometricVaultOutcome.cancelled;

      final result = await fixture.controller.activate();

      expect(result, BiometricEnrollmentResult.cancelled);

      expect(fixture.finishedResults, <BiometricEnrollmentResult>[
        BiometricEnrollmentResult.cancelled,
      ]);

      await fixture.dispose();
    });

    test('A-B-A durante Android exige reevaluar el estado nativo', () async {
      final fixture = _Fixture();

      final pending = Completer<BiometricVaultOutcome>();
      fixture.vault.pendingEnrollment = pending;

      final operation = fixture.controller.activate();

      await Future<void>.delayed(Duration.zero);

      expect(fixture.vault.enrollCalls, 1);

      fixture.auth.setUser('uid-b');
      fixture.auth.setUser('uid-a');

      pending.complete(BiometricVaultOutcome.verified);

      final result = await operation;

      expect(result, BiometricEnrollmentResult.identityChanged);

      expect(fixture.finishedResults, <BiometricEnrollmentResult>[
        BiometricEnrollmentResult.identityChanged,
      ]);

      await fixture.dispose();
    });

    test('no notifica a una interfaz después de dispose', () async {
      final fixture = _Fixture();

      final pending = Completer<BiometricVaultOutcome>();
      fixture.vault.pendingEnrollment = pending;

      final operation = fixture.controller.activate();

      await Future<void>.delayed(Duration.zero);

      expect(fixture.vault.enrollCalls, 1);

      fixture.controller.dispose();

      pending.complete(BiometricVaultOutcome.verified);

      await operation;

      expect(fixture.finishedResults, isEmpty);

      await fixture.auth.dispose();
    });
  });
}

final class _Fixture {
  _Fixture() {
    coordinator = BiometricEnrollmentCoordinator(
      repository: auth,
      gateway: vault,
    );

    controller = BiometricEnrollmentController(
      coordinator: coordinator,
      onOperationFinished: finishedResults.add,
    );
  }

  final _FakeAuth auth = _FakeAuth();
  final _FakeVault vault = _FakeVault();

  final List<BiometricEnrollmentResult> finishedResults = [];

  late final BiometricEnrollmentCoordinator coordinator;
  late final BiometricEnrollmentController controller;

  Future<void> dispose() async {
    controller.dispose();
    await auth.dispose();
  }
}

final class _FakeAuth
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthEmailVerificationRepository,
        AuthSessionValidationRepository {
  final StreamController<bool> _authChanges = StreamController<bool>.broadcast(
    sync: true,
  );

  final StreamController<String?> _identityChanges =
      StreamController<String?>.broadcast(sync: true);

  String? _userId = 'uid-a';

  @override
  bool get isAuthenticated => _userId != null;

  @override
  String? get currentUserId => _userId;

  @override
  String? get currentUserEmail => 'test@example.com';

  @override
  bool get isCurrentUserEmailVerified => true;

  @override
  Stream<bool> get authStateChanges => _authChanges.stream;

  @override
  Stream<String?> get userIdChanges => _identityChanges.stream;

  void setUser(String? userId) {
    _userId = userId;

    _identityChanges.add(userId);
    _authChanges.add(userId != null);
  }

  @override
  Future<bool> validateCurrentSession() async => true;

  @override
  Future<void> signIn({required String email, required String password}) async {
    setUser('uid-a');
  }

  @override
  Future<void> signOut() async {
    setUser(null);
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> refreshEmailVerificationStatus() async => true;

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}

final class _FakeVault implements BiometricVaultGateway {
  BiometricBindingState binding = const BiometricBindingDisabled();

  BiometricVaultOutcome outcome = BiometricVaultOutcome.verified;

  Completer<BiometricVaultOutcome>? pendingEnrollment;

  int enrollCalls = 0;

  @override
  Future<BiometricBindingState> readBinding() async => binding;

  @override
  Future<BiometricVaultOutcome> enroll({required String userId}) async {
    enrollCalls++;

    final pending = pendingEnrollment;

    final result = pending == null ? outcome : await pending.future;

    if (result == BiometricVaultOutcome.verified) {
      binding = BiometricBindingEnabled(userId: userId);
    }

    return result;
  }

  @override
  Future<BiometricVaultOutcome> unlock({required String expectedUserId}) async {
    return BiometricVaultOutcome.denied;
  }

  @override
  Future<bool> clearBinding() async {
    binding = const BiometricBindingDisabled();
    return true;
  }
}
