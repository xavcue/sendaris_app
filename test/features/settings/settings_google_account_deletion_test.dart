import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sendaris/app/theme/theme_mode_controller.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
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
  testWidgets('Google no solicita contraseña para eliminar', (tester) async {
    final fixture = await _pumpSettings(tester);

    await _startDeletion(tester);

    expect(
      find.byKey(const Key('settings-delete-account-password-dialog')),
      findsNothing,
    );

    expect(fixture.authRepository.passwordCalls, 0);

    expect(fixture.operationLog, [
      'google-reauth:uid-a',
      'recover:uid-a',
      'delete:uid-a:seguimiento-a',
      'delete-account:uid-a',
    ]);

    expect(fixture.authViewModel.isAuthenticated, isFalse);
  });

  testWidgets('cancelar Google conserva todos los datos', (tester) async {
    final fixture = await _pumpSettings(tester);

    fixture.authRepository.googleResult = false;

    await _startDeletion(tester);

    expect(fixture.operationLog, ['google-reauth:uid-a']);

    expect(fixture.trackingRepository.deletedProfiles, isEmpty);
    expect(fixture.authRepository.deleteCalls, 0);

    expect(fixture.authViewModel.isAuthenticated, isTrue);
    expect(fixture.authViewModel.errorMessage, isNull);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Google rechazado no autoriza la eliminación', (tester) async {
    final fixture = await _pumpSettings(tester);

    fixture.authRepository.googleError = const AuthFailure(
      'La cuenta de Google seleccionada no coincide '
      'con la cuenta actual.',
    );

    await _startDeletion(tester);

    expect(fixture.operationLog, ['google-reauth:uid-a']);

    expect(fixture.trackingRepository.deletedProfiles, isEmpty);
    expect(fixture.authRepository.deleteCalls, 0);

    expect(
      find.textContaining('no coincide con la cuenta actual'),
      findsOneWidget,
    );
  });

  testWidgets('cambiar de A a B durante Google no elimina B', (tester) async {
    final gate = Completer<bool>();

    final fixture = await _pumpSettings(tester);
    fixture.authRepository.googleGate = gate;

    await _startDeletion(tester, waitForCompletion: false);

    expect(fixture.operationLog, ['google-reauth:uid-a']);

    fixture.changeIdentity('uid-b');

    await tester.pump();

    gate.complete(true);

    await tester.pumpAndSettle();

    expect(fixture.operationLog, ['google-reauth:uid-a']);
    expect(fixture.trackingRepository.deletedProfiles, isEmpty);
    expect(fixture.authRepository.deleteCalls, 0);
    expect(fixture.authViewModel.currentUserId, 'uid-b');
  });

  testWidgets('cambio A-B-A invalida la confirmación Google', (tester) async {
    final gate = Completer<bool>();

    final fixture = await _pumpSettings(tester);
    fixture.authRepository.googleGate = gate;

    await _startDeletion(tester, waitForCompletion: false);

    fixture.changeIdentity('uid-b');
    fixture.changeIdentity('uid-a');

    await tester.pump();

    gate.complete(true);

    await tester.pumpAndSettle();

    expect(fixture.operationLog, ['google-reauth:uid-a']);
    expect(fixture.trackingRepository.deletedProfiles, isEmpty);
    expect(fixture.authRepository.deleteCalls, 0);
    expect(fixture.authViewModel.currentUserId, 'uid-a');
  });
}

Future<_Fixture> _pumpSettings(WidgetTester tester) async {
  final operationLog = <String>[];

  final authRepository = _FakeGoogleAccountRepository(
    operationLog: operationLog,
  );

  final authViewModel = AuthViewModel(authRepository);

  final trackingRepository = _FakeTrackingRepository(
    authRepository: authRepository,
    operationLog: operationLog,
  );

  final trackingViewModel = TrackingViewModel(
    trackingRepository,
    const AnonymousTrackingProfileFactory(_FakeIdGenerator()),
  );

  trackingViewModel.synchronizeAuthenticationContext(
    authRepository.currentUserId,
  );

  final themeController = ThemeModeController();

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    authViewModel.dispose();
    trackingViewModel.dispose();
    themeController.dispose();

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
          value: themeController,
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

Future<void> _startDeletion(
  WidgetTester tester, {
  bool waitForCompletion = true,
}) async {
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

  await tester.pump();

  if (waitForCompletion) {
    await tester.pumpAndSettle();
  }
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
  final _FakeGoogleAccountRepository authRepository;
  final AuthViewModel authViewModel;
  final _FakeTrackingRepository trackingRepository;
  final TrackingViewModel trackingViewModel;

  void changeIdentity(String uid) {
    authRepository.changeIdentity(uid);
    trackingViewModel.synchronizeAuthenticationContext(uid);
  }
}

class _FakeGoogleAccountRepository
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthGoogleAccountManagementRepository,
        AuthAccountManagementRepository {
  _FakeGoogleAccountRepository({required this.operationLog});

  final List<String> operationLog;

  final StreamController<bool> _authChanges = StreamController<bool>.broadcast(
    sync: true,
  );

  final StreamController<String?> _identityChanges =
      StreamController<String?>.broadcast(sync: true);

  String? _uid = 'uid-a';

  bool googleResult = true;
  Object? googleError;
  Completer<bool>? googleGate;

  int passwordCalls = 0;
  int deleteCalls = 0;

  @override
  bool get isAuthenticated => _uid != null;

  @override
  String? get currentUserId => _uid;

  @override
  Stream<bool> get authStateChanges => _authChanges.stream;

  @override
  Stream<String?> get userIdChanges => _identityChanges.stream;

  @override
  bool get canReauthenticateWithGoogle => _uid != null;

  void changeIdentity(String? uid) {
    _uid = uid;

    _identityChanges.add(uid);
    _authChanges.add(uid != null);
  }

  @override
  Future<bool> reauthenticateWithGoogle() async {
    operationLog.add('google-reauth:$_uid');

    final gate = googleGate;

    if (gate != null) {
      return gate.future;
    }

    final error = googleError;

    if (error != null) {
      throw error;
    }

    return googleResult;
  }

  @override
  Future<void> reauthenticateWithPassword({required String password}) async {
    passwordCalls++;
    throw StateError('No debe solicitar contraseña para Google.');
  }

  @override
  Future<void> deleteCurrentAccount() async {
    operationLog.add('delete-account:$_uid');
    deleteCalls++;
    changeIdentity(null);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    changeIdentity('uid-password');
  }

  @override
  Future<void> signOut() async {
    changeIdentity(null);
  }

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}

class _FakeTrackingRepository
    implements TrackingRepository, TrackingDeletionRepository {
  _FakeTrackingRepository({
    required this.authRepository,
    required this.operationLog,
  });

  final _FakeGoogleAccountRepository authRepository;
  final List<String> operationLog;

  final List<String> deletedProfiles = [];

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    final uid = authRepository.currentUserId;

    operationLog.add('recover:$uid');

    if (uid == null) {
      return [];
    }

    return [
      AnonymousTrackingProfile(
        anonymousId: uid == 'uid-a' ? 'seguimiento-a' : 'seguimiento-b',
        createdAt: DateTime.utc(2026, 10, 16),
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
    deletedProfiles.add('$uid:$anonymousId');
  }
}

class _FakeIdGenerator implements AnonymousIdGenerator {
  const _FakeIdGenerator();

  @override
  String generate() => 'seguimiento-generado';
}
