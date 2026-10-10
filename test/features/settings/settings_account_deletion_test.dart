import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/theme/theme_mode_controller.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:sendaris/features/settings/presentation/views/settings_view.dart';
import 'package:sendaris/features/tracking/domain/exceptions/tracking_failure.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_deletion_repository.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  group('SettingsView eliminación de cuenta', () {
    testWidgets('cancelar la advertencia no modifica datos ni cuenta', (
      tester,
    ) async {
      final fixture = await _pumpSettings(tester);

      await _openDeleteAccount(tester);

      expect(
        find.byKey(const Key('settings-delete-account-warning-dialog')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('settings-cancel-delete-account-button')),
      );

      await tester.pumpAndSettle();

      expect(fixture.operationLog, isEmpty);

      expect(fixture.authViewModel.isAuthenticated, isTrue);
    });

    testWidgets(
      'contraseña incorrecta detiene la eliminación antes de tocar Firestore',
      (tester) async {
        final fixture = await _pumpSettings(tester);

        fixture.authRepository.reauthenticationError = const AuthFailure(
          'La contraseña ingresada es incorrecta.',
        );

        await _submitDeleteAccount(tester, password: 'incorrecta');

        await tester.pumpAndSettle();

        expect(fixture.operationLog, ['reauth']);

        expect(fixture.trackingRepository.recoverCalls, 0);

        expect(fixture.authRepository.deleteAccountCalls, 0);

        expect(fixture.authViewModel.isAuthenticated, isTrue);

        expect(
          find.text('La contraseña ingresada es incorrecta.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('limpia los datos antes de eliminar Authentication', (
      tester,
    ) async {
      final fixture = await _pumpSettings(tester);

      await _submitDeleteAccount(tester, password: 'PasswordDePrueba123!');

      await tester.pumpAndSettle();

      expect(fixture.operationLog, [
        'reauth',
        'recover',
        'delete:seguimiento-1',
        'delete:seguimiento-2',
        'delete-account',
      ]);

      expect(fixture.authRepository.lastPassword, 'PasswordDePrueba123!');

      expect(fixture.authRepository.deleteAccountCalls, 1);

      expect(fixture.authViewModel.isAuthenticated, isFalse);

      expect(fixture.trackingViewModel.profiles, isEmpty);

      expect(fixture.trackingViewModel.activeProfile, isNull);
    });

    testWidgets('si falla la limpieza no elimina Authentication', (
      tester,
    ) async {
      final fixture = await _pumpSettings(tester);

      fixture.trackingRepository.failingId = 'seguimiento-2';

      await _submitDeleteAccount(tester, password: 'PasswordDePrueba123!');

      await tester.pumpAndSettle();

      expect(fixture.operationLog, [
        'reauth',
        'recover',
        'delete:seguimiento-1',
        'delete:seguimiento-2',
      ]);

      expect(fixture.authRepository.deleteAccountCalls, 0);

      expect(fixture.authViewModel.isAuthenticated, isTrue);

      expect(
        find.text(
          'No fue posible eliminar '
          'el seguimiento de prueba.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('muestra progreso mientras procesa la eliminación', (
      tester,
    ) async {
      final reauthenticationGate = Completer<void>();

      final fixture = await _pumpSettings(
        tester,
        reauthenticationGate: reauthenticationGate,
      );

      await _openDeleteAccount(tester);

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

      await tester.pump();

      expect(
        find.byKey(const Key('settings-delete-account-progress')),
        findsOneWidget,
      );

      expect(fixture.authRepository.deleteAccountCalls, 0);

      reauthenticationGate.complete();

      await tester.pumpAndSettle();

      expect(fixture.authViewModel.isAuthenticated, isFalse);
    });
  });
}

Future<_SettingsFixture> _pumpSettings(
  WidgetTester tester, {
  Completer<void>? reauthenticationGate,
}) async {
  final operationLog = <String>[];

  final authRepository = _FakeAccountAuthRepository(
    operationLog: operationLog,
    reauthenticationGate: reauthenticationGate,
  );

  final authViewModel = AuthViewModel(authRepository);

  final trackingRepository = _FakeAccountTrackingRepository(
    operationLog: operationLog,
  );

  final trackingViewModel = TrackingViewModel(
    trackingRepository,
    const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
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
      child: Consumer<ThemeModeController>(
        builder: (context, controller, child) {
          return MaterialApp(
            theme: ThemeData.light(useMaterial3: true),
            darkTheme: ThemeData.dark(useMaterial3: true),
            themeMode: controller.themeMode,
            home: const SettingsView(),
          );
        },
      ),
    ),
  );

  await tester.pumpAndSettle();

  return _SettingsFixture(
    operationLog: operationLog,
    authRepository: authRepository,
    authViewModel: authViewModel,
    trackingRepository: trackingRepository,
    trackingViewModel: trackingViewModel,
  );
}

