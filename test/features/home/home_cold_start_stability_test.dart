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
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  testWidgets('inicio en frío evita estados vacíos transitorios '
      'y presenta seguimiento y panorama juntos', (tester) async {
    tester.view.physicalSize = const Size(1000, 1800);

    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final trackingRepository = _DelayedTrackingRepository();

    final trackingViewModel = TrackingViewModel(
      trackingRepository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    final overviewRepository = _DelayedHomeOverviewRepository();

    final homeViewModel = HomeViewModel(
      clock: _FakeHomeClock(DateTime(2026, 10, 12, 23, 54)),
      overviewRepository: overviewRepository,
      timerFactory: (_, _) => _NoopTimer(),
    );

    void synchronizeHomeTracking() {
      unawaited(
        homeViewModel.setActiveTracking(trackingViewModel.activeAnonymousId),
      );
    }

    trackingViewModel.addListener(synchronizeHomeTracking);

    addTearDown(() {
      trackingViewModel.removeListener(synchronizeHomeTracking);

      trackingViewModel.dispose();

      homeViewModel.dispose();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TrackingViewModel>.value(
            value: trackingViewModel,
          ),
          ChangeNotifierProvider<HomeViewModel>.value(value: homeViewModel),
        ],
        child: MaterialApp(
          home: HomePlaceholderView(trackingViewModel: trackingViewModel),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Buenas noches'), findsOneWidget);

    expect(find.text('Hoy, lunes 12 de octubre'), findsOneWidget);

    expect(find.byKey(const Key('home-tracking-selector-card')), findsNothing);

    expect(find.byKey(const Key('home-day-overview-card')), findsNothing);

    expect(
      find.text('Toca para crear o seleccionar un seguimiento.'),
      findsNothing,
    );

    expect(find.byKey(const Key('home-overview-empty-state')), findsNothing);

    expect(find.byType(CircularProgressIndicator), findsNothing);

    trackingRepository.completeRecovery([
      AnonymousTrackingProfile(
        anonymousId: 'seguimiento-principal',
        createdAt: DateTime(2026, 10, 12),
        trackingNumber: 1,
      ),
    ]);

    await tester.pump();
    await tester.pump();

    expect(trackingViewModel.isInitialized, isTrue);

    expect(trackingViewModel.activeAnonymousId, 'seguimiento-principal');

    expect(homeViewModel.activeAnonymousId, 'seguimiento-principal');

    expect(overviewRepository.requestReceived, isTrue);

    expect(find.byKey(const Key('home-tracking-selector-card')), findsNothing);

    expect(find.byKey(const Key('home-day-overview-card')), findsNothing);

    expect(find.text('Seguimiento 1'), findsNothing);

    expect(
      find.text(
        'El panorama del día aparecerá aquí '
        'conforme registres información.',
      ),
      findsNothing,
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);

    overviewRepository.completeRecovery(
      HomeDayOverview(
        date: DateTime(2026, 10, 12),
        areas: const {
          HomeActivityArea.behavior,
          HomeActivityArea.sleep,
          HomeActivityArea.feeding,
        },
        counts: const {
          HomeActivityArea.behavior: 1,
          HomeActivityArea.sleep: 1,
          HomeActivityArea.feeding: 1,
        },
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('home-tracking-selector-card')),
      findsOneWidget,
    );

    expect(find.byKey(const Key('home-day-overview-card')), findsOneWidget);

    expect(find.text('Seguimiento 1'), findsOneWidget);

    expect(find.text('Conducta'), findsOneWidget);

    expect(find.text('Sueño'), findsOneWidget);

    expect(find.text('Alimentación'), findsOneWidget);

    expect(
      find.byKey(const Key('home-overview-area-count-conducta')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('home-overview-area-count-sueno')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('home-overview-area-count-alimentacion')),
      findsOneWidget,
    );

    expect(
      find.text('Toca para crear o seleccionar un seguimiento.'),
      findsNothing,
    );

    expect(
      find.text(
        'El panorama del día aparecerá aquí '
        'conforme registres información.',
      ),
      findsNothing,
    );

    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}

class _DelayedTrackingRepository implements TrackingRepository {
  final Completer<List<AnonymousTrackingProfile>> _recoveryCompleter =
      Completer<List<AnonymousTrackingProfile>>();

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() {
    return _recoveryCompleter.future;
  }

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}

  void completeRecovery(List<AnonymousTrackingProfile> profiles) {
    if (_recoveryCompleter.isCompleted) {
      throw StateError(
        'La recuperación de seguimientos '
        'ya fue completada.',
      );
    }

    _recoveryCompleter.complete(profiles);
  }
}

class _DelayedHomeOverviewRepository implements HomeOverviewRepository {
  Completer<HomeDayOverview>? _recoveryCompleter;

  bool get requestReceived {
    return _recoveryCompleter != null;
  }

  @override
  Future<HomeDayOverview> recoverDayOverview({
    required String anonymousId,
    required DateTime localDate,
  }) {
    _recoveryCompleter ??= Completer<HomeDayOverview>();

    return _recoveryCompleter!.future;
  }

  void completeRecovery(HomeDayOverview overview) {
    final completer = _recoveryCompleter;

    if (completer == null) {
      throw StateError(
        'Todavía no se ha solicitado '
        'el panorama.',
      );
    }

    if (completer.isCompleted) {
      throw StateError(
        'La recuperación del panorama '
        'ya fue completada.',
      );
    }

    completer.complete(overview);
  }
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
