import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/biometric_enrollment_controller.dart';
import 'package:sendaris/app/session/biometric_enrollment_coordinator.dart';
import 'package:sendaris/app/session/biometric_settings_binding_reader.dart';
import 'package:sendaris/app/session/biometric_vault_gateway.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/settings/presentation/widgets/biometric_enrollment_settings_card.dart';

void main() {
  group('AUTH-03 - Tarjeta de activación biométrica', () {
    Future<_Fixture> mount(
      WidgetTester tester, {
      bool accountReady = true,
      bool withReader = true,
      BiometricBindingState binding = const BiometricBindingDisabled(),
      Completer<BiometricBindingState>? pendingRead,
    }) async {
      final fixture = _Fixture(binding: binding, withReader: withReader);

      fixture.vault.pendingRead = pendingRead;

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        fixture.controller.dispose();
        await fixture.auth.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BiometricEnrollmentSettingsCard(
              controller: fixture.controller,
              isAccountReady: accountReady,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      return fixture;
    }

    Future<void> openConfirmation(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('settings-biometric-activate')));

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('biometric-enrollment-confirmation-dialog')),
        findsOneWidget,
      );
    }

    testWidgets('sin cuenta habilitada no permite configurar biometría', (
      tester,
    ) async {
      final fixture = await mount(tester, accountReady: false);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('settings-biometric-activate')),
      );

      expect(button.onPressed, isNull);
      expect(fixture.vault.enrollCalls, 0);

      expect(
        find.byKey(const Key('settings-biometric-account-not-ready')),
        findsOneWidget,
      );
    });

    testWidgets('cancelar el diálogo no inicia una operación nativa', (
      tester,
    ) async {
      final fixture = await mount(tester);

      await openConfirmation(tester);

      await tester.tap(find.byKey(const Key('biometric-enrollment-cancel')));

      await tester.pumpAndSettle();

      expect(fixture.vault.enrollCalls, 0);
      expect(fixture.controller.lastResult, isNull);

      expect(
        find.byKey(const Key('biometric-enrollment-confirmation-dialog')),
        findsNothing,
      );
    });

    testWidgets('confirmar activa el progreso e impide otra solicitud', (
      tester,
    ) async {
      final fixture = await mount(tester);

      final pending = Completer<BiometricVaultOutcome>();
      fixture.vault.pendingEnrollment = pending;

      await openConfirmation(tester);

      await tester.tap(find.byKey(const Key('biometric-enrollment-confirm')));

      await tester.pump();
      await tester.pump();

      expect(fixture.vault.enrollCalls, 1);
      expect(fixture.controller.isBusy, isTrue);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('settings-biometric-activate')),
      );

      expect(button.onPressed, isNull);

      pending.complete(BiometricVaultOutcome.verified);

      await tester.pumpAndSettle();

      expect(fixture.controller.isBusy, isFalse);
      expect(fixture.vault.enrollCalls, 1);

      expect(fixture.controller.lastResult, BiometricEnrollmentResult.enabled);

      expect(
        fixture.controller.bindingStatus,
        BiometricSettingsBindingStatus.enabledForCurrentUser,
      );

      expect(
        find.textContaining('La vinculación biométrica se configuró'),
        findsOneWidget,
      );
    });

    testWidgets('una cancelación nativa no muestra activación exitosa', (
      tester,
    ) async {
      final fixture = await mount(tester);

      fixture.vault.outcome = BiometricVaultOutcome.cancelled;

      await openConfirmation(tester);

      await tester.tap(find.byKey(const Key('biometric-enrollment-confirm')));

      await tester.pumpAndSettle();

      expect(fixture.vault.enrollCalls, 1);

      expect(
        fixture.controller.lastResult,
        BiometricEnrollmentResult.cancelled,
      );

      expect(
        fixture.controller.bindingStatus,
        BiometricSettingsBindingStatus.disabled,
      );

      expect(fixture.vault.binding, isA<BiometricBindingDisabled>());

      expect(
        find.text('La configuración biométrica fue cancelada.'),
        findsOneWidget,
      );
    });

    testWidgets('una vinculación del UID actual se muestra como configurada', (
      tester,
    ) async {
      final fixture = await mount(
        tester,
        binding: const BiometricBindingEnabled(userId: 'uid-a'),
      );

      expect(
        fixture.controller.bindingStatus,
        BiometricSettingsBindingStatus.enabledForCurrentUser,
      );

      expect(find.text('Biometría configurada'), findsOneWidget);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('settings-biometric-activate')),
      );

      expect(button.onPressed, isNull);
      expect(fixture.vault.enrollCalls, 0);
    });

    testWidgets('una vinculación de otra cuenta no permite activar', (
      tester,
    ) async {
      final fixture = await mount(
        tester,
        binding: const BiometricBindingEnabled(userId: 'uid-b'),
      );

      expect(
        fixture.controller.bindingStatus,
        BiometricSettingsBindingStatus.enabledForDifferentUser,
      );

      expect(
        find.textContaining('correspondiente a otra cuenta'),
        findsOneWidget,
      );

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('settings-biometric-activate')),
      );

      expect(button.onPressed, isNull);
      expect(fixture.vault.enrollCalls, 0);
    });

    testWidgets('un estado nativo no disponible bloquea el botón', (
      tester,
    ) async {
      final fixture = await mount(
        tester,
        binding: const BiometricBindingUnavailable(),
      );

      expect(
        fixture.controller.bindingStatus,
        BiometricSettingsBindingStatus.unavailable,
      );

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('settings-biometric-activate')),
      );

      expect(button.onPressed, isNull);
      expect(fixture.vault.enrollCalls, 0);
    });

    testWidgets('el botón permanece bloqueado durante la lectura nativa', (
      tester,
    ) async {
      final pending = Completer<BiometricBindingState>();

      final fixture = await mount(tester, pendingRead: pending);

      expect(fixture.controller.isReadingBinding, isTrue);
      expect(fixture.controller.bindingStatus, isNull);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('settings-biometric-activate')),
      );

      expect(button.onPressed, isNull);
      expect(fixture.vault.enrollCalls, 0);

      pending.complete(const BiometricBindingDisabled());

      await tester.pumpAndSettle();

      expect(
        fixture.controller.bindingStatus,
        BiometricSettingsBindingStatus.disabled,
      );

      final enabledButton = tester.widget<FilledButton>(
        find.byKey(const Key('settings-biometric-activate')),
      );

      expect(enabledButton.onPressed, isNotNull);
    });

    testWidgets('sin lector configurado el botón permanece bloqueado', (
      tester,
    ) async {
      final fixture = await mount(tester, withReader: false);

      expect(
        fixture.controller.bindingStatus,
        BiometricSettingsBindingStatus.unavailable,
      );

      expect(fixture.controller.canConfigureBiometrics, isFalse);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('settings-biometric-activate')),
      );

      expect(button.onPressed, isNull);
      expect(fixture.vault.enrollCalls, 0);
    });

    testWidgets('A-B-A durante una lectura no permite activar', (tester) async {
      final pending = Completer<BiometricBindingState>();

      final fixture = await mount(tester, pendingRead: pending);

      fixture.auth.setUser('uid-b');
      fixture.auth.setUser('uid-a');

      pending.complete(const BiometricBindingDisabled());

      await tester.pumpAndSettle();

      expect(
        fixture.controller.bindingStatus,
        BiometricSettingsBindingStatus.identityChanged,
      );

      expect(fixture.controller.canConfigureBiometrics, isFalse);

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('settings-biometric-activate')),
      );

      expect(button.onPressed, isNull);
      expect(fixture.vault.enrollCalls, 0);
    });
  });
}

final class _Fixture {
  _Fixture({required BiometricBindingState binding, required bool withReader})
    : vault = _FakeVault(binding) {
    coordinator = BiometricEnrollmentCoordinator(
      repository: auth,
      gateway: vault,
    );

    controller = BiometricEnrollmentController(
      coordinator: coordinator,
      bindingReader: withReader
          ? BiometricSettingsBindingReader(repository: auth, gateway: vault)
          : null,
      onOperationFinished: (_) {},
    );
  }

  final _FakeAuth auth = _FakeAuth();
  final _FakeVault vault;

  late final BiometricEnrollmentCoordinator coordinator;
  late final BiometricEnrollmentController controller;
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
  _FakeVault(this.binding);

  BiometricBindingState binding;

  BiometricVaultOutcome outcome = BiometricVaultOutcome.verified;

  Completer<BiometricVaultOutcome>? pendingEnrollment;
  Completer<BiometricBindingState>? pendingRead;

  int enrollCalls = 0;

  @override
  Future<BiometricBindingState> readBinding() async {
    final pending = pendingRead;

    return pending == null ? binding : await pending.future;
  }

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
