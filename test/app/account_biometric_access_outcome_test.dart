import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/account_biometric_access_coordinator.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/biometric_vault_gateway.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';

final class _Identity implements AccountIdentitySource {
  _Identity(this._uid);

  // La identidad simulada no cambia durante estas pruebas.
  // Declararla final satisface prefer_final_fields.
  final String? _uid;

  final _changes = StreamController<String?>.broadcast(sync: true);

  @override
  String? get currentUserId => _uid;

  @override
  Stream<String?> get userIdChanges => _changes.stream;

  Future<void> dispose() => _changes.close();
}

final class _Verifier implements AccountFirebaseSessionVerifier {
  _Verifier(this.currentUserId);

  @override
  String? currentUserId;

  bool valid = true;
  int validations = 0;

  @override
  Future<bool> validate({required String expectedUserId}) async {
    validations++;

    return valid && currentUserId == expectedUserId;
  }
}

final class _Vault implements BiometricVaultGateway {
  BiometricVaultOutcome result = BiometricVaultOutcome.verified;

  int unlockCalls = 0;

  @override
  Future<BiometricBindingState> readBinding() async {
    return const BiometricBindingEnabled(userId: 'uid-a');
  }

  @override
  Future<BiometricVaultOutcome> unlock({required String expectedUserId}) async {
    unlockCalls++;

    return result;
  }

  @override
  Future<BiometricVaultOutcome> enroll({required String userId}) async {
    return BiometricVaultOutcome.denied;
  }

  @override
  Future<bool> clearBinding() async => false;
}

void main() {
  late _Identity primary;
  late _Identity secondary;

  late _Verifier primarySession;
  late _Vault vault;

  late AccountBiometricAccessCoordinator coordinator;

  setUp(() {
    primary = _Identity('uid-a');
    secondary = _Identity(null);

    primarySession = _Verifier('uid-a');
    vault = _Vault();

    coordinator = AccountBiometricAccessCoordinator(
      selection: AccountSessionSelectionController(
        primary: primary,
        secondary: secondary,
      ),
      gateway: vault,
      primarySession: primarySession,
      secondarySession: _Verifier(null),
    );
  });

  tearDown(() async {
    coordinator.dispose();

    await primary.dispose();
    await secondary.dispose();
  });

  Future<AccountBiometricAccessOutcome> unlock() {
    return coordinator.unlockLinkedAccountWithOutcome(
      slot: FirebaseAccountSlot.primary,
    );
  }

  test('cancelar no autoriza ni consulta Firebase', () async {
    vault.result = BiometricVaultOutcome.cancelled;

    expect(await unlock(), AccountBiometricAccessOutcome.cancelled);

    expect(coordinator.privateAccessGranted, isFalse);

    expect(primarySession.validations, 0);
  });

  test('denegacion nativa no concede acceso', () async {
    vault.result = BiometricVaultOutcome.denied;

    expect(await unlock(), AccountBiometricAccessOutcome.denied);

    expect(coordinator.privateAccessGranted, isFalse);

    expect(primarySession.validations, 0);
  });

  test('sensor no disponible se informa por separado', () async {
    vault.result = BiometricVaultOutcome.unavailable;

    expect(await unlock(), AccountBiometricAccessOutcome.unavailable);

    expect(coordinator.privateAccessGranted, isFalse);
  });

  test('sesion Firebase invalida no se confunde con huella', () async {
    primarySession.valid = false;

    expect(await unlock(), AccountBiometricAccessOutcome.sessionUnavailable);

    expect(primarySession.validations, 1);

    expect(coordinator.privateAccessGranted, isFalse);
  });

  test('sin identidad Firebase no se invoca Keystore', () async {
    primarySession.currentUserId = null;

    expect(await unlock(), AccountBiometricAccessOutcome.sessionUnavailable);

    expect(vault.unlockCalls, 0);

    expect(coordinator.privateAccessGranted, isFalse);
  });

  test('huella valida y Firebase valido siguen autorizando A', () async {
    expect(await unlock(), AccountBiometricAccessOutcome.granted);

    expect(coordinator.privateAccessGranted, isTrue);

    expect(coordinator.selectedUserId, 'uid-a');
  });

  test('la API booleana anterior conserva su comportamiento', () async {
    vault.result = BiometricVaultOutcome.cancelled;

    expect(
      await coordinator.unlockLinkedAccount(slot: FirebaseAccountSlot.primary),
      isFalse,
    );

    vault.result = BiometricVaultOutcome.verified;

    expect(
      await coordinator.unlockLinkedAccount(slot: FirebaseAccountSlot.primary),
      isTrue,
    );
  });
}
