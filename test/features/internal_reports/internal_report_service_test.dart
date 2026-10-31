import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/domain/services/duration_overview_service.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/internal_reports/domain/services/internal_report_service.dart';
import 'package:sendaris/features/period_comparison/domain/models/comparison_period.dart';
import 'package:sendaris/features/routine_compliance/domain/exceptions/routine_compliance_query_validation_failure.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/domain/services/routine_overview_service.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

class _FakeDurationRepository implements DurationRepository {
  _FakeDurationRepository(this.observations);

  final List<DurationObservation> observations;
  int requests = 0;

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    requests++;

    return observations
        .where((record) => record.metricType == metricType)
        .toList();
  }
}

class _FakeRoutineRepository implements RoutineComplianceRepository {
  _FakeRoutineRepository(this.entries);

  final List<RoutineComplianceEntry> entries;
  int requests = 0;

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    requests++;
    return List<RoutineComplianceEntry>.of(entries);
  }
}

class _FakeCalendarLoader {
  _FakeCalendarLoader(this.index);

  final MonthlyCalendarIndex index;
  final List<String> requestedIds = [];

  Future<MonthlyCalendarIndex> recover({required String anonymousId}) async {
    requestedIds.add(anonymousId);
    return index;
  }
}

MonthlyCalendarRecord _record({
  required String id,
  required int day,
  required CalendarRecordType type,
  String anonymousId = 'perfil-a',
  DateTime? eventDateTime,
  DateTime? createdAt,
}) {
  return MonthlyCalendarRecord(
    id: id,
    anonymousId: anonymousId,
    date: DateTime(2026, 10, day),
    eventDateTime: eventDateTime,
    createdAt: createdAt,
    type: type,
    description: type.label,
  );
}

DurationObservation _duration({
  required String id,
  required int day,
  required DurationMetricType type,
  required int minutes,
  String anonymousId = 'perfil-a',
}) {
  return DurationObservation(
    recordId: id,
    anonymousId: anonymousId,
    metricType: type,
    date: DateTime(2026, 10, day),
    durationMinutes: minutes,
  );
}

RoutineComplianceEntry _routine({
  required String id,
  required int day,
  required RoutineStatus status,
  String anonymousId = 'perfil-a',
}) {
  return RoutineComplianceEntry(
    recordId: id,
    anonymousId: anonymousId,
    routineId: 'rutina-ficticia',
    date: DateTime(2026, 10, day),
    status: status,
  );
}

ComparisonPeriod _period(int startDay, int endDay) {
  return ComparisonPeriod(
    startDate: DateTime(2026, 10, startDay),
    endDate: DateTime(2026, 10, endDay),
  );
}

InternalReportService _service({
  required _FakeCalendarLoader calendar,
  required _FakeDurationRepository durations,
  required _FakeRoutineRepository routines,
}) {
  return InternalReportService(
    calendarLoader: calendar.recover,
    durationService: DurationOverviewService(durations),
    routineService: RoutineOverviewService(routines),
  );
}

