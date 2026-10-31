import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/domain/services/duration_overview_service.dart';
import 'package:sendaris/features/duration/presentation/widgets/duration_summary_cards.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/internal_reports/domain/services/internal_report_service.dart';
import 'package:sendaris/features/internal_reports/presentation/models/internal_report_display_data.dart';
import 'package:sendaris/features/internal_reports/presentation/models/internal_report_routine_details.dart';
import 'package:sendaris/features/internal_reports/presentation/services/internal_report_pdf_service.dart';
import 'package:sendaris/features/period_comparison/domain/models/comparison_period.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/domain/services/routine_overview_service.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

class _DurationRepository implements DurationRepository {
  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    final values = <DurationObservation>[
      DurationObservation(
        recordId: 'sueno-1',
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.sleep,
        date: DateTime(2026, 9, 9),
        durationMinutes: 480,
      ),
      DurationObservation(
        recordId: 'sueno-2',
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.sleep,
        date: DateTime(2026, 10, 15),
        durationMinutes: 450,
      ),
    ];

    return values
        .where(
          (item) =>
              item.anonymousId == anonymousId && item.metricType == metricType,
        )
        .toList(growable: false);
  }
}

class _RoutineRepository implements RoutineComplianceRepository {
  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    final entries = <RoutineComplianceEntry>[
      RoutineComplianceEntry(
        recordId: 'estado-1',
        anonymousId: 'perfil-a',
        routineId: 'rutina-1',
        routineName: 'Preparar mochila',
        date: DateTime(2026, 10, 14),
        status: RoutineStatus.interrupted,
      ),
      RoutineComplianceEntry(
        recordId: 'estado-2',
        anonymousId: 'perfil-a',
        routineId: 'rutina-1',
        routineName: 'Preparar mochila',
        date: DateTime(2026, 10, 15),
        status: RoutineStatus.completed,
      ),
      RoutineComplianceEntry(
        recordId: 'estado-3',
        anonymousId: 'perfil-a',
        routineId: 'rutina-2',
        routineName: 'Rutina de prueba',
        date: DateTime(2026, 10, 16),
        status: RoutineStatus.completed,
      ),
    ];

    return entries
        .where((entry) => entry.anonymousId == anonymousId)
        .toList(growable: false);
  }
}

