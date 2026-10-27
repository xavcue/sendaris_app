import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/session/account_biometric_access_coordinator.dart';
import 'package:sendaris/app/session/account_biometric_settings_controller.dart';
import 'package:sendaris/app/session/account_session_exit_coordinator.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/biometric_vault_gateway.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/sendaris_dual_account_root.dart';
import 'package:sendaris/app/theme/theme_mode_controller.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:sendaris/features/settings/presentation/views/settings_view.dart';
import 'package:sendaris/features/settings/presentation/widgets/account_biometric_settings_card.dart';
import 'package:sendaris/features/settings/presentation/widgets/biometric_enrollment_settings_card.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

final class _Auth
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthEmailVerificationRepository,
        AuthSessionValidationRepository,
        AccountIdentitySource {
  _Auth();

  final _authChanges = StreamController<bool>.broadcast(sync: true);
  final _identityChanges = StreamController<String?>.broadcast(sync: true);

  @override
  bool get isAuthenticated => true;
  @override
  String? get currentUserId => 'uid-a';
  @override
  String? get currentUserEmail => 'a@sendaris.test';
  @override
  bool get isCurrentUserEmailVerified => true;
  @override
  Stream<bool> get authStateChanges => _authChanges.stream;
  @override
  Stream<String?> get userIdChanges => _identityChanges.stream;
  @override
  Future<bool> validateCurrentSession() async => true;
  @override
  Future<bool> refreshEmailVerificationStatus() async => true;
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signOut() async {}

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}

final class _OtherIdentity
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthEmailVerificationRepository,
        AuthSessionValidationRepository,
        AccountIdentitySource {
  _OtherIdentity(this._userId);

  String? _userId;
  final _authChanges = StreamController<bool>.broadcast(sync: true);
  final _changes = StreamController<String?>.broadcast(sync: true);

  @override
  bool get isAuthenticated => _userId != null;
  @override
  String? get currentUserId => _userId;
  @override
  String? get currentUserEmail => _userId == null ? null : 'b@sendaris.test';
  @override
  bool get isCurrentUserEmailVerified => _userId != null;
  @override
  Stream<bool> get authStateChanges => _authChanges.stream;
  @override
  Stream<String?> get userIdChanges => _changes.stream;
  @override
  Future<bool> validateCurrentSession() async => _userId != null;
  @override
  Future<bool> refreshEmailVerificationStatus() async => true;
  @override
  Future<void> sendEmailVerification() async {}
  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}
  @override
  Future<void> signOut() async {
    _userId = null;
    _changes.add(null);
    _authChanges.add(false);
  }

  Future<void> dispose() async {
    await _changes.close();
    await _authChanges.close();
  }
}

final class _Verifier implements AccountFirebaseSessionVerifier {
  const _Verifier(this.identity);
  final AccountIdentitySource identity;
  @override
  String? get currentUserId => identity.currentUserId;
  @override
  Future<bool> validate({required String expectedUserId}) async =>
      identity.currentUserId == expectedUserId;
}

final class _Vault implements BiometricVaultGateway {
  _Vault(this.binding);
  BiometricBindingState binding;
  @override
  Future<BiometricBindingState> readBinding() async => binding;
  @override
  Future<BiometricVaultOutcome> enroll({required String userId}) async =>
      BiometricVaultOutcome.denied;
  @override
  Future<BiometricVaultOutcome> unlock({
    required String expectedUserId,
  }) async => BiometricVaultOutcome.denied;
  @override
  Future<bool> clearBinding() async => false;
}

final class _Unlink implements BiometricUnlinkGateway {
  @override
  Future<BiometricVaultOutcome> deactivate({
    required String expectedUserId,
  }) async => BiometricVaultOutcome.denied;
}

final class _Exit implements AccountSessionExitTarget {
  const _Exit(this.identity);
  final AccountIdentitySource identity;
  @override
  String? get currentUserId => identity.currentUserId;
  @override
  Future<void> signOut() async {}
}

final class _TrackingRepository implements TrackingRepository {
  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async => [];
  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}
}

final class _IdGenerator implements AnonymousIdGenerator {
  const _IdGenerator();
  @override
  String generate() => 'id-ficticio';
}

final class _Fixture {
  _Fixture({required bool linked, bool asConventional = false}) {
    other = _OtherIdentity(asConventional ? 'uid-b' : null);
    selection = AccountSessionSelectionController(
      primary: auth,
      secondary: other,
    );
    exit = AccountSessionExitCoordinator(
      selection: selection,
      linkedSlot: linked ? FirebaseAccountSlot.primary : null,
      primary: _Exit(auth),
      secondary: _Exit(other),
    );
    vault = _Vault(
      linked
          ? const BiometricBindingEnabled(userId: 'uid-a')
          : const BiometricBindingDisabled(),
    );
    controller = AccountBiometricSettingsController(
      selection: selection,
      primarySession: _Verifier(auth),
      secondarySession: _Verifier(other),
      gateway: vault,
      unlinkGateway: _Unlink(),
      onBindingChanged: (_) async => false,
    );
    configuration = SendarisAccountSessionConfiguration(
      conventionalSlot: linked
          ? FirebaseAccountSlot.secondary
          : FirebaseAccountSlot.primary,
      linkedSlot: linked ? FirebaseAccountSlot.primary : null,
    );
    authViewModel = AuthViewModel(asConventional ? other : auth);
    trackingViewModel = TrackingViewModel(
      _TrackingRepository(),
      const AnonymousTrackingProfileFactory(_IdGenerator()),
    );
  }

