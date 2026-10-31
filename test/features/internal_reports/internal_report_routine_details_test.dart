import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/domain/services/duration_overview_service.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/internal_reports/domain/models/internal_report.dart';
import 'package:sendaris/features/internal_reports/domain/services/internal_report_service.dart';
import 'package:sendaris/features/internal_reports/presentation/models/internal_report_routine_details.dart';
import 'package:sendaris/features/period_comparison/domain/models/comparison_period.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/domain/services/routine_overview_service.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

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
  const _RoutineRepository(this.entries);

  final List<RoutineComplianceEntry> entries;

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    return List<RoutineComplianceEntry>.of(entries);
  }
}

RoutineComplianceEntry _entry({
  required String id,
  required String routineId,
  required int day,
  required RoutineStatus status,
  String anonymousId = 'perfil-a',
  String? name,
}) {
  return RoutineComplianceEntry(
    recordId: id,
    anonymousId: anonymousId,
    routineId: routineId,
    routineName: name,
    date: DateTime(2026, 10, day),
    status: status,
  );
}

Future<InternalReport> _report(List<RoutineComplianceEntry> entries) async {
  final service = InternalReportService(
    calendarLoader: ({required String anonymousId}) async {
      return MonthlyCalendarIndex(anonymousId: anonymousId, records: []);
    },
    durationService: DurationOverviewService(_EmptyDurations()),
    routineService: RoutineOverviewService(_RoutineRepository(entries)),
  );

  return service.generate(
    anonymousId: 'perfil-a',
    period: ComparisonPeriod(
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 29),
    ),
  );
}

void main() {
  test('HU-16 identifica nombres, fechas y estados reales', () async {
    final report = await _report([
      _entry(
        id: 'r1',
        routineId: 'aseo',
        day: 12,
        status: RoutineStatus.completed,
        name: 'Aseo personal',
      ),
      _entry(
        id: 'r2',
        routineId: 'mochila',
        day: 14,
        status: RoutineStatus.interrupted,
        name: 'Preparar mochila',
      ),
      _entry(
        id: 'r3',
        routineId: 'aseo',
        day: 11,
        status: RoutineStatus.modified,
      ),
    ]);

    final detail = InternalReportRoutineDetails.fromReport(report);

    expect(detail.total, 3);
    expect(detail.entries.first.routineName, 'Preparar mochila');
    expect(detail.entries.first.dateLabel, '14/10/2026');
    expect(detail.entries.first.status, RoutineStatus.interrupted);

    expect(detail.forStatus(RoutineStatus.completed), hasLength(1));
    expect(detail.forStatus(RoutineStatus.modified), hasLength(1));
    expect(detail.forStatus(RoutineStatus.interrupted), hasLength(1));
    expect(detail.forStatus(RoutineStatus.notCompleted), isEmpty);

    // El nombre de una rutina se recupera del agrupamiento existente
    // cuando uno de sus estados no lo trae informado.
    expect(
      detail.forStatus(RoutineStatus.modified).single.routineName,
      'Aseo personal',
    );
  });

  test('HU-16 excluye otros seguimientos y fechas', () async {
    final report = await _report([
      _entry(
        id: 'valido',
        routineId: 'aseo',
        day: 15,
        status: RoutineStatus.completed,
        name: 'Aseo personal',
      ),
      _entry(
        id: 'externo',
        routineId: 'externa',
        anonymousId: 'perfil-b',
        day: 15,
        status: RoutineStatus.modified,
        name: 'Rutina ajena',
      ),
      _entry(
        id: 'fuera',
        routineId: 'otra',
        day: 30,
        status: RoutineStatus.interrupted,
        name: 'Fuera del periodo',
      ),
    ]);

    final detail = InternalReportRoutineDetails.fromReport(report);

    expect(detail.total, 1);
    expect(detail.entries.single.recordId, 'valido');
    expect(
      detail.entries.any((entry) => entry.routineName == 'Rutina ajena'),
      isFalse,
    );
    expect(
      detail.entries.any((entry) => entry.routineName == 'Fuera del periodo'),
      isFalse,
    );
  });

  test('HU-16 maneja nombres ausentes sin inventarlos', () async {
    final report = await _report([
      _entry(
        id: 'sin-nombre',
        routineId: 'rutina-desconocida',
        day: 16,
        status: RoutineStatus.notCompleted,
      ),
    ]);

    final detail = InternalReportRoutineDetails.fromReport(report);

    expect(detail.total, 1);
    expect(detail.entries.single.routineName, 'Rutina sin nombre');
    expect(detail.entries.single.statusLabel, 'No realizada');
  });

  test('HU-16 maneja un periodo sin estados', () async {
    final report = await _report([]);

    final detail = InternalReportRoutineDetails.fromReport(report);

    expect(detail.isEmpty, isTrue);
    expect(detail.total, 0);

    for (final status in RoutineStatus.values) {
      expect(detail.forStatus(status), isEmpty);
    }
  });

  test('HU-16 mantiene el resultado inmutable', () async {
    final report = await _report([
      _entry(
        id: 'estado',
        routineId: 'aseo',
        day: 15,
        status: RoutineStatus.completed,
        name: 'Aseo',
      ),
    ]);

    final detail = InternalReportRoutineDetails.fromReport(report);

    expect(() => detail.entries.clear(), throwsUnsupportedError);
    expect(
      () => detail.forStatus(RoutineStatus.completed).clear(),
      throwsUnsupportedError,
    );
  });

  test('HU-16 rechaza asociar estados a otro seguimiento', () async {
    final valid = await _report([
      _entry(
        id: 'estado',
        routineId: 'aseo',
        day: 15,
        status: RoutineStatus.completed,
        name: 'Aseo',
      ),
    ]);

    final invalid = InternalReport(
      anonymousId: 'perfil-b',
      period: valid.period,
      records: valid.records,
      coverage: valid.coverage,
      durations: valid.durations,
      routines: valid.routines,
    );

    expect(
      () => InternalReportRoutineDetails.fromReport(invalid),
      throwsStateError,
    );
  });
}
