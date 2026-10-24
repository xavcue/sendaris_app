import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/account_biometric_access_coordinator.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/biometric_vault_gateway.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';

final class _FakeIdentitySource implements AccountIdentitySource {
  _FakeIdentitySource(this._userId);

  final StreamController<String?> _changes =
      StreamController<String?>.broadcast(sync: true);

  String? _userId;

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

final class _FakeSessionVerifier implements AccountFirebaseSessionVerifier {
  _FakeSessionVerifier(this.userId);

  String? userId;
  bool valid = true;
  int validationCalls = 0;

  Future<bool> Function(String)? onValidate;

  @override
  String? get currentUserId => userId;

  @override
  Future<bool> validate({required String expectedUserId}) async {
    validationCalls++;

    final action = onValidate;

    if (action != null) {
      return action(expectedUserId);
    }

    return valid && userId == expectedUserId;
  }
}

final class _FakeBiometricGateway implements BiometricVaultGateway {
  BiometricBindingState binding = BiometricBindingEnabled(userId: 'uid-a');

  BiometricVaultOutcome outcome = BiometricVaultOutcome.verified;

  int readCalls = 0;
  int unlockCalls = 0;

  Future<BiometricVaultOutcome> Function(String)? onUnlock;

  bool throwOnRead = false;

  @override
  Future<BiometricBindingState> readBinding() async {
    readCalls++;

    if (throwOnRead) {
      throw StateError('Native vault unavailable');
    }

    return binding;
  }

  @override
  Future<BiometricVaultOutcome> unlock({required String expectedUserId}) async {
    unlockCalls++;

    final action = onUnlock;

    if (action != null) {
      return action(expectedUserId);
    }

    return outcome;
  }

  @override
  Future<BiometricVaultOutcome> enroll({required String userId}) async {
    return BiometricVaultOutcome.denied;
  }

