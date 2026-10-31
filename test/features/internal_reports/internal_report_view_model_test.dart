import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/domain/services/duration_overview_service.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/internal_reports/domain/models/internal_report.dart';
import 'package:sendaris/features/internal_reports/domain/services/internal_report_service.dart';
import 'package:sendaris/features/internal_reports/presentation/viewmodels/internal_report_view_model.dart';
import 'package:sendaris/features/period_comparison/domain/models/comparison_period.dart';
import 'package:sendaris/features/routine_compliance/domain/exceptions/routine_compliance_failure.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/domain/services/routine_overview_service.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

class _FakeDurationRepository implements DurationRepository {
  _FakeDurationRepository({this.observations = const []});

  final List<DurationObservation> observations;
  final List<String> requests = [];

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    requests.add('$anonymousId:${metricType.name}');

    return observations
        .where(
          (record) =>
              record.anonymousId == anonymousId &&
              record.metricType == metricType,
        )
        .toList();
  }
}

class _FakeRoutineRepository implements RoutineComplianceRepository {
  _FakeRoutineRepository({this.entries = const []});

  final List<RoutineComplianceEntry> entries;
  final List<String> requests = [];

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    requests.add(anonymousId);

    return entries.where((entry) => entry.anonymousId == anonymousId).toList();
  }
}

class _FakeReportService implements InternalReportService {
  _FakeReportService({this.report, this.failure});

  final InternalReport? report;
  final Object? failure;

  final List<String> requestedIds = [];
  final List<ComparisonPeriod> requestedPeriods = [];

  @override
  Future<InternalReport> generate({
    required String anonymousId,
    required ComparisonPeriod period,
  }) async {
    requestedIds.add(anonymousId);
    requestedPeriods.add(period);

    if (failure != null) {
      throw failure!;
    }

    return report!;
  }
}

class _DeferredReportService implements InternalReportService {
  final List<Completer<InternalReport>> pending = [];
  final List<String> requestedIds = [];
  final List<ComparisonPeriod> requestedPeriods = [];

  @override
  Future<InternalReport> generate({
    required String anonymousId,
    required ComparisonPeriod period,
  }) {
    requestedIds.add(anonymousId);
    requestedPeriods.add(period);

    final completer = Completer<InternalReport>();
    pending.add(completer);

    return completer.future;
  }

  void complete(int index, InternalReport report) {
    pending[index].complete(report);
  }
}

ComparisonPeriod _initialPeriod() {
  return ComparisonPeriod(
    startDate: DateTime(2026, 9, 16),
    endDate: DateTime(2026, 10, 15),
  );
}

