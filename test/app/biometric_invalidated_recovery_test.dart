import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_biometric_access_coordinator.dart';
import 'package:sendaris/app/session/account_biometric_settings_controller.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/biometric_vault_gateway.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/features/settings/presentation/widgets/account_biometric_settings_card.dart';

final class _Identity implements AccountIdentitySource {
  _Identity(this.userId);

  String? userId;

  final StreamController<String?> changes = StreamController<String?>.broadcast(
    sync: true,
  );

  @override
  String? get currentUserId => userId;

  @override
  Stream<String?> get userIdChanges => changes.stream;

  void change(String? value) {
    userId = value;
    changes.add(value);
  }

  Future<void> dispose() => changes.close();
}

final class _Session implements AccountFirebaseSessionVerifier {
  const _Session(this.identity);

  final _Identity identity;

  @override
  String? get currentUserId => identity.currentUserId;

  @override
  Future<bool> validate({required String expectedUserId}) async {
    return identity.currentUserId == expectedUserId;
  }
}

final class _Vault
    implements
        BiometricVaultGateway,
        BiometricUnlinkGateway,
        BiometricInvalidatedRecoveryGateway {
  BiometricBindingState state = const BiometricBindingEnabled(userId: 'uid-a');

  bool invalidated = true;
  int recoveryCalls = 0;

  BiometricVaultOutcome recoveryOutcome = BiometricVaultOutcome.verified;

  @override
  Future<BiometricBindingState> readBinding() async {
    return state;
  }

  @override
  Future<bool> isPermanentlyInvalidated({
    required String expectedUserId,
  }) async {
    return invalidated &&
        state is BiometricBindingEnabled &&
        (state as BiometricBindingEnabled).userId == expectedUserId;
  }

  @override
  Future<BiometricVaultOutcome> recoverInvalidated({
    required String expectedUserId,
  }) async {
    recoveryCalls++;

    if (!invalidated ||
        state is! BiometricBindingEnabled ||
        (state as BiometricBindingEnabled).userId != expectedUserId) {
      return BiometricVaultOutcome.denied;
    }

    if (recoveryOutcome != BiometricVaultOutcome.verified) {
      return recoveryOutcome;
    }

    state = const BiometricBindingDisabled();
    return BiometricVaultOutcome.verified;
  }

  @override
  Future<BiometricVaultOutcome> enroll({required String userId}) async {
    return BiometricVaultOutcome.denied;
  }

  @override
  Future<BiometricVaultOutcome> unlock({required String expectedUserId}) async {
    return BiometricVaultOutcome.denied;
  }

  @override
  Future<BiometricVaultOutcome> deactivate({
    required String expectedUserId,
  }) async {
    return BiometricVaultOutcome.denied;
  }

  @override
  Future<bool> clearBinding() async {
    return false;
  }
}

final class _Fixture {
  _Fixture() : primary = _Identity('uid-a'), secondary = _Identity('uid-b') {
    selection = AccountSessionSelectionController(
      primary: primary,
      secondary: secondary,
    );

    controller = AccountBiometricSettingsController(
      selection: selection,
      primarySession: _Session(primary),
      secondarySession: _Session(secondary),
      gateway: vault,
      unlinkGateway: vault,
      onBindingChanged: (change) async {
        changes.add(change);
        return true;
      },
    );
  }

  final _Identity primary;
  final _Identity secondary;
  final _Vault vault = _Vault();

  final List<AccountBiometricBindingChange> changes = [];

  late final AccountSessionSelectionController selection;
  late final AccountBiometricSettingsController controller;

  Future<void> selectA() async {
    final result = await selection.select(
      slot: FirebaseAccountSlot.primary,
      expectedUserId: 'uid-a',
      verifyAccess: () async => true,
    );

    expect(result, isTrue);
  }

  Future<void> selectB() async {
    final result = await selection.select(
      slot: FirebaseAccountSlot.secondary,
      expectedUserId: 'uid-b',
      verifyAccess: () async => true,
    );

    expect(result, isTrue);
  }

