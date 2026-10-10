import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/router/app_routes.dart';
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
  testWidgets('cancelar el cierre mantiene la sesión activa', (tester) async {
    final fixture = await _pumpSessionSettings(tester);

    await _openSignOut(tester);

    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    expect(fixture.authRepository.signOutCalls, 0);

    await tester.tap(find.text('Cancelar'));

    await tester.pumpAndSettle();

    expect(find.text('¿Cerrar sesión?'), findsNothing);

    expect(fixture.authRepository.signOutCalls, 0);

    expect(fixture.authViewModel.isAuthenticated, isTrue);

    expect(find.byKey(const Key('settings-sign-out-action')), findsOneWidget);
  });

  testWidgets('confirmar cierre redirige a Login y limpia tracking local', (
    tester,
  ) async {
    final fixture = await _pumpSessionSettings(tester);

    expect(fixture.trackingViewModel.profiles, isNotEmpty);

    await _openSignOut(tester);

    await tester.tap(find.byKey(const Key('settings-confirm-sign-out-button')));

    await tester.pumpAndSettle();

    expect(fixture.authRepository.signOutCalls, 1);

    expect(fixture.authViewModel.isAuthenticated, isFalse);

    expect(fixture.trackingViewModel.profiles, isEmpty);

    expect(fixture.trackingViewModel.activeProfile, isNull);

    expect(find.text('Inicio de sesión de prueba'), findsOneWidget);

    expect(find.text('Ajustes'), findsNothing);
  });
}

Future<_SessionFixture> _pumpSessionSettings(WidgetTester tester) async {
  final authRepository = _FakeSessionAuthRepository();

  final authViewModel = AuthViewModel(authRepository);

  final trackingRepository = _FakeSessionTrackingRepository();

  final trackingViewModel = TrackingViewModel(
    trackingRepository,
    const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
  );

  final initialized = await trackingViewModel.initialize();

  expect(initialized, isTrue);

  final themeModeController = ThemeModeController();

  final router = GoRouter(
    initialLocation: AppRoutes.settings,
    refreshListenable: authViewModel,
    redirect: (context, state) {
      final authenticated = authViewModel.isAuthenticated;

      final goingToLogin = state.matchedLocation == AppRoutes.login;

      if (!authenticated) {
        return goingToLogin ? null : AppRoutes.login;
      }

      if (goingToLogin) {
        return AppRoutes.settings;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) {
          return const SettingsView();
        },
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) {
          return const Scaffold(
            body: Center(child: Text('Inicio de sesión de prueba')),
          );
        },
      ),
    ],
  );

  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());

    await tester.pump();

    router.dispose();

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
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.pumpAndSettle();

  return _SessionFixture(
    authRepository: authRepository,
    authViewModel: authViewModel,
    trackingViewModel: trackingViewModel,
  );
}

Future<void> _openSignOut(WidgetTester tester) async {
  final action = find.byKey(const Key('settings-sign-out-action'));

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

class _SessionFixture {
  const _SessionFixture({
    required this.authRepository,
    required this.authViewModel,
    required this.trackingViewModel,
  });

  final _FakeSessionAuthRepository authRepository;

  final AuthViewModel authViewModel;

  final TrackingViewModel trackingViewModel;
}

class _FakeSessionAuthRepository implements AuthRepository {
  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );

  bool authenticated = true;

  int signOutCalls = 0;

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
    signOutCalls++;

    authenticated = false;

    _controller.add(false);
  }

  Future<void> dispose() {
    return _controller.close();
  }
}

class _FakeSessionTrackingRepository
    implements TrackingRepository, TrackingDeletionRepository {
  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return [
      AnonymousTrackingProfile(
        anonymousId: 'seguimiento-sesion',
        createdAt: DateTime.utc(2026, 10, 9),
        trackingNumber: 1,
      ),
    ];
  }

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}

  @override
  Future<void> deleteProfile(String anonymousId) async {}
}

class _FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  const _FakeAnonymousIdGenerator();

  @override
  String generate() {
    return 'seguimiento-generado';
  }
}