Future<void> _openDeleteAccount(WidgetTester tester) async {
  final action = find.byKey(const Key('settings-delete-account-action'));

  await tester.scrollUntilVisible(
    action,
    300,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pumpAndSettle();

  expect(action, findsOneWidget);

  await tester.tap(action);

  await tester.pumpAndSettle();
}

Future<void> _submitDeleteAccount(
  WidgetTester tester, {
  required String password,
}) async {
  await _openDeleteAccount(tester);

  await tester.tap(
    find.byKey(const Key('settings-continue-delete-account-button')),
  );

  await tester.pumpAndSettle();

  await tester.enterText(
    find.byKey(const Key('settings-delete-account-password-field')),
    password,
  );

  await tester.tap(
    find.byKey(const Key('settings-confirm-delete-account-button')),
  );

  await tester.pumpAndSettle();
}

class _SettingsFixture {
  const _SettingsFixture({
    required this.operationLog,
    required this.authRepository,
    required this.authViewModel,
    required this.trackingRepository,
    required this.trackingViewModel,
  });

  final List<String> operationLog;

  final _FakeAccountAuthRepository authRepository;

  final AuthViewModel authViewModel;

  final _FakeAccountTrackingRepository trackingRepository;

  final TrackingViewModel trackingViewModel;
}

class _FakeAccountAuthRepository
    implements AuthRepository, AuthAccountManagementRepository {
  _FakeAccountAuthRepository({
    required this.operationLog,
    this.reauthenticationGate,
  });

  final List<String> operationLog;

  final Completer<void>? reauthenticationGate;

  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );

  bool authenticated = true;

  Object? reauthenticationError;

  int deleteAccountCalls = 0;

  String? lastPassword;

  @override
  bool get isAuthenticated {
    return authenticated;
  }

  @override
  Stream<bool> get authStateChanges {
    return _controller.stream;
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {
    authenticated = false;

    _controller.add(false);
  }

  @override
  Future<void> reauthenticateWithPassword({required String password}) async {
    operationLog.add('reauth');

    lastPassword = password;

    final gate = reauthenticationGate;

    if (gate != null) {
      await gate.future;
    }

    final error = reauthenticationError;

    if (error != null) {
      throw error;
    }
  }

  @override
  Future<void> deleteCurrentAccount() async {
    operationLog.add('delete-account');

    deleteAccountCalls++;

    authenticated = false;

    _controller.add(false);
  }

  Future<void> dispose() {
    return _controller.close();
  }
}

class _FakeAccountTrackingRepository
    implements TrackingRepository, TrackingDeletionRepository {
  _FakeAccountTrackingRepository({required this.operationLog});

  final List<String> operationLog;

  String? failingId;

  int recoverCalls = 0;

  final List<AnonymousTrackingProfile> profiles = [
    AnonymousTrackingProfile(
      anonymousId: 'seguimiento-1',
      createdAt: DateTime.utc(2026, 10, 1),
      trackingNumber: 1,
    ),
    AnonymousTrackingProfile(
      anonymousId: 'seguimiento-2',
      createdAt: DateTime.utc(2026, 10, 2),
      trackingNumber: 2,
    ),
  ];

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    recoverCalls++;

    operationLog.add('recover');

    return List.unmodifiable(profiles);
  }

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}

  @override
  Future<void> deleteProfile(String anonymousId) async {
    operationLog.add('delete:$anonymousId');

    if (anonymousId == failingId) {
      throw const TrackingFailure(
        'No fue posible eliminar '
        'el seguimiento de prueba.',
      );
    }
  }
}

class _FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  const _FakeAnonymousIdGenerator();

  @override
  String generate() {
    return 'seguimiento-generado';
  }
}
