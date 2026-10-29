import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/frequency/data/repositories/composite_monthly_calendar_repository.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/frequency/presentation/views/monthly_calendar_view.dart';
import 'package:sendaris/features/indicators/presentation/views/indicators_view.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

void main() {
  testWidgets(
    'Indicadores mantiene tres opciones y el nombre Explorar registros',
    (tester) async {
      final repository = _FakeTrackingRepository(
        recoveredProfiles: [
          AnonymousTrackingProfile(
            anonymousId: 'seguimiento-interno-a',
            createdAt: DateTime.utc(2026, 9, 7),
            trackingNumber: 1,
          ),
        ],
      );

      final viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      addTearDown(viewModel.dispose);

      await viewModel.initialize();
      await _pumpView(tester, viewModel);

      expect(viewModel.hasActiveProfile, isTrue);

      expect(find.byKey(const Key('indicators-view')), findsOneWidget);

      expect(find.byKey(const Key('sendaris-primary-app-bar')), findsOneWidget);

      expect(
        find.byKey(const Key('sendaris-primary-app-bar-logo')),
        findsOneWidget,
      );

      expect(find.text('Sendaris'), findsOneWidget);

      expect(find.byKey(const Key('indicators-title')), findsOneWidget);

      expect(find.text('Indicadores'), findsOneWidget);

      expect(find.text('Consulta la información registrada'), findsOneWidget);

      expect(find.text('Explorar registros'), findsOneWidget);

      expect(find.text('Resumen de duraciones'), findsOneWidget);

      expect(find.text('Resumen de cumplimiento de rutinas'), findsOneWidget);

      expect(find.text('Calendario de registros'), findsNothing);
      expect(find.text('Línea temporal de registros'), findsNothing);
      expect(find.text('Cumplimiento de rutinas'), findsNothing);
      expect(find.text('INDICADORES DISPONIBLES'), findsNothing);
      expect(find.text('Frecuencias descriptivas'), findsNothing);

      expect(
        find.descendant(
          of: find.byKey(const Key('indicators-frequency-option')),
          matching: find.byIcon(Icons.manage_search_rounded),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('indicators-duration-option')),
          matching: find.byIcon(Icons.schedule_rounded),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('indicators-routine-compliance-option')),
          matching: find.byIcon(Icons.fact_check_outlined),
        ),
        findsOneWidget,
      );

      expect(find.byKey(const Key('indicators-timeline-option')), findsNothing);

      expect(find.textContaining('seguimiento-interno-a'), findsNothing);

      expect(find.textContaining('UUID'), findsNothing);
      expect(find.textContaining('identificador interno'), findsNothing);

      expect(find.textContaining('perfil activo'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('las tres tarjetas mantienen dimensiones y navegación uniforme', (
    tester,
  ) async {
    final repository = _FakeTrackingRepository(
      recoveredProfiles: [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-interno-a',
          createdAt: DateTime.utc(2026, 9, 7),
          trackingNumber: 1,
        ),
      ],
    );

    final viewModel = TrackingViewModel(
      repository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    addTearDown(viewModel.dispose);

    await viewModel.initialize();
    await _pumpView(tester, viewModel);

    const optionKeys = [
      Key('indicators-frequency-option'),
      Key('indicators-duration-option'),
      Key('indicators-routine-compliance-option'),
    ];

    for (final key in optionKeys) {
      final option = find.byKey(key);

      expect(option, findsOneWidget);

      expect(
        find.descendant(
          of: option,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is ConstrainedBox && widget.constraints.minHeight == 126,
          ),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: option,
          matching: find.byIcon(Icons.arrow_forward_rounded),
        ),
        findsOneWidget,
      );

      final inkWell = tester.widget<InkWell>(
        find.descendant(of: option, matching: find.byType(InkWell)),
      );

      expect(inkWell.onTap, isNotNull);
    }

    expect(find.byKey(const Key('indicators-timeline-option')), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sin seguimiento muestra orientación y deshabilita los indicadores',
    (tester) async {
      final repository = _FakeTrackingRepository();

      final viewModel = TrackingViewModel(
        repository,
        const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
      );

      addTearDown(viewModel.dispose);

      await viewModel.initialize();
      await _pumpView(tester, viewModel);

      expect(viewModel.hasActiveProfile, isFalse);

      final emptyMessage = find.byKey(
        const Key('indicators-no-tracking-message'),
      );

      expect(emptyMessage, findsOneWidget);

      expect(
        find.text(
          'Crea o selecciona un seguimiento '
          'desde Inicio para consultar sus indicadores.',
        ),
        findsOneWidget,
      );

      const optionKeys = [
        Key('indicators-frequency-option'),
        Key('indicators-duration-option'),
        Key('indicators-routine-compliance-option'),
      ];

      for (final key in optionKeys) {
        final option = find.byKey(key);

        expect(option, findsOneWidget);

        final inkWell = tester.widget<InkWell>(
          find.descendant(of: option, matching: find.byType(InkWell)),
        );

        expect(inkWell.onTap, isNull);

        expect(
          find.descendant(
            of: option,
            matching: find.byIcon(Icons.arrow_forward_rounded),
          ),
          findsNothing,
        );
      }

      expect(
        tester.getTopLeft(emptyMessage).dy,
        lessThan(tester.getTopLeft(find.byKey(optionKeys.first)).dy),
      );

      expect(find.byKey(const Key('indicators-timeline-option')), findsNothing);

      expect(find.textContaining('perfil activo'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Explorar registros abre ambas vistas y permite regresar', (
    tester,
  ) async {
    final trackingRepository = _FakeTrackingRepository(
      recoveredProfiles: [
        AnonymousTrackingProfile(
          anonymousId: 'seguimiento-interno-a',
          createdAt: DateTime.utc(2026, 10, 1),
          trackingNumber: 1,
        ),
      ],
    );

    final trackingViewModel = TrackingViewModel(
      trackingRepository,
      const AnonymousTrackingProfileFactory(_FakeAnonymousIdGenerator()),
    );

    addTearDown(trackingViewModel.dispose);

    await trackingViewModel.initialize();

    final calendarRepository = _FakeCalendarRepository();

    final router = GoRouter(
      initialLocation: AppRoutes.indicators,
      routes: [
        GoRoute(
          path: AppRoutes.indicators,
          builder: (context, state) => const IndicatorsView(),
        ),
        GoRoute(
          path: '/calendar',
          builder: (context, state) => MonthlyCalendarView(
            repository: calendarRepository,
            anonymousId: trackingViewModel.activeAnonymousId!,
          ),
        ),
      ],
    );

    addTearDown(router.dispose);

    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<TrackingViewModel>.value(
        value: trackingViewModel,
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('indicators-frequency-option')));

    await tester.pumpAndSettle();

    expect(find.text('Explorar registros'), findsOneWidget);

    expect(find.byKey(const Key('records-view-switch')), findsOneWidget);

    expect(find.byKey(const Key('monthly-calendar-grid')), findsOneWidget);

    expect(calendarRepository.requests, 1);

    await tester.tap(find.byKey(const Key('records-view-timeline')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('records-timeline-panel')), findsOneWidget);

    expect(calendarRepository.requests, 1);
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('indicators-view')), findsOneWidget);

    expect(find.byKey(const Key('records-view-switch')), findsNothing);

    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpView(WidgetTester tester, TrackingViewModel viewModel) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ChangeNotifierProvider<TrackingViewModel>.value(
      value: viewModel,
      child: const MaterialApp(home: IndicatorsView()),
    ),
  );

  await tester.pumpAndSettle();
}

class _FakeCalendarRepository implements MonthlyCalendarRepository {
  int requests = 0;

  @override
  Future<MonthlyCalendarIndex> recover({required String anonymousId}) async {
    requests++;

    final today = DateTime.now();

    return MonthlyCalendarIndex(
      anonymousId: anonymousId,
      records: [
        MonthlyCalendarRecord(
          id: 'registro-ficticio',
          anonymousId: anonymousId,
          date: DateTime(today.year, today.month, 15),
          type: CalendarRecordType.behavior,
          description: 'Registro de prueba',
        ),
      ],
    );
  }
}

class _FakeTrackingRepository implements TrackingRepository {
  _FakeTrackingRepository({this.recoveredProfiles = const []});

  final List<AnonymousTrackingProfile> recoveredProfiles;

  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return List.unmodifiable(recoveredProfiles);
  }
}

class _FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  const _FakeAnonymousIdGenerator();

  @override
  String generate() {
    return 'seguimiento-generado-interno';
  }
}
