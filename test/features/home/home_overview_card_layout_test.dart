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
  testWidgets(
    'Panorama de hoy presenta etiquetas completas debajo del contador',
    (tester) async {
      // Anchura equivalente a una pantalla Android compacta.
      tester.view.physicalSize = const Size(393, 1800);
      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final trackingRepository = _FakeTrackingRepository();

      final trackingViewModel = TrackingViewModel(
        trackingRepository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      await trackingViewModel.initialize();

      final homeViewModel = HomeViewModel(
        clock: _FakeHomeClock(DateTime(2026, 10, 15, 10)),
        overviewRepository: _FakeHomeOverviewRepository(),
        timerFactory: (_, _) => _NoopTimer(),
      );

      await homeViewModel.setActiveTracking('seguimiento-prueba');

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();

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

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-day-overview-card')), findsOneWidget);

      for (final area in HomeActivityArea.values) {
        final tile = find.byKey(Key('home-overview-area-${area.code}'));

        final counter = find.byKey(
          Key('home-overview-area-count-${area.code}'),
        );

        final label = find.text(area.label);

        expect(tile, findsOneWidget);
        expect(counter, findsOneWidget);

        expect(
          tester.getSize(tile).height,
          lessThanOrEqualTo(100),
          reason: 'La tarjeta de ${area.label} debe ser compacta.',
        );
        expect(label, findsOneWidget);

        final labelWidget = tester.widget<Text>(label);

        expect(
          labelWidget.maxLines,
          isNull,
          reason:
              'El nombre de ${area.label} debe poder '
              'ocupar las líneas que necesite.',
        );

        expect(
          labelWidget.overflow,
          isNot(TextOverflow.ellipsis),
          reason: 'No se debe truncar el nombre de ${area.label}.',
        );

        final counterBottom = tester.getBottomLeft(counter).dy;
        final labelTop = tester.getTopLeft(label).dy;

        expect(
          labelTop,
          greaterThan(counterBottom + 5),
          reason:
              'El nombre ${area.label} debe aparecer '
              'debajo de la fila del icono y contador.',
        );
      }

      // La primera pareja debe continuar en dos columnas.
      final behaviorTile = find.byKey(const Key('home-overview-area-conducta'));

      final sleepTile = find.byKey(const Key('home-overview-area-sueno'));

      final behaviorPosition = tester.getTopLeft(behaviorTile);
      final sleepPosition = tester.getTopLeft(sleepTile);

      expect(behaviorPosition.dy, closeTo(sleepPosition.dy, 1));

      expect(behaviorPosition.dx, lessThan(sleepPosition.dx));

      expect(tester.takeException(), isNull);
    },
  );
}

class _FakeTrackingRepository implements TrackingRepository {
  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return [
      AnonymousTrackingProfile(
        anonymousId: 'seguimiento-prueba',
        createdAt: DateTime(2026, 10, 15),
        trackingNumber: 1,
      ),
    ];
  }

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}
}

class _FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  const _FakeAnonymousIdGenerator();

  @override
  String generate() => 'seguimiento-generado';
}

class _FakeHomeClock implements HomeClock {
  _FakeHomeClock(this.current);

  final DateTime current;

  @override
  DateTime now() => current;
}

class _FakeHomeOverviewRepository implements HomeOverviewRepository {
  @override
  Future<HomeDayOverview> recoverDayOverview({
    required String anonymousId,
    required DateTime localDate,
  }) async {
    return HomeDayOverview(
      date: localDate,
      counts: {for (final area in HomeActivityArea.values) area: 2},
    );
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
