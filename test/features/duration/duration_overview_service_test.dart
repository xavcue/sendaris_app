import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/duration/domain/exceptions/duration_query_validation_failure.dart';
import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/domain/services/duration_overview_service.dart';

class _FakeDurationRepository implements DurationRepository {
  _FakeDurationRepository(this.observations);

  final List<DurationObservation> observations;
  final List<String> requestedIds = [];

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    requestedIds.add(anonymousId);

    return observations.where((item) => item.metricType == metricType).toList();
  }
}

DurationObservation _observation({
  required String id,
  required DurationMetricType type,
  required DateTime date,
  required int? minutes,
  String anonymousId = 'perfil-a',
}) {
  return DurationObservation(
    recordId: id,
    anonymousId: anonymousId,
    metricType: type,
    date: date,
    durationMinutes: minutes,
  );
}

void main() {
  final start = DateTime(2026, 10, 12);
  final end = DateTime(2026, 10, 15);

  test('calcula las tres métricas con datos válidos del periodo', () async {
    final repository = _FakeDurationRepository([
      _observation(
        id: 'sleep-1',
        type: DurationMetricType.sleep,
        date: start,
        minutes: 480,
      ),
      _observation(
        id: 'sleep-2',
        type: DurationMetricType.sleep,
        date: end,
        minutes: 540,
      ),
      _observation(
        id: 'sleep-invalid',
        type: DurationMetricType.sleep,
        date: end,
        minutes: 0,
      ),
      _observation(
        id: 'sleep-other-profile',
        type: DurationMetricType.sleep,
        date: end,
        minutes: 900,
        anonymousId: 'perfil-b',
      ),
      _observation(
        id: 'sleep-outside',
        type: DurationMetricType.sleep,
        date: DateTime(2026, 10, 16),
        minutes: 600,
      ),
      _observation(
        id: 'behavior-1',
        type: DurationMetricType.behavior,
        date: start,
        minutes: 10,
      ),
      _observation(
        id: 'behavior-2',
        type: DurationMetricType.behavior,
        date: end,
        minutes: 20,
      ),
      _observation(
        id: 'behavior-null',
        type: DurationMetricType.behavior,
        date: end,
        minutes: null,
      ),
      _observation(
        id: 'dysregulation-zero',
        type: DurationMetricType.dysregulation,
        date: start,
        minutes: 0,
      ),
      _observation(
        id: 'dysregulation-1',
        type: DurationMetricType.dysregulation,
        date: end,
        minutes: 12,
      ),
      _observation(
        id: 'dysregulation-invalid',
        type: DurationMetricType.dysregulation,
        date: end,
        minutes: -1,
      ),
    ]);

    final overview = await DurationOverviewService(repository)
        .load(anonymousId: ' perfil-a ', startDate: start, endDate: end);

    final sleep = overview.resultFor(DurationMetricType.sleep);

    final behavior = overview.resultFor(DurationMetricType.behavior);

    final dysregulation = overview.resultFor(DurationMetricType.dysregulation);

    expect(overview.anonymousId, 'perfil-a');

    expect(sleep.validRecordCount, 2);
    expect(sleep.averageMinutes, 510);

    expect(behavior.validRecordCount, 2);
    expect(behavior.averageMinutes, 15);

    expect(dysregulation.validRecordCount, 2);
    expect(dysregulation.averageMinutes, 6);

    expect(overview.totalValidRecords, 6);
    expect(overview.hasAnyData, isTrue);

    expect(repository.requestedIds, hasLength(3));

    expect(repository.requestedIds.every((id) => id == 'perfil-a'), isTrue);
  });

  test('no inventa promedios cuando faltan datos', () async {
    final repository = _FakeDurationRepository([]);

    final overview = await DurationOverviewService(repository)
        .load(anonymousId: 'perfil-a', startDate: start, endDate: end);

    for (final type in DurationMetricType.values) {
      final result = overview.resultFor(type);

      expect(result.validRecordCount, 0);
      expect(result.averageMinutes, isNull);
      expect(result.hasSufficientData, isFalse);
    }

    expect(overview.hasAnyData, isFalse);
    expect(overview.totalValidRecords, 0);
  });

  test('valida el periodo antes de recuperar registros', () async {
    final repository = _FakeDurationRepository([]);

    final service = DurationOverviewService(repository);

    await expectLater(
      service.load(anonymousId: 'perfil-a', startDate: end, endDate: start),
      throwsA(isA<DurationQueryValidationFailure>()),
    );

    expect(repository.requestedIds, isEmpty);
  });

  test('rechaza perfiles inválidos antes de consultar', () async {
    final repository = _FakeDurationRepository([]);

    final service = DurationOverviewService(repository);

    await expectLater(
      service.load(anonymousId: 'perfil/a', startDate: start, endDate: end),
      throwsA(isA<DurationQueryValidationFailure>()),
    );

    expect(repository.requestedIds, isEmpty);
  });

  test('los resultados agregados son de solo lectura', () async {
    final overview = await DurationOverviewService(_FakeDurationRepository([]))
        .load(anonymousId: 'perfil-a', startDate: start, endDate: end);

    expect(() => overview.results.clear(), throwsUnsupportedError);
  });
}
