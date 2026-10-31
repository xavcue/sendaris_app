import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/domain/services/duration_overview_service.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/internal_reports/domain/services/internal_report_service.dart';
import 'package:sendaris/features/internal_reports/presentation/models/internal_report_display_data.dart';
import 'package:sendaris/features/period_comparison/domain/models/comparison_period.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/domain/services/routine_overview_service.dart';

class _NoDurations implements DurationRepository {
  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async => [];
}

class _NoRoutines implements RoutineComplianceRepository {
  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async => [];
}

Future<InternalReportDisplayData> _presentation(
  List<MonthlyCalendarRecord> records,
) async {
  final service = InternalReportService(
    calendarLoader: ({required String anonymousId}) async =>
        MonthlyCalendarIndex(anonymousId: anonymousId, records: records),
    durationService: DurationOverviewService(_NoDurations()),
    routineService: RoutineOverviewService(_NoRoutines()),
  );

  final report = await service.generate(
    anonymousId: 'perfil-ficticio',
    period: ComparisonPeriod(
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 29),
    ),
  );

  return InternalReportDisplayData.fromReport(report);
}

MonthlyCalendarRecord _record({
  required String id,
  required int day,
  required CalendarRecordType type,
  String description = 'Descripción ficticia',
  DateTime? eventDateTime,
}) {
  return MonthlyCalendarRecord(
    id: id,
    anonymousId: 'perfil-ficticio',
    date: DateTime(2026, 10, day),
    type: type,
    description: description,
    eventDateTime: eventDateTime,
  );
}

void main() {
  test('HU-16 presenta las categorías con una sola escala y orden', () async {
    final data = await _presentation([
      _record(id: 'c1', day: 10, type: CalendarRecordType.behavior),
      _record(id: 'c2', day: 12, type: CalendarRecordType.behavior),
      _record(id: 's1', day: 15, type: CalendarRecordType.sleep),
      _record(id: 'r1', day: 15, type: CalendarRecordType.routineStatus),
    ]);

    expect(data.totalRecords, 4);
    expect(data.categories.length, 3);
    expect(data.mostFrequentCategory?.type, CalendarRecordType.behavior);
    expect(data.categories.first.count, 2);
    expect(data.categories.first.fraction, 0.5);
    expect(data.categories.first.percentageText, '50.0 %');
    expect(data.categories[1].percentageText, '25.0 %');
    expect(data.categories[2].percentageText, '25.0 %');
    expect(
      data.categories.map((item) => item.count).reduce((a, b) => a + b),
      4,
    );
    expect(
      data.categories.any((item) => item.type == CalendarRecordType.feeding),
      isFalse,
    );
  });

  test('HU-16 conserva la misma fecha y hora del acontecimiento', () async {
    final data = await _presentation([
      _record(
        id: 'c1',
        day: 23,
        type: CalendarRecordType.behavior,
        description: 'Agresión o irritabilidad',
      ),
      _record(
        id: 's1',
        day: 15,
        type: CalendarRecordType.sleep,
        eventDateTime: DateTime(2026, 10, 15, 22),
        description: 'Duración registrada: 8 h',
      ),
    ]);

    expect(data.rows.map((row) => row.id), ['c1', 's1']);
    expect(data.rows.first.dateText, '23/10/2026');
    expect(data.rows.first.description, 'Agresión o irritabilidad');
    expect(data.rows.last.dateText, '15/10/2026 · 22:00');
    expect(data.rows.last.description, 'Duración registrada: 8 h');
  });

  test('HU-16 separa ausencia de datos del valor cero', () async {
    final data = await _presentation([]);

    expect(data.totalRecords, 0);
    expect(data.categories, isEmpty);
    expect(data.rows, isEmpty);
    expect(data.mostFrequentCategory, isNull);
    expect(data.complianceText, 'Sin datos');
    expect(data.coverageText, '0.0 %');
    expect(data.periodLabel, '01/10/2026 - 29/10/2026');
  });
}
