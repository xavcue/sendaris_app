import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/biometric_enrollment_controller.dart';
import 'package:sendaris/app/session/biometric_enrollment_coordinator.dart';
import 'package:sendaris/app/session/biometric_settings_binding_reader.dart';
import 'package:sendaris/app/session/biometric_vault_gateway.dart';
import 'package:sendaris/app/theme/theme_mode_controller.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:sendaris/features/settings/presentation/views/settings_view.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  group('AUTH-03 - Ajustes y biometría integrada', () {
    Future<_Fixture> mount(
      WidgetTester tester, {
      bool verified = true,
      bool provideBiometrics = true,
      BiometricBindingState binding = const BiometricBindingDisabled(),
    }) async {
      tester.view.physicalSize = const Size(1100, 4500);
      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final fixture = _Fixture(verified: verified, binding: binding);

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());

        fixture.controller.dispose();
        fixture.authViewModel.dispose();
        fixture.trackingViewModel.dispose();
        fixture.themeModeController.dispose();

        await fixture.auth.dispose();
      });

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthViewModel>.value(
              value: fixture.authViewModel,
            ),
            ChangeNotifierProvider<TrackingViewModel>.value(
              value: fixture.trackingViewModel,
            ),
            ChangeNotifierProvider<ThemeModeController>.value(
              value: fixture.themeModeController,
            ),
            if (provideBiometrics)
              ChangeNotifierProvider<BiometricEnrollmentController>.value(
                value: fixture.controller,
              ),
          ],
          child: const MaterialApp(home: SettingsView()),
        ),
      );

      await tester.pumpAndSettle();

      return fixture;
    }

    testWidgets('se muestra después de Apariencia y antes de las acciones', (
      tester,
    ) async {
      final fixture = await mount(tester);

      final privacy = find.byKey(const Key('settings-privacy-card'));
      final appearance = find.byKey(const Key('settings-appearance-card'));
      final biometric = find.byKey(const Key('settings-biometric-card'));
      final delete = find.byKey(const Key('settings-delete-account-card'));
      final signOut = find.byKey(const Key('settings-sign-out-action'));

      expect(privacy, findsOneWidget);
      expect(appearance, findsOneWidget);
      expect(biometric, findsOneWidget);
      expect(delete, findsOneWidget);
      expect(signOut, findsOneWidget);

      expect(
        tester.getTopLeft(privacy).dy,
        lessThan(tester.getTopLeft(appearance).dy),
      );

      expect(
        tester.getTopLeft(appearance).dy,
        lessThan(tester.getTopLeft(biometric).dy),
      );

      expect(
        tester.getTopLeft(biometric).dy,
        lessThan(tester.getTopLeft(delete).dy),
      );

      expect(
        tester.getTopLeft(delete).dy,
        lessThan(tester.getTopLeft(signOut).dy),
      );

      expect(
        fixture.controller.bindingStatus,
        BiometricSettingsBindingStatus.disabled,
      );

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('settings-biometric-activate')),
      );

      expect(button.onPressed, isNotNull);
      expect(fixture.vault.enrollCalls, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('una cuenta sin correo verificado no permite activación', (
      tester,
    ) async {
      final fixture = await mount(tester, verified: false);

      expect(find.byKey(const Key('settings-biometric-card')), findsOneWidget);

      expect(
        fixture.controller.bindingStatus,
        BiometricSettingsBindingStatus.disabled,
      );

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('settings-biometric-activate')),
      );

      expect(button.onPressed, isNull);
      expect(fixture.vault.enrollCalls, 0);
    });

    testWidgets('no muestra la tarjeta si el controlador no está provisto', (
      tester,
    ) async {
      await mount(tester, provideBiometrics: false);

      expect(find.byKey(const Key('settings-biometric-card')), findsNothing);

      expect(find.byKey(const Key('settings-sign-out-action')), findsOneWidget);

      expect(tester.takeException(), isNull);
    });

    testWidgets('la vinculación de otra cuenta bloquea la configuración', (
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

      final button = tester.widget<FilledButton>(
        find.byKey(const Key('settings-biometric-activate')),
      );

      expect(button.onPressed, isNull);
      expect(fixture.vault.enrollCalls, 0);
    });
  });
}

final class _Fixture {
  _Fixture({required bool verified, required BiometricBindingState binding})
    : auth = _FakeAuth(verified: verified),
      vault = _FakeVault(binding) {
    authViewModel = AuthViewModel(auth);

    trackingViewModel = TrackingViewModel(
      _EmptyTrackingRepository(),
      const AnonymousTrackingProfileFactory(_FakeIdGenerator()),
    );

    coordinator = BiometricEnrollmentCoordinator(
      repository: auth,
      gateway: vault,
    );

    controller = BiometricEnrollmentController(
      coordinator: coordinator,
      bindingReader: BiometricSettingsBindingReader(
        repository: auth,
        gateway: vault,
      ),
      onOperationFinished: (_) {},
    );
  }

  final _FakeAuth auth;
  final _FakeVault vault;

  final ThemeModeController themeModeController = ThemeModeController();

  late final AuthViewModel authViewModel;
  late final TrackingViewModel trackingViewModel;
  late final BiometricEnrollmentCoordinator coordinator;
  late final BiometricEnrollmentController controller;
}

final class _FakeAuth
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthEmailVerificationRepository,
        AuthSessionValidationRepository {
  _FakeAuth({required this.verified});

  final bool verified;

  final StreamController<bool> _authChanges = StreamController<bool>.broadcast(
    sync: true,
  );

  final StreamController<String?> _identityChanges =
      StreamController<String?>.broadcast(sync: true);

  String? _uid = 'uid-a';

  @override
  bool get isAuthenticated => _uid != null;

  @override
  String? get currentUserId => _uid;

  @override
  String? get currentUserEmail => 'test@sendaris.test';

  @override
  bool get isCurrentUserEmailVerified => verified;

  @override
  Stream<bool> get authStateChanges => _authChanges.stream;

  @override
  Stream<String?> get userIdChanges => _identityChanges.stream;

  @override
  Future<bool> validateCurrentSession() async => true;

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> refreshEmailVerificationStatus() async => verified;

  @override
  Future<void> signIn({required String email, required String password}) async {
    _uid = 'uid-a';
    _identityChanges.add(_uid);
    _authChanges.add(true);
  }

  @override
  Future<void> signOut() async {
    _uid = null;
    _identityChanges.add(null);
    _authChanges.add(false);
  }

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}

final class _FakeVault implements BiometricVaultGateway {
  _FakeVault(this.binding);

  BiometricBindingState binding;

  int enrollCalls = 0;

  @override
  Future<BiometricBindingState> readBinding() async => binding;

  @override
  Future<BiometricVaultOutcome> enroll({required String userId}) async {
    enrollCalls++;
    return BiometricVaultOutcome.denied;
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

final class _EmptyTrackingRepository implements TrackingRepository {
  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async => [];

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}
}

final class _FakeIdGenerator implements AnonymousIdGenerator {
  const _FakeIdGenerator();

  @override
  String generate() => 'seguimiento-generado';
}