void main() {
  group('HU-16 - InternalReportService', () {
    test('consolida registros y metricas del mismo periodo', () async {
      final calendar = _FakeCalendarLoader(
        MonthlyCalendarIndex(
          anonymousId: 'perfil-a',
          records: [
            _record(id: 'sueno-1', day: 1, type: CalendarRecordType.sleep),
            _record(
              id: 'conducta-1',
              day: 7,
              type: CalendarRecordType.behavior,
              eventDateTime: DateTime(2026, 10, 7, 16),
            ),
            _record(
              id: 'estado-1',
              day: 7,
              type: CalendarRecordType.routineStatus,
            ),
            _record(
              id: 'fuera-del-periodo',
              day: 8,
              type: CalendarRecordType.feeding,
            ),
            _record(
              id: 'otro-perfil',
              day: 3,
              type: CalendarRecordType.behavior,
              anonymousId: 'perfil-b',
            ),
          ],
        ),
      );

      final durations = _FakeDurationRepository([
        _duration(
          id: 'sueno-1',
          day: 1,
          type: DurationMetricType.sleep,
          minutes: 480,
        ),
        _duration(
          id: 'sueno-2',
          day: 7,
          type: DurationMetricType.sleep,
          minutes: 600,
        ),
        _duration(
          id: 'conducta-1',
          day: 7,
          type: DurationMetricType.behavior,
          minutes: 12,
        ),
        _duration(
          id: 'otro-perfil',
          day: 3,
          type: DurationMetricType.sleep,
          minutes: 900,
          anonymousId: 'perfil-b',
        ),
      ]);

      final routines = _FakeRoutineRepository([
        _routine(id: 'estado-1', day: 1, status: RoutineStatus.completed),
        _routine(id: 'estado-2', day: 7, status: RoutineStatus.modified),
        _routine(
          id: 'fuera-del-periodo',
          day: 8,
          status: RoutineStatus.completed,
        ),
      ]);

      final report = await _service(
        calendar: calendar,
        durations: durations,
        routines: routines,
      ).generate(anonymousId: ' perfil-a ', period: _period(1, 7));

      expect(report.anonymousId, 'perfil-a');
      expect(report.period.startDate, DateTime(2026, 10, 1));
      expect(report.period.endDate, DateTime(2026, 10, 7));

      expect(report.totalRecords, 3);
      expect(report.countFor(CalendarRecordType.sleep), 1);
      expect(report.countFor(CalendarRecordType.behavior), 1);
      expect(report.countFor(CalendarRecordType.routineStatus), 1);
      expect(report.countFor(CalendarRecordType.feeding), 0);

      expect(
        report.records.map((record) => record.id),
        containsAll(['sueno-1', 'conducta-1', 'estado-1']),
      );

      expect(
        report.records.any((record) => record.id == 'fuera-del-periodo'),
        isFalse,
      );

      expect(
        report.records.any((record) => record.anonymousId != 'perfil-a'),
        isFalse,
      );

      expect(report.totalDays, 7);
      expect(report.daysWithRecords, 2);
      expect(report.coveragePercentage, closeTo(28.5714, 0.001));

      expect(report.averageMinutesFor(DurationMetricType.sleep), 540);
      expect(report.averageMinutesFor(DurationMetricType.behavior), 12);
      expect(
        report.averageMinutesFor(DurationMetricType.dysregulation),
        isNull,
      );

      expect(report.validDurationsFor(DurationMetricType.sleep), 2);
      expect(report.routineCompliancePercentage, 50);
      expect(report.routineStatusCount, 2);
      expect(report.completedRoutineCount, 1);

      expect(calendar.requestedIds, ['perfil-a']);
      expect(durations.requests, 3);
      expect(routines.requests, 1);
    });

    test('sin registros no fabrica promedios ni porcentajes', () async {
      final calendar = _FakeCalendarLoader(
        MonthlyCalendarIndex(anonymousId: 'perfil-a', records: []),
      );

      final report = await _service(
        calendar: calendar,
        durations: _FakeDurationRepository([]),
        routines: _FakeRoutineRepository([]),
      ).generate(anonymousId: 'perfil-a', period: _period(1, 7));

      expect(report.totalRecords, 0);
      expect(report.hasRecords, isFalse);
      expect(report.hasAnyInformation, isFalse);

      expect(report.totalDays, 7);
      expect(report.daysWithRecords, 0);
      expect(report.coveragePercentage, 0);

      for (final type in CalendarRecordType.values) {
        expect(report.countFor(type), 0);
      }

      for (final type in DurationMetricType.values) {
        expect(report.averageMinutesFor(type), isNull);
      }

      expect(report.routineCompliancePercentage, isNull);
    });

    test('incluye fechas extremas y evita duplicados del indice', () async {
      final calendar = _FakeCalendarLoader(
        MonthlyCalendarIndex(
          anonymousId: 'perfil-a',
          records: [
            _record(id: 'inicial', day: 1, type: CalendarRecordType.behavior),
            _record(id: 'inicial', day: 1, type: CalendarRecordType.behavior),
            _record(id: 'final', day: 7, type: CalendarRecordType.sleep),
            _record(id: 'posterior', day: 8, type: CalendarRecordType.feeding),
          ],
        ),
      );

      final report = await _service(
        calendar: calendar,
        durations: _FakeDurationRepository([]),
        routines: _FakeRoutineRepository([]),
      ).generate(anonymousId: 'perfil-a', period: _period(1, 7));

      expect(report.totalRecords, 2);
      expect(report.records.map((record) => record.id).toList(), [
        'final',
        'inicial',
      ]);
      expect(report.daysWithRecords, 2);

      expect(() => report.records.clear(), throwsUnsupportedError);

      expect(() => report.recordCounts.clear(), throwsUnsupportedError);
    });

    test('rechaza identificadores invalidos antes de recuperar', () async {
      final calendar = _FakeCalendarLoader(
        MonthlyCalendarIndex(anonymousId: 'perfil-a', records: []),
      );

      final durations = _FakeDurationRepository([]);
      final routines = _FakeRoutineRepository([]);

      await expectLater(
        _service(
          calendar: calendar,
          durations: durations,
          routines: routines,
        ).generate(anonymousId: 'perfil/incorrecto', period: _period(1, 7)),
        throwsA(isA<RoutineComplianceQueryValidationFailure>()),
      );

      expect(calendar.requestedIds, isEmpty);
      expect(durations.requests, 0);
      expect(routines.requests, 0);
    });

    test('rechaza un indice de otro seguimiento', () async {
      final calendar = _FakeCalendarLoader(
        MonthlyCalendarIndex(
          anonymousId: 'perfil-b',
          records: [
            _record(
              id: 'ajeno',
              day: 1,
              type: CalendarRecordType.sleep,
              anonymousId: 'perfil-b',
            ),
          ],
        ),
      );

      await expectLater(
        _service(
          calendar: calendar,
          durations: _FakeDurationRepository([]),
          routines: _FakeRoutineRepository([]),
        ).generate(anonymousId: 'perfil-a', period: _period(1, 7)),
        throwsStateError,
      );
    });

    test('propaga errores sin entregar reportes parciales', () async {
      var calendarRequests = 0;

      final service = InternalReportService(
        calendarLoader: ({required String anonymousId}) async {
          calendarRequests++;
          throw StateError('Recuperacion incompleta');
        },
        durationService: DurationOverviewService(_FakeDurationRepository([])),
        routineService: RoutineOverviewService(_FakeRoutineRepository([])),
      );

      await expectLater(
        service.generate(anonymousId: 'perfil-a', period: _period(1, 7)),
        throwsStateError,
      );

      expect(calendarRequests, 1);
    });
  });
}