MonthlyCalendarIndex _calendar() {
  return MonthlyCalendarIndex(
    anonymousId: 'perfil-a',
    records: [
      MonthlyCalendarRecord(
        id: 'conducta-1',
        anonymousId: 'perfil-a',
        date: DateTime(2026, 10, 15),
        type: CalendarRecordType.behavior,
        description: 'Conducta registrada',
      ),
      MonthlyCalendarRecord(
        id: 'sueno-1',
        anonymousId: 'perfil-a',
        date: DateTime(2026, 9, 9),
        type: CalendarRecordType.sleep,
        description: 'Sueño registrado',
      ),
      MonthlyCalendarRecord(
        id: 'estado-1',
        anonymousId: 'perfil-a',
        date: DateTime(2026, 10, 14),
        type: CalendarRecordType.routineStatus,
        description: 'Interrumpida',
      ),
      MonthlyCalendarRecord(
        id: 'estado-2',
        anonymousId: 'perfil-a',
        date: DateTime(2026, 10, 15),
        type: CalendarRecordType.routineStatus,
        description: 'Completada',
      ),
      MonthlyCalendarRecord(
        id: 'estado-3',
        anonymousId: 'perfil-a',
        date: DateTime(2026, 10, 16),
        type: CalendarRecordType.routineStatus,
        description: 'Completada',
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HU-16 - Consistencia integral', () {
    test(
      'aplicación y PDF comparten cantidades, categorías y rutinas',
      () async {
        var calendarLoads = 0;
        var durationLoads = 0;
        var routineLoads = 0;

        final service = InternalReportService(
          calendarLoader: ({required String anonymousId}) async {
            calendarLoads++;

            expect(anonymousId, 'perfil-a');

            return _calendar();
          },
          durationService: DurationOverviewService(
            _CountingDurationRepository(onLoad: () => durationLoads++),
          ),
          routineService: RoutineOverviewService(
            _CountingRoutineRepository(onLoad: () => routineLoads++),
          ),
        );

        final report = await service.generate(
          anonymousId: 'perfil-a',
          period: ComparisonPeriod(
            startDate: DateTime(2026, 9, 1),
            endDate: DateTime(2026, 10, 31),
          ),
        );

        // Resultado único consolidado.
        expect(report.totalRecords, 5);
        expect(report.countFor(CalendarRecordType.behavior), 1);
        expect(report.countFor(CalendarRecordType.sleep), 1);
        expect(report.countFor(CalendarRecordType.routineStatus), 3);

        expect(report.daysWithRecords, 4);
        expect(report.totalDays, 61);

        expect(report.routineStatusCount, 3);
        expect(report.completedRoutineCount, 2);

        expect(report.routineCompliancePercentage, closeTo(66.6666667, 0.0001));

        // Proyección utilizada por el PDF.
        final display = InternalReportDisplayData.fromReport(report);
        final routines = InternalReportRoutineDetails.fromReport(report);

        expect(display.totalRecords, report.totalRecords);
        expect(display.daysWithRecords, report.daysWithRecords);
        expect(display.totalDays, report.totalDays);
        expect(display.completedRoutineCount, report.completedRoutineCount);
        expect(display.routineStatusCount, report.routineStatusCount);

        expect(display.rows, hasLength(5));
        expect(routines.total, 3);
        expect(routines.entries, hasLength(3));

        // El detalle de eventos excluye los estados de rutina.
        final appEventIds = report.records
            .where((record) => record.type != CalendarRecordType.routineStatus)
            .map((record) => record.id)
            .toSet();

        final pdfEventIds = display.rows
            .where((row) => row.type != CalendarRecordType.routineStatus)
            .map((row) => row.record.id)
            .toSet();

        expect(appEventIds, hasLength(2));
        expect(pdfEventIds, appEventIds);

        // Los tres estados aparecen en su propio detalle,
        // sin duplicarse dentro del historial de eventos.
        final routineIds = routines.entries
            .map((entry) => entry.recordId)
            .toSet();

        expect(routineIds, {'estado-1', 'estado-2', 'estado-3'});

        expect(appEventIds.intersection(routineIds), isEmpty);

        // Los promedios conservan la misma representación
        // que consumen los widgets y el servicio PDF.
        expect(report.averageMinutesFor(DurationMetricType.sleep), 465);

        expect(
          DurationSummaryCards.formatDuration(
            DurationMetricType.sleep,
            report.averageMinutesFor(DurationMetricType.sleep)!,
          ),
          '7 h 45 min',
        );

        // Generar el PDF no debe volver a consultar repositorios.
        final previousCalendarLoads = calendarLoads;
        final previousDurationLoads = durationLoads;
        final previousRoutineLoads = routineLoads;

        final bytes = await const InternalReportPdfService().generate(
          report,
          trackingNumber: 1,
        );

        expect(bytes.length, greaterThan(100));

        // Firma PDF: %PDF-
        expect(bytes.sublist(0, 5), [0x25, 0x50, 0x44, 0x46, 0x2D]);

        expect(calendarLoads, previousCalendarLoads);
        expect(durationLoads, previousDurationLoads);
        expect(routineLoads, previousRoutineLoads);
      },
    );
  });
}

class _CountingDurationRepository extends _DurationRepository {
  _CountingDurationRepository({required this.onLoad});

  final void Function() onLoad;

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) {
    onLoad();

    return super.recoverObservations(
      anonymousId: anonymousId,
      metricType: metricType,
    );
  }
}

class _CountingRoutineRepository extends _RoutineRepository {
  _CountingRoutineRepository({required this.onLoad});

  final void Function() onLoad;

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) {
    onLoad();

    return super.recoverEntries(anonymousId: anonymousId);
  }
}
