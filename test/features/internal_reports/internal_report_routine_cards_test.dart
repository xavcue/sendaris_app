import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/domain/services/duration_overview_service.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/internal_reports/domain/models/internal_report.dart';
import 'package:sendaris/features/internal_reports/domain/services/internal_report_service.dart';
import 'package:sendaris/features/internal_reports/presentation/models/internal_report_routine_details.dart';
import 'package:sendaris/features/internal_reports/presentation/views/internal_report_view.dart';
import 'package:sendaris/features/internal_reports/presentation/widgets/internal_report_routine_detail_card.dart';
import 'package:sendaris/features/period_comparison/domain/models/comparison_period.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/domain/services/routine_overview_service.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';

class _EmptyDurations implements DurationRepository {
  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    return [];
  }
}

class _RoutineRepository implements RoutineComplianceRepository {
  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    return [
      RoutineComplianceEntry(
        recordId: 'estado-1',
        anonymousId: anonymousId,
        routineId: 'rutina-1',
        routineName: 'Preparar mochila',
        date: DateTime(2026, 10, 14),
        status: RoutineStatus.completed,
      ),
    ];
  }
}

InternalReportService _service({
  String sourceOwner = 'perfil-a',
  String sourceRoutineId = 'rutina-1',
  String? observation = '  Completada con apoyo   visual. ',
}) {
  final date = DateTime(2026, 10, 14);

  return InternalReportService(
    calendarLoader: ({required String anonymousId}) async {
      return MonthlyCalendarIndex(
        anonymousId: anonymousId,
        records: [
          MonthlyCalendarRecord(
            id: 'evento-1',
            anonymousId: anonymousId,
            date: date,
            type: CalendarRecordType.behavior,
            description: 'Conducta registrada',
          ),
          MonthlyCalendarRecord(
            id: 'estado-1',
            anonymousId: anonymousId,
            date: date,
            type: CalendarRecordType.routineStatus,
            description: 'Completada',
            sourceRecord: RoutineStatusRecord(
              recordId: 'estado-1',
              anonymousId: sourceOwner,
              routineId: sourceRoutineId,
              date: date,
              status: RoutineStatus.completed,
              observation: observation,
              createdAt: date,
              updatedAt: date,
            ),
          ),
        ],
      );
    },
    durationService: DurationOverviewService(_EmptyDurations()),
    routineService: RoutineOverviewService(_RoutineRepository()),
  );
}

Future<InternalReport> _report({
  String sourceOwner = 'perfil-a',
  String sourceRoutineId = 'rutina-1',
  String? observation = '  Completada con apoyo   visual. ',
}) {
  return _service(
    sourceOwner: sourceOwner,
    sourceRoutineId: sourceRoutineId,
    observation: observation,
  ).generate(
    anonymousId: 'perfil-a',
    period: ComparisonPeriod(
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 15),
    ),
  );
}

void main() {
  test('HU-16 recupera la observación del estado correcto', () async {
    final report = await _report();

    final details = InternalReportRoutineDetails.fromReport(report);

    expect(details.total, 1);
    expect(details.entries.single.routineName, 'Preparar mochila');
    expect(details.entries.single.status, RoutineStatus.completed);

    expect(
      InternalReportRoutineObservation.resolve(report, details.entries.single),
      'Completada con apoyo visual.',
    );
  });

  test('HU-16 no incorpora observaciones de otro seguimiento', () async {
    final report = await _report(sourceOwner: 'perfil-b');

    final details = InternalReportRoutineDetails.fromReport(report);

    expect(
      InternalReportRoutineObservation.resolve(report, details.entries.single),
      isNull,
    );
  });

  test('HU-16 no incorpora observaciones de otra rutina', () async {
    final report = await _report(sourceRoutineId: 'rutina-ajena');

    final details = InternalReportRoutineDetails.fromReport(report);

    expect(
      InternalReportRoutineObservation.resolve(report, details.entries.single),
      isNull,
    );
  });

  testWidgets('HU-16 muestra nombre, fecha, estado y observación', (
    tester,
  ) async {
    final report = await _report();

    final entry = InternalReportRoutineDetails.fromReport(report)
        .entries
        .single;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InternalReportRoutineDetailCard(report: report, entry: entry),
        ),
      ),
    );

    expect(
      find.byKey(const Key('internal-report-routine-detail-estado-1')),
      findsOneWidget,
    );

    expect(find.text('Preparar mochila'), findsOneWidget);
    expect(find.text('14/10/2026'), findsOneWidget);
    expect(find.text('Completada'), findsOneWidget);
    expect(find.text('Observación registrada'), findsOneWidget);
    expect(find.text('Completada con apoyo visual.'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 omite observaciones ausentes', (tester) async {
    final report = await _report(observation: null);

    final entry = InternalReportRoutineDetails.fromReport(report)
        .entries
        .single;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InternalReportRoutineDetailCard(report: report, entry: entry),
        ),
      ),
    );

    expect(find.text('Preparar mochila'), findsOneWidget);
    expect(find.text('Observación registrada'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 integra las rutinas en la vista del reporte', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: InternalReportView(
          service: _service(),
          anonymousId: 'perfil-a',
          clock: () => DateTime(2026, 10, 15),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('internal-report-generate-button')));

    await tester.pumpAndSettle();

    // Ambos tipos de registro permanecen en el panorama.
    expect(
      tester
          .widget<Text>(find.byKey(const Key('internal-report-total-count')))
          .data,
      '2',
    );

    final routineCard = find.byKey(
      const Key('internal-report-routine-detail-estado-1'),
    );

    await tester.scrollUntilVisible(
      routineCard,
      180,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(routineCard, findsOneWidget);
    expect(find.text('Preparar mochila'), findsOneWidget);
    expect(find.text('14/10/2026'), findsOneWidget);
    expect(find.text('Completada'), findsOneWidget);
    expect(find.text('Completada con apoyo visual.'), findsOneWidget);

    // El estado no debe aparecer como acontecimiento.
    expect(
      find.byKey(const Key('internal-report-record-routineStatus-estado-1')),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });
}
