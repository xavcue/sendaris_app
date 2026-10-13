import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/features/home/domain/models/home_activity_area.dart';
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
  testWidgets(
    'al volver a Inicio actualiza el panorama automáticamente sin loader',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final trackingRepository = _FakeTrackingRepository(
        recoveredProfiles: [
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-a',
            createdAt: DateTime(2026, 10, 12),
            trackingNumber: 1,
          ),
        ],
      );

      final trackingViewModel = TrackingViewModel(
        trackingRepository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      await trackingViewModel.initialize();

      addTearDown(trackingViewModel.dispose);

      final overviewRepository = _MutableHomeOverviewRepository(
        areas: const {HomeActivityArea.behavior, HomeActivityArea.sleep},
      );

      final homeViewModel = HomeViewModel(
        clock: _FakeHomeClock(DateTime(2026, 10, 12, 19, 30)),
        overviewRepository: overviewRepository,
        timerFactory: (_, _) => _NoopTimer(),
      );

      addTearDown(homeViewModel.dispose);

      await homeViewModel.setActiveTracking('seguimiento-a');

      final branchKey = GlobalKey<_HomeBranchHostState>();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<TrackingViewModel>.value(
              value: trackingViewModel,
            ),
            ChangeNotifierProvider<HomeViewModel>.value(value: homeViewModel),
          ],
          child: MaterialApp(
            home: _HomeBranchHost(
              key: branchKey,
              trackingViewModel: trackingViewModel,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home-overview-area-conducta')),
        findsOneWidget,
      );

      expect(find.byKey(const Key('home-overview-area-sueno')), findsOneWidget);

      expect(
        find.byKey(const Key('home-overview-area-alimentacion')),
        findsNothing,
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);

      final requestsBeforeLeaving = overviewRepository.requestCount;

      branchKey.currentState!.setBranchActive(false);

      await tester.pumpAndSettle();

      overviewRepository.areas = const {
        HomeActivityArea.behavior,
        HomeActivityArea.sleep,
        HomeActivityArea.feeding,
      };

      branchKey.currentState!.setBranchActive(true);

      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpAndSettle();

      expect(
        overviewRepository.requestCount,
        greaterThan(requestsBeforeLeaving),
      );

      expect(
        find.byKey(const Key('home-overview-area-conducta')),
        findsOneWidget,
      );

      expect(find.byKey(const Key('home-overview-area-sueno')), findsOneWidget);

      expect(
        find.byKey(const Key('home-overview-area-alimentacion')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('home-refresh-overview-button')),
        findsNothing,
      );

      expect(find.byKey(const Key('home-overview-last-updated')), findsNothing);

      expect(find.byType(CircularProgressIndicator), findsNothing);
    },
  );
}

class _HomeBranchHost extends StatefulWidget {
  const _HomeBranchHost({required this.trackingViewModel, super.key});

  final TrackingViewModel trackingViewModel;

  @override
  State<_HomeBranchHost> createState() => _HomeBranchHostState();
}

class _HomeBranchHostState extends State<_HomeBranchHost> {
  bool _isActive = true;

  void setBranchActive(bool value) {
    setState(() {
      _isActive = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: _isActive,
      child: HomePlaceholderView(trackingViewModel: widget.trackingViewModel),
    );
  }
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

class _MutableHomeOverviewRepository implements HomeOverviewRepository {
  _MutableHomeOverviewRepository({required this.areas});

  Set<HomeActivityArea> areas;

  int requestCount = 0;

  @override
  Future<HomeDayOverview> recoverDayOverview({
    required String anonymousId,
    required DateTime localDate,
  }) async {
    requestCount += 1;

    return HomeDayOverview(date: localDate, areas: areas);
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
