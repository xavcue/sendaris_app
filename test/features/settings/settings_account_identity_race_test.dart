import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sendaris/app/theme/theme_mode_controller.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:sendaris/features/settings/presentation/views/settings_view.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_deletion_repository.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  group('SettingsView - aislamiento en eliminacion de cuenta', () {
    testWidgets('cambiar a B durante la reautenticacion de A '
        'no elimina datos ni cuenta de B', (tester) async {
      final reauthenticationGate = Completer<void>();

      final fixture = await _pumpSettings(
        tester,
        reauthenticationGate: reauthenticationGate,
      );

      await _startAccountDeletion(tester);

      expect(fixture.operationLog, ['reauth:uid-a']);

      fixture.changeAccount('uid-b');

      await tester.pump();

      expect(fixture.authViewModel.currentUserId, 'uid-b');
      expect(fixture.authViewModel.isAuthenticated, isTrue);

      reauthenticationGate.complete();

      await tester.pumpAndSettle();

      expect(
        fixture.operationLog,
        ['reauth:uid-a'],
        reason:
            'Una confirmacion de identidad iniciada por A '
            'no autoriza eliminar los datos de B.',
      );

      expect(fixture.authRepository.currentUserId, 'uid-b');
      expect(fixture.authViewModel.isAuthenticated, isTrue);
      expect(fixture.trackingRepository.deletedProfiles, isEmpty);
    });

    testWidgets('cambiar a B durante la eliminacion de A '
        'no inicia nuevas eliminaciones ni elimina B', (tester) async {
      final deletionGate = Completer<void>();

      final fixture = await _pumpSettings(tester, deletionGate: deletionGate);

      await _startAccountDeletion(tester);

      expect(fixture.operationLog, [
        'reauth:uid-a',
        'recover:uid-a',
        'delete:uid-a:seguimiento-a',
      ]);

      fixture.changeAccount('uid-b');

      await tester.pump();

      expect(fixture.authViewModel.currentUserId, 'uid-b');

      deletionGate.complete();

      await tester.pumpAndSettle();

      expect(
        fixture.operationLog,
        ['reauth:uid-a', 'recover:uid-a', 'delete:uid-a:seguimiento-a'],
        reason:
            'Despues del cambio de identidad no deben '
            'iniciarse operaciones destructivas adicionales.',
      );

      expect(fixture.authRepository.currentUserId, 'uid-b');
      expect(fixture.authViewModel.isAuthenticated, isTrue);

      expect(fixture.trackingRepository.deletedProfiles, [
        'uid-a:seguimiento-a',
      ]);
    });
  });
}

Future<_Fixture> _pumpSettings(
  WidgetTester tester, {
  Completer<void>? reauthenticationGate,
  Completer<void>? deletionGate,
}) async {
  final operationLog = <String>[];

  final authRepository = _IdentityAccountRepository(
    operationLog: operationLog,
    reauthenticationGate: reauthenticationGate,
  );

  final authViewModel = AuthViewModel(authRepository);

  final trackingRepository = _ControlledTrackingRepository(
    authRepository: authRepository,
    operationLog: operationLog,
    deletionGate: deletionGate,
  );

  final trackingViewModel = TrackingViewModel(
    trackingRepository,
    const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
  );

  trackingViewModel.synchronizeAuthenticationContext(
    authRepository.currentUserId,
  );

  final themeModeController = ThemeModeController();

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    authViewModel.dispose();
    trackingViewModel.dispose();
    themeModeController.dispose();

    await authRepository.dispose();
  });

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: authViewModel),
        ChangeNotifierProvider<TrackingViewModel>.value(
          value: trackingViewModel,
        ),
        ChangeNotifierProvider<ThemeModeController>.value(
          value: themeModeController,
        ),
      ],
      child: MaterialApp(
        theme: ThemeData.light(useMaterial3: true),
        home: const SettingsView(),
      ),
    ),
  );

  await tester.pumpAndSettle();

  return _Fixture(
    operationLog: operationLog,
    authRepository: authRepository,
    authViewModel: authViewModel,
    trackingRepository: trackingRepository,
    trackingViewModel: trackingViewModel,
  );
}

