import 'dart:async';

import 'package:flutter/material.dart';
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
  final changes = StreamController<String?>.broadcast(sync: true);

  @override
  String? get currentUserId => userId;

  @override
  Stream<String?> get userIdChanges => changes.stream;

  void update(String? next) {
    userId = next;
    changes.add(next);
  }

  Future<void> dispose() => changes.close();
}

final class _Session implements AccountFirebaseSessionVerifier {
  const _Session(this.identity);
  final _Identity identity;

  @override
  String? get currentUserId => identity.currentUserId;

  @override
  Future<bool> validate({required String expectedUserId}) async =>
      identity.currentUserId == expectedUserId;
}

final class _Vault implements BiometricVaultGateway {
  BiometricBindingState binding = const BiometricBindingDisabled();
  int enrollCalls = 0;
  int clearCalls = 0;

  @override
  Future<BiometricBindingState> readBinding() async => binding;

  @override
  Future<BiometricVaultOutcome> enroll({required String userId}) async {
    enrollCalls++;
    binding = BiometricBindingEnabled(userId: userId);
    return BiometricVaultOutcome.verified;
  }

  @override
  Future<BiometricVaultOutcome> unlock({
    required String expectedUserId,
  }) async => BiometricVaultOutcome.denied;

  @override
  Future<bool> clearBinding() async {
    clearCalls++;
    return false;
  }
}

final class _Unlink implements BiometricUnlinkGateway {
  const _Unlink(this.vault);
  final _Vault vault;

  static int calls = 0;

  @override
  Future<BiometricVaultOutcome> deactivate({
    required String expectedUserId,
  }) async {
    calls++;
    final binding = vault.binding;
    if (binding is BiometricBindingEnabled &&
        binding.userId == expectedUserId) {
      vault.binding = const BiometricBindingDisabled();
      return BiometricVaultOutcome.verified;
    }
    return BiometricVaultOutcome.denied;
  }
}

final class _Fixture {
  _Fixture() : primary = _Identity('uid-a'), secondary = _Identity(null) {
    selection = AccountSessionSelectionController(
      primary: primary,
      secondary: secondary,
    );
    controller = AccountBiometricSettingsController(
      selection: selection,
      primarySession: _Session(primary),
      secondarySession: _Session(secondary),
      gateway: vault,
      unlinkGateway: _Unlink(vault),
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

  Future<void> authorize() async {
    final accepted = await selection.select(
      slot: FirebaseAccountSlot.primary,
      expectedUserId: 'uid-a',
      verifyAccess: () async => true,
    );
    expect(accepted, isTrue);
  }

  Future<void> dispose() async {
    controller.dispose();
    selection.dispose();
    await primary.dispose();
    await secondary.dispose();
  }
}

void main() {
  Future<_Fixture> mount(
    WidgetTester tester, {
    BiometricBindingState binding = const BiometricBindingDisabled(),
    bool ready = true,
  }) async {
    tester.view.physicalSize = const Size(700, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fixture = _Fixture();
    fixture.vault.binding = binding;
    await fixture.authorize();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await fixture.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AccountBiometricSettingsCard(
            controller: fixture.controller,
            isAccountReady: ready,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  testWidgets('activa A con confirmación y mantiene autorización', (
    tester,
  ) async {
    final fixture = await mount(tester);

    expect(find.textContaining('no está configurada'), findsOneWidget);
    await tester.tap(find.byKey(const Key('settings-biometric-activate')));
    await tester.pumpAndSettle();
    expect(fixture.vault.enrollCalls, 0);

    await tester.tap(find.byKey(const Key('biometric-enrollment-confirm')));
    await tester.pumpAndSettle();

    expect(fixture.vault.enrollCalls, 1);
    expect(fixture.changes, hasLength(1));
    expect(fixture.selection.value, isTrue);
    expect(fixture.selection.selectedUserId, 'uid-a');
    expect(
      find.byKey(const Key('settings-biometric-deactivate')),
      findsOneWidget,
    );
    expect(fixture.vault.clearCalls, 0);
  });

  testWidgets('desactiva A solo mediante gateway protegido', (tester) async {
    _Unlink.calls = 0;
    final fixture = await mount(
      tester,
      binding: const BiometricBindingEnabled(userId: 'uid-a'),
    );

    await tester.tap(find.byKey(const Key('settings-biometric-deactivate')));
    await tester.pumpAndSettle();
    expect(_Unlink.calls, 0);

    await tester.tap(find.byKey(const Key('biometric-deactivation-confirm')));
    await tester.pumpAndSettle();

    expect(_Unlink.calls, 1);
    expect(fixture.vault.binding, isA<BiometricBindingDisabled>());
    expect(fixture.selection.value, isTrue);
    expect(fixture.vault.clearCalls, 0);
    expect(
      find.byKey(const Key('settings-biometric-activate')),
      findsOneWidget,
    );
  });

  testWidgets('otra cuenta vinculada no permite mutaciones', (tester) async {
    final fixture = await mount(
      tester,
      binding: const BiometricBindingEnabled(userId: 'uid-b'),
    );

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('settings-biometric-activate')),
    );
    expect(button.onPressed, isNull);
    expect(fixture.vault.enrollCalls, 0);
    expect(fixture.changes, isEmpty);
    expect(find.textContaining('otra cuenta'), findsOneWidget);
  });

  testWidgets('cancelar confirmación no cambia la vinculación', (tester) async {
    final fixture = await mount(tester);
    await tester.tap(find.byKey(const Key('settings-biometric-activate')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(fixture.vault.enrollCalls, 0);
    expect(fixture.changes, isEmpty);
    expect(fixture.selection.value, isTrue);
  });

  testWidgets('una identidad revocada durante confirmación no opera', (
    tester,
  ) async {
    final fixture = await mount(tester);
    await tester.tap(find.byKey(const Key('settings-biometric-activate')));
    await tester.pumpAndSettle();

    fixture.primary.update('uid-b');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('biometric-enrollment-confirm')));
    await tester.pumpAndSettle();

    expect(fixture.vault.enrollCalls, 0);
    expect(fixture.changes, isEmpty);
    expect(fixture.selection.value, isFalse);
  });

  testWidgets('correo no verificado mantiene acción deshabilitada', (
    tester,
  ) async {
    final fixture = await mount(tester, ready: false);
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('settings-biometric-activate')),
    );
    expect(button.onPressed, isNull);
    expect(fixture.vault.enrollCalls, 0);
  });
}
