import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_biometric_access_coordinator.dart';
import 'package:sendaris/app/session/account_linked_session_recovery_coordinator.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/biometric_vault_gateway.dart';

final class _FakeIdentity implements AccountIdentitySource {
  _FakeIdentity(this._userId);

  String? _userId;

  final _changes = StreamController<String?>.broadcast(sync: true);

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

final class _FakeVerifier implements AccountFirebaseSessionVerifier {
  _FakeVerifier(this.identity);

  final _FakeIdentity identity;

  bool valid = true;
  int validationCalls = 0;

  Future<bool> Function()? validation;

  @override
  String? get currentUserId => identity.currentUserId;

  @override
  Future<bool> validate({required String expectedUserId}) async {
    validationCalls++;

    final action = validation;

    final result = action == null ? valid : await action();

    return result && identity.currentUserId == expectedUserId;
  }
}

final class _FakeVault implements BiometricVaultGateway {
  BiometricBindingState binding = const BiometricBindingEnabled(
    userId: 'uid-a',
  );

  int readCalls = 0;
  int unlockCalls = 0;
  int enrollCalls = 0;
  int clearCalls = 0;

  Future<BiometricBindingState> Function()? onRead;

  @override
  Future<BiometricBindingState> readBinding() async {
    readCalls++;

    final reader = onRead;

    if (reader != null) {
      return reader();
    }

    return binding;
  }

  @override
  Future<BiometricVaultOutcome> unlock({required String expectedUserId}) async {
    unlockCalls++;
    return BiometricVaultOutcome.denied;
  }

  @override
  Future<BiometricVaultOutcome> enroll({required String userId}) async {
    enrollCalls++;
    return BiometricVaultOutcome.denied;
  }