Future<void> _startAccountDeletion(WidgetTester tester) async {
  final action = find.byKey(const Key('settings-delete-account-action'));

  await tester.scrollUntilVisible(
    action,
    300,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pumpAndSettle();

  await tester.tap(action);

  await tester.pumpAndSettle();

  await tester.tap(
    find.byKey(const Key('settings-continue-delete-account-button')),
  );

  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const Key('settings-delete-account-password-field')),
    'PasswordDePrueba123!',
  );

  await tester.tap(
    find.byKey(const Key('settings-confirm-delete-account-button')),
  );

  // No utilizamos pumpAndSettle porque alguna operacion
  // asincronica permanece deliberadamente pendiente.
  await tester.pump();
}

class _Fixture {
  const _Fixture({
    required this.operationLog,
    required this.authRepository,
    required this.authViewModel,
    required this.trackingRepository,
    required this.trackingViewModel,
  });

  final List<String> operationLog;

  final _IdentityAccountRepository authRepository;

  final AuthViewModel authViewModel;

  final _ControlledTrackingRepository trackingRepository;

  final TrackingViewModel trackingViewModel;

  void changeAccount(String userId) {
    authRepository.changeAccount(userId);

    // Reproduce la sincronizacion del contexto de seguimiento
    // que realiza SendarisApp al cambiar el UID.
    trackingViewModel.synchronizeAuthenticationContext(userId);
  }
}

class _IdentityAccountRepository
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthAccountManagementRepository {
  _IdentityAccountRepository({
    required this.operationLog,
    this.reauthenticationGate,
  });

  final List<String> operationLog;

  final Completer<void>? reauthenticationGate;

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
  Stream<bool> get authStateChanges => _authChanges.stream;

  @override
  Stream<String?> get userIdChanges => _identityChanges.stream;

  void changeAccount(String? userId) {
    _userId = userId;

    _identityChanges.add(userId);
    _authChanges.add(userId != null);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    changeAccount('uid-login');
  }

  @override
  Future<void> signOut() async {
    changeAccount(null);
  }

  @override
  Future<void> reauthenticateWithPassword({required String password}) async {
    operationLog.add('reauth:$_userId');

    final gate = reauthenticationGate;

    if (gate != null) {
      await gate.future;
    }
  }

  @override
  Future<void> deleteCurrentAccount() async {
    operationLog.add('delete-account:$_userId');

    changeAccount(null);
  }

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}

class _ControlledTrackingRepository
    implements TrackingRepository, TrackingDeletionRepository {
  _ControlledTrackingRepository({
    required this.authRepository,
    required this.operationLog,
    this.deletionGate,
  });

  final _IdentityAccountRepository authRepository;

  final List<String> operationLog;

  final Completer<void>? deletionGate;

  final List<String> deletedProfiles = [];

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    final uid = authRepository.currentUserId;

    operationLog.add('recover:$uid');

    if (uid == null) {
      return [];
    }

    final anonymousId = uid == 'uid-a' ? 'seguimiento-a' : 'seguimiento-b';

    return [
      AnonymousTrackingProfile(
        anonymousId: anonymousId,
        createdAt: DateTime.utc(2026, 10, 13),
        trackingNumber: 1,
      ),
    ];
  }

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}

  @override
  Future<void> deleteProfile(String anonymousId) async {
    final uid = authRepository.currentUserId;

    operationLog.add('delete:$uid:$anonymousId');

    final gate = deletionGate;

    if (gate != null) {
      await gate.future;
    }

    deletedProfiles.add('$uid:$anonymousId');
  }
}

class _FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  const _FakeAnonymousIdGenerator();

  @override
  String generate() => 'seguimiento-generado';
}
