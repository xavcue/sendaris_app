import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/indicators/presentation/views/indicators_view.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

class _FakeTrackingRepository implements TrackingRepository {
  _FakeTrackingRepository({this.profiles = const []});

  final List<AnonymousTrackingProfile> profiles;

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return List<AnonymousTrackingProfile>.unmodifiable(profiles);
  }
}

class _FakeIdGenerator implements AnonymousIdGenerator {
  const _FakeIdGenerator();

  @override
  String generate() => 'seguimiento-generado';
}

TrackingViewModel _createTrackingViewModel({bool hasTracking = true}) {
  return TrackingViewModel(
    _FakeTrackingRepository(
      profiles: hasTracking
          ? [
              AnonymousTrackingProfile(
                anonymousId: 'seguimiento-ficticio-a',
                createdAt: DateTime.utc(2026, 10, 1),
                trackingNumber: 1,
              ),
            ]
          : [],
    ),
    const AnonymousTrackingProfileFactory(_FakeIdGenerator()),
  );
}

Future<GoRouter> _pumpRouter(
  WidgetTester tester,
  TrackingViewModel trackingViewModel,
) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final router = GoRouter(
    initialLocation: AppRoutes.indicators,
    routes: [
      GoRoute(
        path: AppRoutes.indicators,
        builder: (context, state) => const IndicatorsView(),
      ),
      GoRoute(
        path: '/internal-report',
        builder: (context, state) => const Scaffold(
          key: Key('internal-report-navigation-destination'),
          body: Center(child: Text('Destino de reportes internos')),
        ),
      ),
    ],
  );

  addTearDown(router.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider<TrackingViewModel>.value(
      value: trackingViewModel,
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  await tester.pumpAndSettle();

  return router;
}

void main() {
  testWidgets('HU-16 presenta cinco tarjetas con el mismo diseno', (
    tester,
  ) async {
    final tracking = _createTrackingViewModel();
    addTearDown(tracking.dispose);

    await tracking.initialize();
    await _pumpRouter(tester, tracking);

    expect(tracking.hasActiveProfile, isTrue);

    const cardKeys = [
      Key('indicators-frequency-option'),
      Key('indicators-duration-option'),
      Key('indicators-routine-compliance-option'),
      Key('indicators-period-comparison-option'),
      Key('indicators-internal-report-option'),
    ];

    for (final key in cardKeys) {
      final card = find.byKey(key);

      expect(card, findsOneWidget);

      expect(
        find.descendant(
          of: card,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedBox && widget.constraints.minHeight == 126,
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.arrow_forward_rounded),
        ),
        findsOneWidget,
      );

      final inkWell = tester.widget<InkWell>(
        find.descendant(of: card, matching: find.byType(InkWell)),
      );

      expect(inkWell.onTap, isNotNull);
    }

    final reportCard = find.byKey(
      const Key('indicators-internal-report-option'),
    );

    expect(
      find.descendant(
        of: reportCard,
        matching: find.byIcon(Icons.description_outlined),
      ),
      findsOneWidget,
    );

    expect(find.text('Explorar registros'), findsOneWidget);
    expect(find.text('Resumen de duraciones'), findsOneWidget);
    expect(find.text('Resumen de cumplimiento de rutinas'), findsOneWidget);
    expect(find.text('Comparar periodos'), findsOneWidget);
    expect(find.text('Reportes internos'), findsOneWidget);

    expect(find.textContaining('seguimiento-ficticio-a'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 abre reportes internos y regresa a Indicadores', (
    tester,
  ) async {
    final tracking = _createTrackingViewModel();
    addTearDown(tracking.dispose);

    await tracking.initialize();

    final router = await _pumpRouter(tester, tracking);

    final reportCard = find.byKey(
      const Key('indicators-internal-report-option'),
    );

    await tester.ensureVisible(reportCard);
    await tester.pumpAndSettle();

    await tester.tap(reportCard);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('internal-report-navigation-destination')),
      findsOneWidget,
    );

    expect(find.text('Destino de reportes internos'), findsOneWidget);

    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('indicators-view')), findsOneWidget);

    expect(
      find.byKey(const Key('indicators-internal-report-option')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 deshabilita las cinco tarjetas sin seguimiento', (
    tester,
  ) async {
    final tracking = _createTrackingViewModel(hasTracking: false);

    addTearDown(tracking.dispose);

    await tracking.initialize();
    await _pumpRouter(tester, tracking);

    expect(tracking.hasActiveProfile, isFalse);

    expect(
      find.byKey(const Key('indicators-no-tracking-message')),
      findsOneWidget,
    );

    const cardKeys = [
      Key('indicators-frequency-option'),
      Key('indicators-duration-option'),
      Key('indicators-routine-compliance-option'),
      Key('indicators-period-comparison-option'),
      Key('indicators-internal-report-option'),
    ];

    for (final key in cardKeys) {
      final card = find.byKey(key);

      expect(card, findsOneWidget);

      final inkWell = tester.widget<InkWell>(
        find.descendant(of: card, matching: find.byType(InkWell)),
      );

      expect(inkWell.onTap, isNull);

      expect(
        find.descendant(
          of: card,
          matching: find.byIcon(Icons.arrow_forward_rounded),
        ),
        findsNothing,
      );
    }

    expect(
      find.byKey(const Key('internal-report-navigation-destination')),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });
}