  final auth = _Auth();
  late final _OtherIdentity other;
  final theme = ThemeModeController();
  late final AccountSessionSelectionController selection;
  late final AccountSessionExitCoordinator exit;
  late final AccountBiometricSettingsController controller;
  late final SendarisAccountSessionConfiguration configuration;
  late final _Vault vault;
  late final AuthViewModel authViewModel;
  late final TrackingViewModel trackingViewModel;

  Future<void> authorize({bool asConventional = false}) async {
    expect(
      await selection.select(
        slot: asConventional
            ? FirebaseAccountSlot.secondary
            : FirebaseAccountSlot.primary,
        expectedUserId: asConventional ? 'uid-b' : 'uid-a',
        verifyAccess: () async => true,
      ),
      isTrue,
    );
  }

  Future<void> dispose() async {
    controller.dispose();
    exit.dispose();
    selection.dispose();
    authViewModel.dispose();
    trackingViewModel.dispose();
    theme.dispose();
    await auth.dispose();
    await other.dispose();
  }
}

void main() {
  Future<_Fixture> mount(
    WidgetTester tester, {
    bool linked = false,
    bool authorized = true,
    bool asConventional = false,
  }) async {
    tester.view.physicalSize = const Size(1100, 4500);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final fixture = _Fixture(linked: linked, asConventional: asConventional);
    if (authorized) await fixture.authorize(asConventional: asConventional);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await fixture.dispose();
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
            value: fixture.theme,
          ),
          Provider<AccountSessionExitCoordinator>.value(value: fixture.exit),
          ChangeNotifierProvider<AccountBiometricSettingsController>.value(
            value: fixture.controller,
          ),
          Provider<SendarisAccountSessionConfiguration>.value(
            value: fixture.configuration,
          ),
        ],
        child: const MaterialApp(home: SettingsView()),
      ),
    );
    await tester.pumpAndSettle();
    return fixture;
  }

  testWidgets('modo dual muestra nueva tarjeta sin controlador antiguo', (
    tester,
  ) async {
    await mount(tester);
    expect(find.byType(AccountBiometricSettingsCard), findsOneWidget);
    expect(find.byType(BiometricEnrollmentSettingsCard), findsNothing);
    expect(find.byKey(const Key('settings-biometric-card')), findsOneWidget);
    expect(
      find.byKey(const Key('settings-biometric-activate')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('settings-sign-out-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cuenta vinculada bloquea eliminar sin perder cerrar sesion', (
    tester,
  ) async {
    await mount(tester, linked: true);
    expect(find.byType(AccountBiometricSettingsCard), findsOneWidget);
    expect(
      find.byKey(const Key('settings-linked-delete-protection')),
      findsOneWidget,
    );
    final delete = tester.widget<InkWell>(
      find.byKey(const Key('settings-delete-account-action')),
    );
    expect(delete.onTap, isNull);
    expect(find.byKey(const Key('settings-sign-out-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cuenta B no ve Seguridad si A ya esta vinculada', (
    tester,
  ) async {
    await mount(tester, linked: true, asConventional: true);

    expect(find.byType(AccountBiometricSettingsCard), findsNothing);
    expect(find.byType(BiometricEnrollmentSettingsCard), findsNothing);
    expect(find.text('SEGURIDAD'), findsNothing);
    expect(
      find.byKey(const Key('settings-linked-delete-protection')),
      findsNothing,
    );
    expect(find.byKey(const Key('settings-sign-out-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin vinculacion cualquier cuenta convencional ve Seguridad', (
    tester,
  ) async {
    await mount(tester, linked: false);

    expect(find.byType(AccountBiometricSettingsCard), findsOneWidget);
    expect(find.text('SEGURIDAD'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmacion de cierre no revela detalles de vinculacion', (
    tester,
  ) async {
    await mount(tester, linked: true);

    await tester.tap(find.byKey(const Key('settings-sign-out-action')));
    await tester.pumpAndSettle();

    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    expect(
      find.text('¿Estás seguro de que deseas cerrar sesión?'),
      findsOneWidget,
    );
    expect(find.textContaining('vinculación se conservará'), findsNothing);
    expect(find.textContaining('mediante biometría'), findsNothing);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin autorizacion privada se bloquean acciones sensibles', (
    tester,
  ) async {
    await mount(tester, authorized: false);
    expect(find.byType(AccountBiometricSettingsCard), findsNothing);
    final delete = tester.widget<InkWell>(
      find.byKey(const Key('settings-delete-account-action')),
    );
    final exit = tester.widget<InkWell>(
      find.byKey(const Key('settings-sign-out-action')),
    );
    expect(delete.onTap, isNull);
    expect(exit.onTap, isNull);
    expect(tester.takeException(), isNull);
  });
}