  Future<void> dispose() async {
    controller.dispose();
    selection.dispose();
    await primary.dispose();
    await secondary.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AUTH-03: recuperación biométrica invalidada', () {
    test('sin reautenticación Firebase no elimina la vinculación', () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);

      await fixture.selectA();

      final result = await fixture.controller.recoverInvalidated(
        reauthenticate: () async => false,
      );

      expect(result, AccountBiometricSettingsResult.denied);
      expect(fixture.vault.recoveryCalls, 0);
      expect(fixture.vault.state, isA<BiometricBindingEnabled>());
      expect(fixture.changes, isEmpty);
    });

    test('la cuenta B no puede recuperar la vinculación de A', () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);

      await fixture.selectB();

      final result = await fixture.controller.recoverInvalidated(
        reauthenticate: () async => true,
      );

      expect(result, AccountBiometricSettingsResult.denied);
      expect(fixture.vault.recoveryCalls, 0);
      expect(fixture.vault.state, isA<BiometricBindingEnabled>());
    });

    test('una cancelación no elimina la vinculación anterior', () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);

      await fixture.selectA();

      fixture.vault.recoveryOutcome = BiometricVaultOutcome.cancelled;

      final result = await fixture.controller.recoverInvalidated(
        reauthenticate: () async => true,
      );

      expect(result, AccountBiometricSettingsResult.cancelled);

      expect(fixture.vault.state, isA<BiometricBindingEnabled>());

      expect(fixture.changes, isEmpty);
    });

    test('recuperación válida desvincula A y avisa al coordinador', () async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);

      await fixture.selectA();

      var reauthenticationCalls = 0;

      final result = await fixture.controller.recoverInvalidated(
        reauthenticate: () async {
          reauthenticationCalls++;
          return true;
        },
      );

      expect(reauthenticationCalls, 1);
      expect(fixture.vault.recoveryCalls, 1);
      expect(result, AccountBiometricSettingsResult.deactivated);
      expect(fixture.vault.state, isA<BiometricBindingDisabled>());

      expect(fixture.changes, hasLength(1));
      expect(fixture.changes.single.userId, 'uid-a');
      expect(
        fixture.changes.single.operation,
        AccountBiometricBindingOperation.deactivation,
      );
    });

    test(
      'una identidad diferente durante reautenticación bloquea el intento',
      () async {
        final fixture = _Fixture();
        addTearDown(fixture.dispose);

        await fixture.selectA();

        final result = await fixture.controller.recoverInvalidated(
          reauthenticate: () async {
            fixture.primary.change('uid-otro');
            return true;
          },
        );

        expect(result, AccountBiometricSettingsResult.denied);
        expect(fixture.vault.recoveryCalls, 0);
        expect(fixture.changes, isEmpty);
      },
    );

    testWidgets(
      'Ajustes muestra la recuperación cuando la clave fue invalidada',
      (tester) async {
        final fixture = _Fixture();
        addTearDown(fixture.dispose);

        await fixture.selectA();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AccountBiometricSettingsCard(
                controller: fixture.controller,
                isAccountReady: true,
                reauthenticateForRecovery: () async => true,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('settings-biometric-recover-invalidated')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('settings-biometric-deactivate')),
          findsNothing,
        );

        await tester.tap(
          find.byKey(const Key('settings-biometric-recover-invalidated')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('biometric-recovery-confirmation')),
          findsOneWidget,
        );

        await tester.tap(find.byKey(const Key('biometric-recovery-confirm')));
        await tester.pumpAndSettle();

        expect(fixture.vault.state, isA<BiometricBindingDisabled>());
        expect(
          find.byKey(const Key('settings-biometric-activate')),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox.shrink());
      },
    );

    testWidgets('Ajustes no ofrece recuperación si la clave sigue válida', (
      tester,
    ) async {
      final fixture = _Fixture();
      addTearDown(fixture.dispose);

      await fixture.selectA();
      fixture.vault.invalidated = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AccountBiometricSettingsCard(
              controller: fixture.controller,
              isAccountReady: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settings-biometric-recover-invalidated')),
        findsNothing,
      );

      expect(
        find.byKey(const Key('settings-biometric-deactivate')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('AUTH-03: contrato nativo de recuperación', () {
    const channel = MethodChannel(
      'com.xavcue.sendaris/test_invalidated_recovery',
    );

    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    late AndroidBiometricVaultGateway gateway;

    setUp(() {
      gateway = AndroidBiometricVaultGateway(channel: channel);
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('la consulta de clave invalidada no solicita eliminación', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'checkInvalidated');
        expect(call.arguments, <String, String>{'uid': 'uid-a'});
        return true;
      });

      final result = await gateway.isPermanentlyInvalidated(
        expectedUserId: 'uid-a',
      );

      expect(result, isTrue);
    });

    test('Android debe confirmar UID y almacenamiento desactivado', () async {
      var recovered = false;

      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'readBinding') {
          return recovered
              ? <String, String>{'status': 'disabled'}
              : <String, String>{'status': 'enabled', 'uid': 'uid-a'};
        }

        expect(call.method, 'recoverInvalidated');
        expect(call.arguments, <String, String>{'uid': 'uid-a'});

        recovered = true;

        return <String, String>{'status': 'verified', 'uid': 'uid-a'};
      });

      final result = await gateway.recoverInvalidated(expectedUserId: 'uid-a');

      expect(result, BiometricVaultOutcome.verified);
    });

    test('respuesta de otra cuenta no autoriza recuperación', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'readBinding') {
          return <String, String>{'status': 'enabled', 'uid': 'uid-a'};
        }

        return <String, String>{'status': 'verified', 'uid': 'uid-b'};
      });

      final result = await gateway.recoverInvalidated(expectedUserId: 'uid-a');

      expect(result, BiometricVaultOutcome.denied);
    });
  });
}
