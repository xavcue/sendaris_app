import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/domain/services/duration_overview_service.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/internal_reports/domain/models/internal_report.dart';
import 'package:sendaris/features/internal_reports/domain/services/internal_report_service.dart';
import 'package:sendaris/features/internal_reports/presentation/services/internal_report_pdf_service.dart';
import 'package:sendaris/features/period_comparison/domain/models/comparison_period.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/domain/services/routine_overview_service.dart';

class _EmptyDurations implements DurationRepository {
  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    return [];
  }
}

class _EmptyRoutines implements RoutineComplianceRepository {
  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    return [];
  }
}

Future<InternalReport> _buildReport({
  bool empty = false,
  int extraRecords = 0,
}) {
  const anonymousId = 'seguimiento-ficticio';

  final records = <MonthlyCalendarRecord>[];

  if (!empty) {
    records.addAll([
      MonthlyCalendarRecord(
        id: 'registro-1',
        anonymousId: anonymousId,
        date: DateTime(2026, 10, 14),
        type: CalendarRecordType.behavior,
        description: 'Agresión o irritabilidad',
      ),
      MonthlyCalendarRecord(
        id: 'registro-2',
        anonymousId: anonymousId,
        date: DateTime(2026, 10, 15),
        type: CalendarRecordType.sleep,
        description: 'Duración registrada: 8 h',
        eventDateTime: DateTime(2026, 10, 15, 22),
      ),
    ]);

    for (var index = 0; index < extraRecords; index++) {
      records.add(
        MonthlyCalendarRecord(
          id: 'extra-$index',
          anonymousId: anonymousId,
          date: DateTime(2026, 10, 1 + index % 29),
          type: CalendarRecordType.socialInteraction,
          description:
              'Observación ficticia número $index. '
              'Interacción social, comunicación y seguimiento '
              'de actividades durante el periodo.',
        ),
      );
    }
  }

  final service = InternalReportService(
    calendarLoader: ({required String anonymousId}) async {
      return MonthlyCalendarIndex(anonymousId: anonymousId, records: records);
    },
    durationService: DurationOverviewService(_EmptyDurations()),
    routineService: RoutineOverviewService(_EmptyRoutines()),
  );

  return service.generate(
    anonymousId: anonymousId,
    period: ComparisonPeriod(
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 29),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pdfService = InternalReportPdfService();

  test('HU-16 genera PDF válido con identidad visual', () async {
    final report = await _buildReport();

    expect(report.totalRecords, 2);

    final bytes = await pdfService.generate(report);

    expect(bytes.length, greaterThan(500));

    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');

    expect(
      ascii.decode(bytes.sublist(bytes.length - 6)).contains('%%EOF'),
      isTrue,
    );
  });

  test('HU-16 genera un reporte sin inventar registros', () async {
    final report = await _buildReport(empty: true);

    expect(report.totalRecords, 0);
    expect(report.records, isEmpty);

    final bytes = await pdfService.generate(report);

    expect(bytes.length, greaterThan(500));
    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');
  });

  test('HU-16 rechaza registros de otro seguimiento', () async {
    final valid = await _buildReport();

    final invalid = InternalReport(
      anonymousId: valid.anonymousId,
      period: valid.period,
      records: [
        MonthlyCalendarRecord(
          id: 'ajeno',
          anonymousId: 'otro-seguimiento',
          date: DateTime(2026, 10, 15),
          type: CalendarRecordType.behavior,
          description: 'No debe incluirse',
        ),
      ],
      coverage: valid.coverage,
      durations: valid.durations,
      routines: valid.routines,
    );

    await expectLater(pdfService.generate(invalid), throwsStateError);
  });

  test('HU-16 rechaza indicadores de otro periodo', () async {
    final valid = await _buildReport();

    final invalid = InternalReport(
      anonymousId: valid.anonymousId,
      period: ComparisonPeriod(
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 20),
      ),
      records: valid.records,
      coverage: valid.coverage,
      durations: valid.durations,
      routines: valid.routines,
    );

    await expectLater(pdfService.generate(invalid), throwsStateError);
  });

  test('HU-16 genera PDF con texto en español y tildes', () async {
    final report = await _buildReport();

    // El servicio ordena los registros por fecha descendente.
    // Identificamos el registro mediante su ID, no su posición.
    final behaviorRecord = report.records.singleWhere(
      (record) => record.id == 'registro-1',
    );

    expect(behaviorRecord.type, CalendarRecordType.behavior);

    expect(behaviorRecord.anonymousId, report.anonymousId);

    expect(behaviorRecord.description, contains('Agresión'));

    // También verificamos que el registro de sueño se conserva.
    final sleepRecord = report.records.singleWhere(
      (record) => record.id == 'registro-2',
    );

    expect(sleepRecord.description, contains('Duración'));

    // La generación debe aceptar los datos con caracteres Unicode.
    final bytes = await pdfService.generate(report);

    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');

    expect(bytes.length, greaterThan(500));
  });

  test('HU-16 admite un detalle extenso de registros', () async {
    final report = await _buildReport(extraRecords: 80);

    expect(report.totalRecords, 82);

    final bytes = await pdfService.generate(report);

    expect(ascii.decode(bytes.sublist(0, 5)), '%PDF-');

    expect(bytes.length, greaterThan(1000));
  });
}
