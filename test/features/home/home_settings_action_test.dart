import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/home/domain/models/home_day_overview.dart';
import 'package:sendaris/features/home/domain/repositories/home_overview_repository.dart';
import 'package:sendaris/features/home/domain/services/home_clock.dart';
import 'package:sendaris/features/home/presentation/viewmodels/home_view_model.dart';
import 'package:sendaris/features/home/presentation/views/home_placeholder_view.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_deletion_repository.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  testWidgets('Inicio reutiliza SendarisPrimaryAppBar y abre Ajustes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1000, 1800);

    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();

      tester.view.resetDevicePixelRatio();
    });

    final trackingRepository = _FakeTrackingRepository(
      recoveredProfiles: [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-prueba',
          createdAt: DateTime(2026, 10, 9),
          trackingNumber: 1,
        ),
      ],
    );

    final trackingViewModel = TrackingViewModel(
      trackingRepository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    final homeViewModel = HomeViewModel(
      clock: _FakeHomeClock(DateTime(2026, 10, 12, 10)),
      overviewRepository: _FakeHomeOverviewRepository(),
      timerFactory: (_, _) => _NoopTimer(),
    );

    addTearDown(trackingViewModel.dispose);

    addTearDown(homeViewModel.dispose);

    final router = GoRouter(
      initialLocation: AppRoutes.home,
      routes: [
        GoRoute(
          path: AppRoutes.home,
          builder: (context, state) {
            return MultiProvider(
              providers: [
                ChangeNotifierProvider<TrackingViewModel>.value(
                  value: trackingViewModel,
                ),
                ChangeNotifierProvider<HomeViewModel>.value(
                  value: homeViewModel,
                ),
              ],
              child: HomePlaceholderView(trackingViewModel: trackingViewModel),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.settings,
          builder: (context, state) {
            return const Scaffold(
              body: Center(child: Text('Ajustes de prueba')),
            );
          },
        ),
      ],
    );

    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('sendaris-primary-app-bar')), findsOneWidget);

    expect(
      find.byKey(const Key('sendaris-primary-app-bar-logo')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('sendaris-primary-app-bar-title')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('sendaris-primary-app-bar-settings-button')),
      findsOneWidget,
    );

    expect(find.byTooltip('Ajustes'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('sendaris-primary-app-bar-settings-button')),
    );

    await tester.pumpAndSettle();

    expect(find.text('Ajustes de prueba'), findsOneWidget);
  });
}

class _FakeTrackingRepository
    implements TrackingRepository, TrackingDeletionRepository {
  _FakeTrackingRepository({this.recoveredProfiles = const []});

  final List<AnonymousTrackingProfile> recoveredProfiles;

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return List<AnonymousTrackingProfile>.unmodifiable(recoveredProfiles);
  }

  @override
  Future<void> deleteProfile(String anonymousId) async {}
}

class _FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  const _FakeAnonymousIdGenerator();

  @override
  String generate() {
    return 'seguimiento-generado-prueba';
  }
}

class _FakeHomeClock implements HomeClock {
  _FakeHomeClock(this.current);

  DateTime current;

  @override
  DateTime now() {
    return current;
  }
}

class _FakeHomeOverviewRepository implements HomeOverviewRepository {
  @override
  Future<HomeDayOverview> recoverDayOverview({
    required String anonymousId,
    required DateTime localDate,
  }) async {
    return HomeDayOverview(date: localDate, areas: const {});
  }
}

class _NoopTimer implements Timer {
  bool _isActive = true;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => 0;

  @override
  void cancel() {
    _isActive = false;
  }
}