MonthlyCalendarRecord _record({
  required String id,
  required int day,
  required CalendarRecordType type,
  String anonymousId = 'perfil-a',
}) {
  return MonthlyCalendarRecord(
    id: id,
    anonymousId: anonymousId,
    date: DateTime(2026, 10, day),
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

Future<InternalReport> _makeReport({
  String anonymousId = 'perfil-a',
  ComparisonPeriod? period,
  List<MonthlyCalendarRecord> records = const [],
  List<DurationObservation> observations = const [],
  List<RoutineComplianceEntry> entries = const [],
}) {
  final durationRepository = _FakeDurationRepository(
    observations: observations,
  );

  final routineRepository = _FakeRoutineRepository(entries: entries);

  final service = InternalReportService(
    calendarLoader: ({required String anonymousId}) async {
      return MonthlyCalendarIndex(anonymousId: anonymousId, records: records);
    },
    durationService: DurationOverviewService(durationRepository),
    routineService: RoutineOverviewService(routineRepository),
  );

  return service.generate(
    anonymousId: anonymousId,
    period: period ?? _initialPeriod(),
  );
}

InternalReportViewModel _createViewModel(
  InternalReportService service, {
  String anonymousId = 'perfil-a',
}) {
  return InternalReportViewModel(
    service,
    anonymousId: anonymousId,
    clock: () => DateTime(2026, 10, 15, 14, 30),
  );
}

void main() {
  group('HU-16 - InternalReportViewModel', () {
    test('inicializa 30 dias y no consulta automaticamente', () {
      final service = _FakeReportService();

      final viewModel = _createViewModel(service);
      addTearDown(viewModel.dispose);

      expect(viewModel.period.startDate, DateTime(2026, 9, 16));
      expect(viewModel.period.endDate, DateTime(2026, 10, 15));

      expect(viewModel.anonymousId, 'perfil-a');
      expect(viewModel.report, isNull);
      expect(viewModel.hasReport, isFalse);
      expect(viewModel.hasAnyInformation, isFalse);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.isDisposed, isFalse);
      expect(viewModel.errorMessage, isNull);

      expect(service.requestedIds, isEmpty);
    });

    test('carga el reporte con registros y metricas conocidas', () async {
      final report = await _makeReport(
        records: [
          _record(id: 'sueno-1', day: 1, type: CalendarRecordType.sleep),
          _record(id: 'conducta-1', day: 14, type: CalendarRecordType.behavior),
          _record(id: 'fuera', day: 16, type: CalendarRecordType.feeding),
        ],
        observations: [
          _duration(
            id: 'sueno-1',
            day: 1,
            type: DurationMetricType.sleep,
            minutes: 480,
          ),
          _duration(
            id: 'sueno-2',
            day: 14,
            type: DurationMetricType.sleep,
            minutes: 600,
          ),
          _duration(
            id: 'conducta-1',
            day: 14,
            type: DurationMetricType.behavior,
            minutes: 12,
          ),
        ],
        entries: [
          _routine(id: 'completada', day: 1, status: RoutineStatus.completed),
          _routine(id: 'modificada', day: 14, status: RoutineStatus.modified),
        ],
      );

      final service = _FakeReportService(report: report);

      final viewModel = _createViewModel(service, anonymousId: ' perfil-a ');

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.hasReport, isTrue);
      expect(viewModel.hasAnyInformation, isTrue);

      expect(viewModel.report!.anonymousId, 'perfil-a');

      expect(viewModel.report!.totalRecords, 2);
      expect(viewModel.report!.totalDays, 30);
      expect(viewModel.report!.daysWithRecords, 2);

      expect(
        viewModel.report!.averageMinutesFor(DurationMetricType.sleep),
        540,
      );

      expect(
        viewModel.report!.averageMinutesFor(DurationMetricType.behavior),
        12,
      );

      expect(viewModel.report!.routineCompliancePercentage, 50);

      expect(service.requestedIds, ['perfil-a']);
      expect(service.requestedPeriods, hasLength(1));

      expect(service.requestedPeriods.single.startDate, DateTime(2026, 9, 16));

      expect(service.requestedPeriods.single.endDate, DateTime(2026, 10, 15));
    });

    test('sin informacion conserva un reporte sin datos', () async {
      final report = await _makeReport();

      final viewModel = _createViewModel(_FakeReportService(report: report));

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.hasReport, isTrue);
      expect(viewModel.hasAnyInformation, isFalse);
      expect(viewModel.errorMessage, isNull);

      expect(viewModel.report!.totalRecords, 0);
      expect(viewModel.report!.daysWithRecords, 0);
      expect(viewModel.report!.routineCompliancePercentage, isNull);

      for (final type in DurationMetricType.values) {
        expect(viewModel.report!.averageMinutesFor(type), isNull);
      }
    });

    test('distingue cero real de una metrica sin datos', () async {
      final report = await _makeReport(
        records: [
          _record(
            id: 'estado-1',
            day: 12,
            type: CalendarRecordType.routineStatus,
          ),
        ],
        entries: [
          _routine(id: 'estado-1', day: 12, status: RoutineStatus.modified),
        ],
      );

      final viewModel = _createViewModel(_FakeReportService(report: report));

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.hasAnyInformation, isTrue);
      expect(viewModel.report!.routineCompliancePercentage, 0);
      expect(viewModel.report!.routineStatusCount, 1);

      expect(
        viewModel.report!.averageMinutesFor(DurationMetricType.sleep),
        isNull,
      );
    });

    test('cambiar fechas elimina resultados sin volver a consultar', () async {
      final report = await _makeReport();
      final service = _FakeReportService(report: report);

      final viewModel = _createViewModel(service);
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.hasReport, isTrue);
      expect(service.requestedIds, hasLength(1));

      viewModel.setDate(
        isStartDate: true,
        date: DateTime(2026, 10, 16, 23, 40),
      );

      expect(viewModel.period.startDate, DateTime(2026, 10, 16));
      expect(viewModel.period.endDate, DateTime(2026, 10, 16));

      expect(viewModel.report, isNull);
      expect(viewModel.hasReport, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.isLoading, isFalse);

      viewModel.setDate(isStartDate: false, date: DateTime(2026, 10, 20, 8));

      expect(viewModel.period.startDate, DateTime(2026, 10, 16));
      expect(viewModel.period.endDate, DateTime(2026, 10, 20));

      expect(service.requestedIds, hasLength(1));
    });

    test('seleccionar las mismas fechas conserva el resultado', () async {
      final report = await _makeReport();

      final viewModel = _createViewModel(_FakeReportService(report: report));

      addTearDown(viewModel.dispose);

      await viewModel.load();

      final previousReport = viewModel.report;
      var notifications = 0;

      viewModel.addListener(() {
        notifications++;
      });

      viewModel.setPeriod(
        ComparisonPeriod(
          startDate: DateTime(2026, 9, 16, 20),
          endDate: DateTime(2026, 10, 15, 8),
        ),
      );

      viewModel.setDate(isStartDate: false, date: DateTime(2026, 10, 15, 22));

      expect(identical(viewModel.report, previousReport), isTrue);
      expect(viewModel.hasReport, isTrue);
      expect(notifications, 0);
    });

    test('rechaza identificadores invalidos sin acceder a datos', () async {
      var calendarRequests = 0;

      final durations = _FakeDurationRepository();
      final routines = _FakeRoutineRepository();

      final service = InternalReportService(
        calendarLoader: ({required String anonymousId}) async {
          calendarRequests++;

          return MonthlyCalendarIndex(anonymousId: anonymousId, records: []);
        },
        durationService: DurationOverviewService(durations),
        routineService: RoutineOverviewService(routines),
      );

      final viewModel = _createViewModel(
        service,
        anonymousId: 'perfil/incorrecto',
      );

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.report, isNull);
      expect(viewModel.errorMessage, isNotNull);

      expect(calendarRequests, 0);
      expect(durations.requests, isEmpty);
      expect(routines.requests, isEmpty);
    });

    test('muestra errores controlados sin reporte parcial', () async {
      const message = 'No fue posible recuperar los estados.';

      final service = _FakeReportService(
        failure: const RoutineComplianceFailure(message),
      );

      final viewModel = _createViewModel(service);
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.hasReport, isFalse);
      expect(viewModel.report, isNull);
      expect(viewModel.errorMessage, message);
    });

    test('no acepta un reporte de otro seguimiento', () async {
      final foreignReport = await _makeReport(anonymousId: 'perfil-b');

      final viewModel = _createViewModel(
        _FakeReportService(report: foreignReport),
      );

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.report, isNull);
      expect(viewModel.hasReport, isFalse);
      expect(viewModel.errorMessage, isNotNull);
      expect(viewModel.isLoading, isFalse);
    });

    test('no acepta un reporte de otro intervalo', () async {
      final wrongPeriod = ComparisonPeriod(
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 15),
      );

      final report = await _makeReport(period: wrongPeriod);

      final viewModel = _createViewModel(_FakeReportService(report: report));

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.report, isNull);
      expect(viewModel.hasReport, isFalse);
      expect(viewModel.errorMessage, isNotNull);
    });

    test('una consulta nueva prevalece sobre una anterior', () async {
      final previousReport = await _makeReport();

      final latestReport = await _makeReport(
        records: [
          _record(
            id: 'registro-nuevo',
            day: 12,
            type: CalendarRecordType.behavior,
          ),
        ],
      );

      final service = _DeferredReportService();
      final viewModel = _createViewModel(service);

      addTearDown(viewModel.dispose);

      final firstRequest = viewModel.load();
      final secondRequest = viewModel.load();

      expect(service.pending, hasLength(2));
      expect(viewModel.isLoading, isTrue);

      service.complete(1, latestReport);

      await secondRequest;

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.report, same(latestReport));
      expect(viewModel.report!.totalRecords, 1);

      service.complete(0, previousReport);

      await firstRequest;

      expect(viewModel.report, same(latestReport));
      expect(viewModel.report!.totalRecords, 1);
      expect(viewModel.errorMessage, isNull);
    });

    test('cambiar el periodo invalida una consulta pendiente', () async {
      final previousReport = await _makeReport();

      final updatedPeriod = ComparisonPeriod(
        startDate: DateTime(2026, 9, 20),
        endDate: DateTime(2026, 10, 15),
      );

      final updatedReport = await _makeReport(
        period: updatedPeriod,
        records: [
          _record(id: 'nuevo', day: 12, type: CalendarRecordType.behavior),
        ],
      );

      final service = _DeferredReportService();
      final viewModel = _createViewModel(service);

      addTearDown(viewModel.dispose);

      final previousRequest = viewModel.load();

      expect(viewModel.isLoading, isTrue);

      viewModel.setPeriod(updatedPeriod);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.report, isNull);

      service.complete(0, previousReport);

      await previousRequest;

      expect(viewModel.report, isNull);
      expect(viewModel.hasReport, isFalse);

      final updatedRequest = viewModel.load();

      expect(viewModel.isLoading, isTrue);
      expect(service.pending, hasLength(2));

      service.complete(1, updatedReport);

      await updatedRequest;

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.report, same(updatedReport));

      expect(viewModel.period.startDate, DateTime(2026, 9, 20));
    });

    test('ignora respuestas posteriores a dispose', () async {
      final report = await _makeReport();

      final service = _DeferredReportService();
      final viewModel = _createViewModel(service);

      final pendingRequest = viewModel.load();

      expect(viewModel.isLoading, isTrue);

      viewModel.dispose();

      service.complete(0, report);

      await pendingRequest;

      expect(viewModel.isDisposed, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.report, isNull);
      expect(viewModel.errorMessage, isNull);
    });
  });
}
