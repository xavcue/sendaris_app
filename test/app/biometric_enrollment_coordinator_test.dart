import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/biometric_enrollment_coordinator.dart';
import 'package:sendaris/app/session/biometric_vault_gateway.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';

void main() {
  group('AUTH-03 - Activación biométrica segura', () {
    _Fixture create({
      String? userId = 'uid-a',
      bool emailVerified = true,
      BiometricBindingState binding = const BiometricBindingDisabled(),
    }) {
      final fixture = _Fixture(
        userId: userId,
        emailVerified: emailVerified,
        binding: binding,
      );

      addTearDown(fixture.auth.dispose);

      return fixture;
    }

    test('activa y confirma una vinculación para el UID vigente', () async {
      final fixture = create();

      final result = await fixture.coordinator.enroll();

      expect(result, BiometricEnrollmentResult.enabled);
      expect(fixture.auth.validationCalls, 1);
      expect(fixture.vault.enrollCalls, 1);
      expect(fixture.vault.enrolledUserId, 'uid-a');

      final binding = fixture.vault.binding;

      expect(binding, isA<BiometricBindingEnabled>());
      expect((binding as BiometricBindingEnabled).userId, 'uid-a');
    });

    test('cancelar Android no confirma la activación', () async {
      final fixture = create();

      fixture.vault.outcome = BiometricVaultOutcome.cancelled;

      final result = await fixture.coordinator.enroll();

      expect(result, BiometricEnrollmentResult.cancelled);
      expect(fixture.vault.binding, isA<BiometricBindingDisabled>());
    });

    test('una denegación nativa no activa biometría', () async {
      final fixture = create();

      fixture.vault.outcome = BiometricVaultOutcome.denied;

      final result = await fixture.coordinator.enroll();

      expect(result, BiometricEnrollmentResult.denied);
      expect(fixture.vault.binding, isA<BiometricBindingDisabled>());
    });

    test(
      'una cuenta sin correo verificado no puede activar biometría',
      () async {
        final fixture = create(emailVerified: false);

        final result = await fixture.coordinator.enroll();

        expect(result, BiometricEnrollmentResult.unverifiedEmail);
        expect(fixture.auth.validationCalls, 0);
        expect(fixture.vault.enrollCalls, 0);
      },
    );

    test('una sesión remota inválida impide el enrolamiento', () async {
      final fixture = create();

      fixture.auth.validationResult = false;

      final result = await fixture.coordinator.enroll();

      expect(result, BiometricEnrollmentResult.invalidSession);
      expect(fixture.vault.enrollCalls, 0);
    });

    test('sin autenticación Firebase no se solicita biometría', () async {
      final fixture = create(userId: null);

      final result = await fixture.coordinator.enroll();

      expect(result, BiometricEnrollmentResult.invalidSession);
      expect(fixture.vault.enrollCalls, 0);
    });

    test('una vinculación existente del mismo UID no se reemplaza', () async {
      final fixture = create(
        binding: const BiometricBindingEnabled(userId: 'uid-a'),
      );

      final result = await fixture.coordinator.enroll();

      expect(result, BiometricEnrollmentResult.alreadyBound);
      expect(fixture.vault.enrollCalls, 0);
    });

    test('una vinculación de otra cuenta no se reemplaza', () async {
      final fixture = create(
        binding: const BiometricBindingEnabled(userId: 'uid-b'),
      );

      final result = await fixture.coordinator.enroll();

      expect(result, BiometricEnrollmentResult.bindingMismatch);
      expect(fixture.vault.enrollCalls, 0);
    });

    test('un estado nativo no disponible bloquea el enrolamiento', () async {
      final fixture = create(binding: const BiometricBindingUnavailable());

      final result = await fixture.coordinator.enroll();

      expect(result, BiometricEnrollmentResult.unavailable);
      expect(fixture.vault.enrollCalls, 0);
    });

    test('Android verificado sin persistencia no es éxito', () async {
      final fixture = create();

      fixture.vault.persistOnVerification = false;

      final result = await fixture.coordinator.enroll();

      expect(result, BiometricEnrollmentResult.unavailable);
      expect(fixture.vault.enrollCalls, 1);
      expect(fixture.vault.binding, isA<BiometricBindingDisabled>());
    });

    test('A-B-A durante el desafío nativo invalida el resultado', () async {
      final fixture = create();

      final pending = Completer<BiometricVaultOutcome>();

      fixture.vault.pendingEnrollment = pending;

      final resultFuture = fixture.coordinator.enroll();

      await Future<void>.delayed(Duration.zero);

      expect(fixture.vault.enrollCalls, 1);

      fixture.auth.setUser('uid-b');
      fixture.auth.setUser('uid-a');

      pending.complete(BiometricVaultOutcome.verified);

      final result = await resultFuture;

      expect(result, BiometricEnrollmentResult.identityChanged);
      expect(fixture.auth.currentUserId, 'uid-a');
    });

    test('cerrar Firebase durante la validación invalida el alta', () async {
      final fixture = create();

      final pending = Completer<bool>();

      fixture.auth.validationFuture = pending.future;

      final resultFuture = fixture.coordinator.enroll();

      await Future<void>.delayed(Duration.zero);

      expect(fixture.auth.validationCalls, 1);

      fixture.auth.setUser(null);

      pending.complete(true);

      final result = await resultFuture;

      expect(result, BiometricEnrollmentResult.identityChanged);
      expect(fixture.vault.enrollCalls, 0);
    });
  });
}

final class _Fixture {
  _Fixture({
    required String? userId,
    required bool emailVerified,
    required BiometricBindingState binding,
  }) : auth = _FakeAuth(userId, emailVerified),
       vault = _FakeVault(binding) {
    coordinator = BiometricEnrollmentCoordinator(
      repository: auth,
      gateway: vault,
    );
  }

  final _FakeAuth auth;
  final _FakeVault vault;

  late final BiometricEnrollmentCoordinator coordinator;
}

final class _FakeAuth
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthEmailVerificationRepository,
        AuthSessionValidationRepository {
  _FakeAuth(this._userId, this.emailVerified);

  final StreamController<bool> _authChanges = StreamController<bool>.broadcast(
    sync: true,
  );

  final StreamController<String?> _identityChanges =
      StreamController<String?>.broadcast(sync: true);

  String? _userId;

  bool emailVerified;
  bool validationResult = true;
  Future<bool>? validationFuture;

  int validationCalls = 0;

  @override
  bool get isAuthenticated => _userId != null;

  @override
  String? get currentUserId => _userId;

  @override
  String? get currentUserEmail => 'test@example.com';

  @override
  bool get isCurrentUserEmailVerified => emailVerified;

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
  Future<bool> validateCurrentSession() async {
    validationCalls++;

    final future = validationFuture;

    return future == null ? validationResult : await future;
  }

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
  Future<bool> refreshEmailVerificationStatus() async => emailVerified;

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}

final class _FakeVault implements BiometricVaultGateway {
  _FakeVault(this.binding);

  BiometricBindingState binding;

  BiometricVaultOutcome outcome = BiometricVaultOutcome.verified;
  Completer<BiometricVaultOutcome>? pendingEnrollment;

  bool persistOnVerification = true;

  int enrollCalls = 0;
  String? enrolledUserId;

  @override
  Future<BiometricBindingState> readBinding() async => binding;

  @override
  Future<BiometricVaultOutcome> enroll({required String userId}) async {
    enrollCalls++;
    enrolledUserId = userId;

    final pending = pendingEnrollment;

    final result = pending == null ? outcome : await pending.future;

    if (result == BiometricVaultOutcome.verified && persistOnVerification) {
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