  @override
  Future<bool> clearBinding() async => false;
}

void main() {
  late _FakeIdentitySource primaryIdentity;
  late _FakeIdentitySource secondaryIdentity;

  late _FakeSessionVerifier primarySession;
  late _FakeSessionVerifier secondarySession;

  late _FakeBiometricGateway gateway;

  late AccountBiometricAccessCoordinator coordinator;

  setUp(() {
    primaryIdentity = _FakeIdentitySource('uid-a');
    secondaryIdentity = _FakeIdentitySource('uid-b');

    primarySession = _FakeSessionVerifier('uid-a');
    secondarySession = _FakeSessionVerifier('uid-b');

    gateway = _FakeBiometricGateway();

    coordinator = AccountBiometricAccessCoordinator(
      selection: AccountSessionSelectionController(
        primary: primaryIdentity,
        secondary: secondaryIdentity,
      ),
      gateway: gateway,
      primarySession: primarySession,
      secondarySession: secondarySession,
    );
  });

  tearDown(() async {
    coordinator.dispose();

    await primaryIdentity.dispose();
    await secondaryIdentity.dispose();
  });

  Future<bool> unlockPrimary() {
    return coordinator.unlockLinkedAccount(slot: FirebaseAccountSlot.primary);
  }

  Future<bool> unlockSecondary() {
    return coordinator.unlockLinkedAccount(slot: FirebaseAccountSlot.secondary);
  }

  group('AccountBiometricAccessCoordinator', () {
    test('inicia sin conceder acceso privado', () {
      expect(coordinator.privateAccessGranted, isFalse);
      expect(coordinator.selectedSlot, isNull);
      expect(coordinator.selectedUserId, isNull);
    });

    test('autoriza A tras biometría y validación Firebase', () async {
      expect(await unlockPrimary(), isTrue);

      expect(coordinator.privateAccessGranted, isTrue);
      expect(coordinator.selectedSlot, FirebaseAccountSlot.primary);
      expect(coordinator.selectedUserId, 'uid-a');

      expect(gateway.unlockCalls, 1);
      expect(primarySession.validationCalls, 1);
    });

    test('autoriza B cuando su UID está vinculado', () async {
      gateway.binding = BiometricBindingEnabled(userId: 'uid-b');

      expect(await unlockSecondary(), isTrue);

      expect(coordinator.privateAccessGranted, isTrue);
      expect(coordinator.selectedSlot, FirebaseAccountSlot.secondary);
      expect(coordinator.selectedUserId, 'uid-b');
    });

    test('rechaza B cuando la huella pertenece a A', () async {
      expect(await unlockSecondary(), isFalse);

      expect(coordinator.privateAccessGranted, isFalse);
      expect(gateway.unlockCalls, 0);
      expect(secondarySession.validationCalls, 0);
    });

    test('rechaza una vinculación desactivada', () async {
      gateway.binding = const BiometricBindingDisabled();

      expect(await unlockPrimary(), isFalse);

      expect(coordinator.privateAccessGranted, isFalse);
      expect(gateway.unlockCalls, 0);
    });

    test('rechaza un estado biométrico ilegible', () async {
      gateway.binding = const BiometricBindingUnavailable();

      expect(await unlockPrimary(), isFalse);

      expect(coordinator.privateAccessGranted, isFalse);
      expect(gateway.unlockCalls, 0);
    });

    test('rechaza errores de lectura del almacén', () async {
      gateway.throwOnRead = true;

      expect(await unlockPrimary(), isFalse);

      expect(coordinator.privateAccessGranted, isFalse);
    });

    test('una huella cancelada no autoriza acceso', () async {
      gateway.outcome = BiometricVaultOutcome.cancelled;

      expect(await unlockPrimary(), isFalse);

      expect(coordinator.privateAccessGranted, isFalse);
      expect(primarySession.validationCalls, 0);
    });

    test('una huella denegada no autoriza acceso', () async {
      gateway.outcome = BiometricVaultOutcome.denied;

      expect(await unlockPrimary(), isFalse);

      expect(coordinator.privateAccessGranted, isFalse);
      expect(primarySession.validationCalls, 0);
    });

    test('la biometría no disponible impide el acceso', () async {
      gateway.outcome = BiometricVaultOutcome.unavailable;

      expect(await unlockPrimary(), isFalse);

      expect(coordinator.privateAccessGranted, isFalse);
    });

    test('rechaza una sesión Firebase inválida', () async {
      primarySession.valid = false;

      expect(await unlockPrimary(), isFalse);

      expect(gateway.unlockCalls, 1);
      expect(primarySession.validationCalls, 1);
      expect(coordinator.privateAccessGranted, isFalse);
    });

    test('rechaza un cambio de UID durante la huella', () async {
      gateway.onUnlock = (expectedUserId) async {
        expect(expectedUserId, 'uid-a');

        primarySession.userId = 'uid-c';
        primaryIdentity.changeTo('uid-c');

        return BiometricVaultOutcome.verified;
      };

      expect(await unlockPrimary(), isFalse);

      expect(coordinator.privateAccessGranted, isFalse);
      expect(primarySession.validationCalls, 0);
    });

    test('rechaza una verificación antigua tras A -> B -> A', () async {
      final pending = Completer<BiometricVaultOutcome>();

      gateway.onUnlock = (_) => pending.future;

      final attempt = unlockPrimary();

      await Future<void>.delayed(Duration.zero);

      primaryIdentity.changeTo('uid-c');
      primaryIdentity.changeTo('uid-a');

      pending.complete(BiometricVaultOutcome.verified);

      expect(await attempt, isFalse);
      expect(coordinator.privateAccessGranted, isFalse);
    });

    test('lock invalida una comprobación pendiente', () async {
      final pending = Completer<BiometricVaultOutcome>();

      gateway.onUnlock = (_) => pending.future;

      final attempt = unlockPrimary();

      await Future<void>.delayed(Duration.zero);

      coordinator.lock();

      pending.complete(BiometricVaultOutcome.verified);

      expect(await attempt, isFalse);
      expect(coordinator.privateAccessGranted, isFalse);
    });

    test('cambiar de A a B revoca A antes de verificar B', () async {
      expect(await unlockPrimary(), isTrue);

      gateway.binding = BiometricBindingEnabled(userId: 'uid-b');

      final pending = Completer<BiometricVaultOutcome>();

      gateway.onUnlock = (_) => pending.future;

      final switching = unlockSecondary();

      expect(coordinator.privateAccessGranted, isFalse);
      expect(coordinator.selectedSlot, isNull);

      pending.complete(BiometricVaultOutcome.verified);

      expect(await switching, isTrue);

      expect(coordinator.selectedSlot, FirebaseAccountSlot.secondary);
      expect(coordinator.selectedUserId, 'uid-b');
    });

    test('no recupera automáticamente el permiso después '
        'de bloquear', () async {
      expect(await unlockPrimary(), isTrue);

      coordinator.lock();

      expect(coordinator.privateAccessGranted, isFalse);
      expect(coordinator.selectedSlot, isNull);
      expect(coordinator.selectedUserId, isNull);

      // La sesión Firebase se conserva, pero el acceso
      // privado continúa bloqueado.
      expect(primarySession.currentUserId, 'uid-a');
      expect(secondarySession.currentUserId, 'uid-b');
    });
  });
}
