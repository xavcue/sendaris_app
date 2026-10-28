import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/presentation/views/duration_view.dart';

import 'package:sendaris/features/frequency/data/repositories/composite_monthly_calendar_repository.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/frequency/presentation/views/monthly_calendar_view.dart';

import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/presentation/views/routine_compliance_view.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

class _FakeDurationRepository implements DurationRepository {
  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    final now = DateTime.now();

    final samples = <DurationObservation>[
      DurationObservation(
        recordId: 'sueno-1',
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.sleep,
        date: now,
        durationMinutes: 420,
      ),
      DurationObservation(
        recordId: 'sueno-2',
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.sleep,
        date: now,
        durationMinutes: 480,
      ),
      DurationObservation(
        recordId: 'conducta-1',
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.behavior,
        date: now,
        durationMinutes: 10,
      ),
      DurationObservation(
        recordId: 'conducta-2',
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.behavior,
        date: now,
        durationMinutes: 20,
      ),
      DurationObservation(
        recordId: 'desregulacion-1',
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.dysregulation,
        date: now,
        durationMinutes: 10,
      ),
      DurationObservation(
        recordId: 'desregulacion-2',
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.dysregulation,
        date: now,
        durationMinutes: 15,
      ),
    ];

    return List<DurationObservation>.unmodifiable(
      samples.where(
        (record) =>
            record.anonymousId == anonymousId &&
            record.metricType == metricType,
      ),
    );
  }
}

class _FakeRoutineRepository implements RoutineComplianceRepository {
  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    final today = DateTime.now();

    final samples = <RoutineComplianceEntry>[
      RoutineComplianceEntry(
        recordId: 'estado-1',
        anonymousId: 'perfil-a',
        routineId: 'rutina-1',
        routineName: 'Preparar mochila',
        date: today,
        status: RoutineStatus.completed,
      ),
      RoutineComplianceEntry(
        recordId: 'estado-2',
        anonymousId: 'perfil-a',
        routineId: 'rutina-1',
        routineName: 'Preparar mochila',
        date: today,
        status: RoutineStatus.modified,
      ),
    ];

    return List<RoutineComplianceEntry>.unmodifiable(
      samples.where((record) => record.anonymousId == anonymousId),
    );
  }
}

class _FakeCalendarRepository implements MonthlyCalendarRepository {
  @override
  Future<MonthlyCalendarIndex> recover({required String anonymousId}) async {
    final now = DateTime.now();

    final records = <MonthlyCalendarRecord>[
      MonthlyCalendarRecord(
        id: 'conducta-1',
        anonymousId: anonymousId,
        date: DateTime(now.year, now.month, 10, 9),
        type: CalendarRecordType.behavior,
        description: 'Conducta de prueba',
      ),
      MonthlyCalendarRecord(
        id: 'sueno-1',
        anonymousId: anonymousId,
        date: DateTime(now.year, now.month, 10, 21),
        type: CalendarRecordType.sleep,
        description: 'Sueño de prueba',
      ),
    ];

    return MonthlyCalendarIndex(anonymousId: anonymousId, records: records);
  }
}

void _configureScreen(
  WidgetTester tester, {
  required double width,
  required double height,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pumpAndSettle();
}

void main() {
  const screenSizes = <({String label, double width, double height})>[
    (label: 'móvil compacto', width: 360, height: 800),
    (label: 'tablet Android', width: 800, height: 1280),
  ];

  for (final screen in screenSizes) {
    group('HU-15 - ${screen.label}', () {
      testWidgets('duraciones muestran promedios, periodo y unidades', (
        tester,
      ) async {
        _configureScreen(tester, width: screen.width, height: screen.height);

        await tester.pumpWidget(
          MaterialApp(
            home: DurationView(
              repository: _FakeDurationRepository(),
              anonymousId: 'perfil-a',
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('duration-overview-period')),
          findsOneWidget,
        );

        expect(find.text('7 h 30 min'), findsOneWidget);
        expect(find.text('15 min'), findsOneWidget);
        expect(find.text('12.5 min'), findsOneWidget);

        expect(find.byKey(const Key('duration-summary-sleep')), findsOneWidget);

        expect(
          find.byKey(const Key('duration-summary-behavior')),
          findsOneWidget,
        );

        await _scrollTo(
          tester,
          find.byKey(const Key('duration-summary-dysregulation')),
        );

        expect(
          find.byKey(const Key('duration-summary-dysregulation')),
          findsOneWidget,
        );

        expect(tester.takeException(), isNull);
      });

      testWidgets('rutinas muestran porcentaje, periodo y cantidades', (
        tester,
      ) async {
        _configureScreen(tester, width: screen.width, height: screen.height);

        await tester.pumpWidget(
          MaterialApp(
            home: RoutineComplianceView(
              repository: _FakeRoutineRepository(),
              anonymousId: 'perfil-a',
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('routine-overview-selected-period')),
          findsOneWidget,
        );

        final percentageCard = find.byKey(
          const Key('routine-overview-percentage-card'),
        );

        expect(percentageCard, findsOneWidget);

        expect(
          find.descendant(of: percentageCard, matching: find.text('50 %')),
          findsOneWidget,
        );

        expect(
          find.text('1 completadas de 2 estados registrados'),
          findsOneWidget,
        );

        final progress = tester.widget<LinearProgressIndicator>(
          find.byKey(const Key('routine-overview-progress')),
        );

        expect(progress.value, closeTo(0.5, 0.000001));

        await _scrollTo(
          tester,
          find.byKey(const Key('routine-overview-status-grid')),
        );

        for (final status in RoutineStatus.values) {
          expect(
            find.byKey(Key('routine-overview-status-${status.name}')),
            findsOneWidget,
          );
        }

        expect(tester.takeException(), isNull);
      });

      testWidgets('calendario muestra conteos y cobertura legibles', (
        tester,
      ) async {
        _configureScreen(tester, width: screen.width, height: screen.height);

        await tester.pumpWidget(
          MaterialApp(
            home: MonthlyCalendarView(
              repository: _FakeCalendarRepository(),
              anonymousId: 'perfil-a',
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('monthly-calendar-month-total')),
          findsOneWidget,
        );

        final calendarCoverage = find.byKey(
          const Key('monthly-calendar-coverage-card'),
        );

        await _scrollTo(tester, calendarCoverage);

        expect(calendarCoverage, findsOneWidget);

        final current = DateTime.now();
        final totalDays = DateTime(current.year, current.month + 1, 0).day;

        expect(find.text('1 de $totalDays días con registros'), findsOneWidget);

        expect(
          find.byKey(const Key('monthly-calendar-coverage-percentage')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('monthly-calendar-coverage-period')),
          findsOneWidget,
        );

        final progress = tester.widget<LinearProgressIndicator>(
          find.byKey(const Key('monthly-calendar-coverage-progress')),
        );

        expect(progress.value, closeTo(1 / totalDays, 0.000001));

        expect(find.textContaining('mejora'), findsNothing);

        expect(find.textContaining('empeoramiento'), findsNothing);

        expect(find.textContaining('riesgo clínico'), findsNothing);

        expect(tester.takeException(), isNull);
      });
    });
  }
}
