import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/period_comparison/domain/models/comparison_period.dart';
import 'package:sendaris/features/period_comparison/domain/services/period_comparison_service.dart';
import 'package:sendaris/features/routine_compliance/domain/exceptions/routine_compliance_failure.dart';
import 'package:sendaris/features/routine_compliance/domain/exceptions/routine_compliance_query_validation_failure.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

class _FakeDurationRepository implements DurationRepository {
  _FakeDurationRepository(this.observations);

  final List<DurationObservation> observations;
  final List<String> requests = [];

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    requests.add('$anonymousId:${metricType.name}');

    return observations.where((item) => item.metricType == metricType).toList();
  }
}

class _FakeRoutineRepository implements RoutineComplianceRepository {
  _FakeRoutineRepository({this.entries = const [], this.failure});

  final List<RoutineComplianceEntry> entries;
  final Object? failure;
  final List<String> requestedIds = [];

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    requestedIds.add(anonymousId);

    if (failure != null) {
      throw failure!;
    }

    return List<RoutineComplianceEntry>.of(entries);
  }
}

DurationObservation _duration({
  required String id,
  required DurationMetricType type,
  required int day,
  required int? minutes,
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
    routineId: 'rutina-prueba',
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

PeriodComparisonService _service(
  _FakeDurationRepository durations,
  _FakeRoutineRepository routines,
) {
  return PeriodComparisonService(
    durationRepository: durations,
    routineComplianceRepository: routines,
  );
}

void main() {
  group('HU-20 - PeriodComparisonService', () {
    test('compara las métricas originales de A y B', () async {
      final durations = _FakeDurationRepository([
        _duration(
          id: 'sleep-a1',
          type: DurationMetricType.sleep,
          day: 1,
          minutes: 480,
        ),
        _duration(
          id: 'sleep-a2',
          type: DurationMetricType.sleep,
          day: 7,
          minutes: 600,
        ),
        _duration(
          id: 'sleep-b',
          type: DurationMetricType.sleep,
          day: 8,
          minutes: 300,
        ),
        _duration(
          id: 'behavior-a',
          type: DurationMetricType.behavior,
          day: 3,
          minutes: 12,
        ),
        _duration(
          id: 'behavior-b',
          type: DurationMetricType.behavior,
          day: 14,
          minutes: 24,
        ),
        _duration(
          id: 'dysregulation-a',
          type: DurationMetricType.dysregulation,
          day: 5,
          minutes: 0,
        ),
        _duration(
          id: 'invalid-sleep',
          type: DurationMetricType.sleep,
          day: 2,
          minutes: 0,
        ),
        _duration(
          id: 'other-profile',
          type: DurationMetricType.sleep,
          day: 8,
          minutes: 900,
          anonymousId: 'perfil-b',
        ),
        _duration(
          id: 'outside-period',
          type: DurationMetricType.sleep,
          day: 15,
          minutes: 1000,
        ),
      ]);

      final routines = _FakeRoutineRepository(
        entries: [
          _routine(id: 'completed-a', day: 1, status: RoutineStatus.completed),
          _routine(id: 'modified-a', day: 7, status: RoutineStatus.modified),
          _routine(id: 'modified-b', day: 8, status: RoutineStatus.modified),
          _routine(
            id: 'other-profile',
            day: 8,
            status: RoutineStatus.completed,
            anonymousId: 'perfil-b',
          ),
        ],
      );

      final result = await _service(durations, routines).compare(
        anonymousId: ' perfil-a ',
        periodA: _period(1, 7),
        periodB: _period(8, 14),
      );

      expect(result.anonymousId, 'perfil-a');

      expect(result.periodA.averageMinutesFor(DurationMetricType.sleep), 540);
      expect(result.periodB.averageMinutesFor(DurationMetricType.sleep), 300);

      expect(result.periodA.averageMinutesFor(DurationMetricType.behavior), 12);
      expect(result.periodB.averageMinutesFor(DurationMetricType.behavior), 24);

      expect(
        result.periodA.averageMinutesFor(DurationMetricType.dysregulation),
        0,
      );
      expect(
        result.periodB.averageMinutesFor(DurationMetricType.dysregulation),
        isNull,
      );

      expect(result.periodA.validDurationsFor(DurationMetricType.sleep), 2);
      expect(result.periodB.validDurationsFor(DurationMetricType.sleep), 1);

      expect(result.periodA.routineCompliancePercentage, 50);
      expect(result.periodB.routineCompliancePercentage, 0);

      expect(result.periodA.routineStatusCount, 2);
      expect(result.periodA.completedRoutineCount, 1);

      expect(result.periodB.routineStatusCount, 1);
      expect(result.periodB.completedRoutineCount, 0);

      expect(result.hasAnyData, isTrue);

      // Los dos repositorios consultan solamente el mismo
      // identificador anonimo normalizado.
      expect(durations.requests, hasLength(6));
      expect(
        durations.requests.every((request) => request.startsWith('perfil-a:')),
        isTrue,
      );

      expect(routines.requestedIds, ['perfil-a', 'perfil-a']);
    });

    test('mantiene null cuando A no tiene datos', () async {
      final durations = _FakeDurationRepository([
        _duration(
          id: 'sleep-b',
          type: DurationMetricType.sleep,
          day: 9,
          minutes: 420,
        ),
      ]);

      final routines = _FakeRoutineRepository(
        entries: [
          _routine(id: 'completed-b', day: 10, status: RoutineStatus.completed),
        ],
      );

      final result = await _service(durations, routines).compare(
        anonymousId: 'perfil-a',
        periodA: _period(1, 7),
        periodB: _period(8, 14),
      );

      expect(result.periodA.hasAnyData, isFalse);
      expect(
        result.periodA.averageMinutesFor(DurationMetricType.sleep),
        isNull,
      );
      expect(result.periodA.routineCompliancePercentage, isNull);

      expect(result.periodB.hasAnyData, isTrue);
      expect(result.periodB.averageMinutesFor(DurationMetricType.sleep), 420);
      expect(result.periodB.routineCompliancePercentage, 100);
    });

    test('sin registros no inventa promedios ni porcentajes', () async {
      final result =
          await _service(
            _FakeDurationRepository([]),
            _FakeRoutineRepository(),
          ).compare(
            anonymousId: 'perfil-a',
            periodA: _period(1, 7),
            periodB: _period(8, 14),
          );

      for (final snapshot in [result.periodA, result.periodB]) {
        for (final type in DurationMetricType.values) {
          expect(snapshot.averageMinutesFor(type), isNull);
          expect(snapshot.validDurationsFor(type), 0);
        }

        expect(snapshot.routineCompliancePercentage, isNull);
        expect(snapshot.routineStatusCount, 0);
        expect(snapshot.hasAnyData, isFalse);
      }

      expect(result.hasAnyData, isFalse);
    });

    test('normaliza fechas y rechaza intervalos invertidos', () {
      final period = ComparisonPeriod(
        startDate: DateTime(2026, 10, 1, 23, 59),
        endDate: DateTime(2026, 10, 7, 1, 30),
      );

      expect(period.startDate, DateTime(2026, 10, 1));
      expect(period.endDate, DateTime(2026, 10, 7));

      expect(
        () => ComparisonPeriod(
          startDate: DateTime(2026, 10, 8),
          endDate: DateTime(2026, 10, 7),
        ),
        throwsArgumentError,
      );
    });

    test('rechaza identificadores inválidos sin consultar', () async {
      final durations = _FakeDurationRepository([]);
      final routines = _FakeRoutineRepository();

      await expectLater(
        _service(durations, routines).compare(
          anonymousId: 'perfil/incorrecto',
          periodA: _period(1, 7),
          periodB: _period(8, 14),
        ),
        throwsA(isA<RoutineComplianceQueryValidationFailure>()),
      );

      expect(durations.requests, isEmpty);
      expect(routines.requestedIds, isEmpty);
    });

    test('propaga errores de repositorio sin fabricar ceros', () async {
      final durations = _FakeDurationRepository([]);
      final routines = _FakeRoutineRepository(
        failure: const RoutineComplianceFailure(
          'Error controlado de recuperación.',
        ),
      );

      await expectLater(
        _service(durations, routines).compare(
          anonymousId: 'perfil-a',
          periodA: _period(1, 7),
          periodB: _period(8, 14),
        ),
        throwsA(isA<RoutineComplianceFailure>()),
      );
    });
  });
}