  @override
  Future<bool> clearBinding() async {
    clearCalls++;
    return false;
  }
}

void main() {
  late _FakeIdentity accountA;
  late _FakeIdentity otherAccount;

  late _FakeVerifier verifier;
  late _FakeVault vault;

  late AccountLinkedSessionRecoveryCoordinator coordinator;

  setUp(() {
    accountA = _FakeIdentity(null);
    otherAccount = _FakeIdentity(null);

    verifier = _FakeVerifier(accountA);
    vault = _FakeVault();

    coordinator = AccountLinkedSessionRecoveryCoordinator(
      linkedIdentity: accountA,
      otherIdentity: otherAccount,
      linkedSession: verifier,
      gateway: vault,
    );
  });

  tearDown(() async {
    coordinator.dispose();

    await accountA.dispose();
    await otherAccount.dispose();
  });

  Future<AccountLinkedRecoveryResult> recoverA() {
    return coordinator.recover(
      authenticate: () async {
        accountA.changeTo('uid-a');
        return true;
      },
    );
  }

  group('AUTH-03 B7 - Recuperacion de la cuenta vinculada', () {
    test('recupera A con credenciales y valida Firebase', () async {
      final result = await recoverA();

      expect(result, AccountLinkedRecoveryResult.recovered);

      expect(accountA.currentUserId, 'uid-a');
      expect(otherAccount.currentUserId, isNull);

      expect(verifier.validationCalls, 1);
      expect(vault.readCalls, 2);

      expect(vault.unlockCalls, 0);
      expect(vault.enrollCalls, 0);
      expect(vault.clearCalls, 0);
    });

    test('rechaza una cuenta B aunque sus credenciales sean validas', () async {
      final result = await coordinator.recover(
        authenticate: () async {
          accountA.changeTo('uid-b');
          return true;
        },
      );

      expect(result, AccountLinkedRecoveryResult.identityChanged);

      expect(verifier.validationCalls, 0);
      expect(vault.clearCalls, 0);

      // Una cuenta equivocada no obtiene autorizacion.
      // Su limpieza se coordinara con el contexto reservado
      // antes de permitir otro intento.
      expect(accountA.currentUserId, 'uid-b');
    });

    test('no utiliza el otro contexto si tiene una sesion', () async {
      otherAccount.changeTo('uid-b');

      var authenticationCalled = false;

      final result = await coordinator.recover(
        authenticate: () async {
          authenticationCalled = true;
          return true;
        },
      );

      expect(result, AccountLinkedRecoveryResult.otherContextOccupied);

      expect(authenticationCalled, isFalse);
      expect(accountA.currentUserId, isNull);
      expect(otherAccount.currentUserId, 'uid-b');

      expect(vault.clearCalls, 0);
    });

    test('rechaza una vinculacion ilegible', () async {
      vault.binding = const BiometricBindingUnavailable();

      var authenticationCalled = false;

      final result = await coordinator.recover(
        authenticate: () async {
          authenticationCalled = true;
          return true;
        },
      );

      expect(result, AccountLinkedRecoveryResult.bindingUnavailable);

      expect(authenticationCalled, isFalse);
      expect(accountA.currentUserId, isNull);
    });

    test('rechaza que la vinculacion cambie durante Firebase', () async {
      verifier.validation = () async {
        vault.binding = const BiometricBindingDisabled();
        return true;
      };

      final result = await recoverA();

      expect(result, AccountLinkedRecoveryResult.bindingChanged);

      expect(accountA.currentUserId, 'uid-a');
      expect(vault.clearCalls, 0);
    });

    test('rechaza una sesion Firebase no verificada', () async {
      verifier.valid = false;

      final result = await recoverA();

      expect(result, AccountLinkedRecoveryResult.sessionInvalid);

      expect(verifier.validationCalls, 1);
      expect(vault.clearCalls, 0);
    });

    test('cancelar credenciales no crea una sesion', () async {
      final result = await coordinator.recover(authenticate: () async => false);

      expect(result, AccountLinkedRecoveryResult.cancelled);

      expect(accountA.currentUserId, isNull);
      expect(verifier.validationCalls, 0);
      expect(vault.clearCalls, 0);
    });

    test('bloquea operaciones de recuperacion simultaneas', () async {
      final pending = Completer<bool>();

      final first = coordinator.recover(authenticate: () => pending.future);

      // Permitir que termine la lectura inicial del vault.
      await Future<void>.delayed(Duration.zero);

      expect(coordinator.isBusy, isTrue);

      var secondCalled = false;

      final second = await coordinator.recover(
        authenticate: () async {
          secondCalled = true;
          return true;
        },
      );

      expect(second, AccountLinkedRecoveryResult.busy);
      expect(secondCalled, isFalse);

      accountA.changeTo('uid-a');
      pending.complete(true);

      expect(await first, AccountLinkedRecoveryResult.recovered);

      expect(coordinator.isBusy, isFalse);
    });

    test('una secuencia A-B-A invalida la recuperacion', () async {
      final pending = Completer<bool>();

      final recovery = coordinator.recover(authenticate: () => pending.future);

      await Future<void>.delayed(Duration.zero);

      accountA.changeTo('uid-a');
      accountA.changeTo('uid-b');
      accountA.changeTo('uid-a');

      pending.complete(true);

      expect(await recovery, AccountLinkedRecoveryResult.identityChanged);

      expect(verifier.validationCalls, 0);
      expect(vault.clearCalls, 0);
    });

    test('cambiar la otra cuenta invalida el intento', () async {
      final pending = Completer<bool>();

      final recovery = coordinator.recover(authenticate: () => pending.future);

      await Future<void>.delayed(Duration.zero);

      otherAccount.changeTo('uid-b');
      otherAccount.changeTo(null);

      accountA.changeTo('uid-a');
      pending.complete(true);

      expect(await recovery, AccountLinkedRecoveryResult.identityChanged);

      expect(verifier.validationCalls, 0);
    });

    test('dispose impide aceptar una autenticacion tardia', () async {
      final pending = Completer<bool>();

      final recovery = coordinator.recover(authenticate: () => pending.future);

      await Future<void>.delayed(Duration.zero);

      coordinator.dispose();

      accountA.changeTo('uid-a');
      pending.complete(true);

      expect(await recovery, AccountLinkedRecoveryResult.identityChanged);

      expect(verifier.validationCalls, 0);
      expect(vault.clearCalls, 0);
    });
  });
}
