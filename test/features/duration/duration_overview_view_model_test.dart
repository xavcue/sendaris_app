import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/duration/domain/exceptions/duration_failure.dart';
import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/presentation/viewmodels/duration_overview_view_model.dart';

class _FakeDurationRepository implements DurationRepository {
  _FakeDurationRepository({this.observations = const [], this.error});

  final List<DurationObservation> observations;
  final Object? error;

  final List<String> requests = [];

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    requests.add('$anonymousId:${metricType.name}');

    if (error != null) {
      throw error!;
    }

    return observations
        .where((record) => record.metricType == metricType)
        .toList();
  }
}

class _DeferredDurationRepository implements DurationRepository {
  final Map<DurationMetricType, List<Completer<List<DurationObservation>>>>
  pending = {
    for (final type in DurationMetricType.values)
      type: <Completer<List<DurationObservation>>>[],
  };

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) {
    final completer = Completer<List<DurationObservation>>();

    pending[metricType]!.add(completer);

    return completer.future;
  }

  void completeRound(int round, List<DurationObservation> observations) {
    for (final type in DurationMetricType.values) {
      pending[type]![round].complete(
        observations.where((record) => record.metricType == type).toList(),
      );
    }
  }
}

DurationObservation _observation({
  required String id,
  required DurationMetricType type,
  required int? minutes,
  String anonymousId = 'perfil-a',
  DateTime? date,
}) {
  return DurationObservation(
    recordId: id,
    anonymousId: anonymousId,
    metricType: type,
    date: date ?? DateTime(2026, 10, 15),
    durationMinutes: minutes,
  );
}

DurationOverviewViewModel _createViewModel(
  DurationRepository repository, {
  String anonymousId = 'perfil-a',
}) {
  return DurationOverviewViewModel(
    repository,
    anonymousId: anonymousId,
    clock: () => DateTime(2026, 10, 15, 14, 30),
  );
}

void main() {
  group('DurationOverviewViewModel', () {
    test('inicializa el periodo desde el primer día del mes', () {
      final repository = _FakeDurationRepository();

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      expect(viewModel.selectedPeriod, DurationPeriod.thisMonth);

      expect(viewModel.startDate, DateTime(2026, 10, 1));

      expect(viewModel.endDate, DateTime(2026, 10, 15));

      expect(viewModel.overview, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);

      expect(repository.requests, isEmpty);
    });

    test('carga las tres métricas sin realizar un cálculo manual', () async {
      final repository = _FakeDurationRepository(
        observations: [
          _observation(id: 's1', type: DurationMetricType.sleep, minutes: 480),
          _observation(id: 's2', type: DurationMetricType.sleep, minutes: 540),
          _observation(
            id: 'b1',
            type: DurationMetricType.behavior,
            minutes: 10,
          ),
          _observation(
            id: 'b2',
            type: DurationMetricType.behavior,
            minutes: 20,
          ),
          _observation(
            id: 'd1',
            type: DurationMetricType.dysregulation,
            minutes: 0,
          ),
        ],
      );

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.overview, isNotNull);

      expect(viewModel.hasData, isTrue);

      expect(repository.requests, hasLength(3));

      final overview = viewModel.overview!;

      final sleep = overview.resultFor(DurationMetricType.sleep);

      final behavior = overview.resultFor(DurationMetricType.behavior);

      final dysregulation = overview.resultFor(
        DurationMetricType.dysregulation,
      );

      expect(sleep.validRecordCount, 2);
      expect(sleep.averageMinutes, 510);

      expect(behavior.validRecordCount, 2);
      expect(behavior.averageMinutes, 15);

      expect(dysregulation.validRecordCount, 1);
      expect(dysregulation.averageMinutes, 0);

      expect(overview.totalValidRecords, 5);
    });

    test('no inventa promedios cuando faltan registros válidos', () async {
      final repository = _FakeDurationRepository(
        observations: [
          _observation(
            id: 'sleep-invalid',
            type: DurationMetricType.sleep,
            minutes: 0,
          ),
          _observation(
            id: 'behavior-null',
            type: DurationMetricType.behavior,
            minutes: null,
          ),
        ],
      );

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.hasData, isFalse);

      expect(viewModel.overview, isNotNull);

      for (final type in DurationMetricType.values) {
        final result = viewModel.overview!.resultFor(type);

        expect(result.validRecordCount, 0);
        expect(result.averageMinutes, isNull);
        expect(result.hasSufficientData, isFalse);
      }
    });

    test('calcula los periodos rápidos con límites inclusivos', () async {
      final repository = _FakeDurationRepository();

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.selectPeriod(DurationPeriod.sevenDays);

      expect(viewModel.selectedPeriod, DurationPeriod.sevenDays);

      expect(viewModel.startDate, DateTime(2026, 10, 9));

      expect(viewModel.endDate, DateTime(2026, 10, 15));

      expect(repository.requests, hasLength(3));

      await viewModel.selectPeriod(DurationPeriod.thirtyDays);

      expect(viewModel.startDate, DateTime(2026, 9, 16));

      expect(viewModel.endDate, DateTime(2026, 10, 15));

      expect(repository.requests, hasLength(6));

      await viewModel.selectPeriod(DurationPeriod.thisMonth);

      expect(viewModel.startDate, DateTime(2026, 10, 1));

      expect(repository.requests, hasLength(9));
    });

    test('el periodo personalizado mantiene fechas válidas', () async {
      final repository = _FakeDurationRepository();

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.selectPeriod(DurationPeriod.custom);

      expect(viewModel.selectedPeriod, DurationPeriod.custom);

      expect(repository.requests, isEmpty);

      await viewModel.setDate(
        isStartDate: true,
        date: DateTime(2026, 11, 3, 22),
      );

      expect(viewModel.startDate, DateTime(2026, 11, 3));

      expect(viewModel.endDate, DateTime(2026, 11, 3));

      await viewModel.setDate(
        isStartDate: false,
        date: DateTime(2026, 11, 7, 8),
      );

      expect(viewModel.endDate, DateTime(2026, 11, 7));

      expect(viewModel.selectedPeriod, DurationPeriod.custom);

      expect(repository.requests, hasLength(6));
    });

    test('muestra errores controlados y descarta resultados', () async {
      const message = 'No fue posible recuperar las duraciones.';

      final repository = _FakeDurationRepository(
        error: const DurationFailure(message),
      );

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.overview, isNull);

      expect(viewModel.errorMessage, message);
      expect(viewModel.hasData, isFalse);
    });

    test('descarta una consulta antigua tras cambiar el periodo', () async {
      final repository = _DeferredDurationRepository();

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      final firstRequest = viewModel.load();

      expect(viewModel.isLoading, isTrue);

      final secondRequest = viewModel.selectPeriod(DurationPeriod.sevenDays);

      repository.completeRound(1, [
        _observation(
          id: 'nuevo',
          type: DurationMetricType.behavior,
          minutes: 9,
        ),
      ]);

      await secondRequest;

      expect(viewModel.isLoading, isFalse);

      expect(
        viewModel.overview!
            .resultFor(DurationMetricType.behavior)
            .averageMinutes,
        9,
      );

      repository.completeRound(0, [
        _observation(
          id: 'antiguo',
          type: DurationMetricType.behavior,
          minutes: 30,
        ),
      ]);

      await firstRequest;

      expect(viewModel.selectedPeriod, DurationPeriod.sevenDays);

      expect(
        viewModel.overview!
            .resultFor(DurationMetricType.behavior)
            .averageMinutes,
        9,
      );
    });

    test('descarta respuestas que llegan después de dispose', () async {
      final repository = _DeferredDurationRepository();

      final viewModel = _createViewModel(repository);

      final request = viewModel.load();

      expect(viewModel.isLoading, isTrue);

      viewModel.dispose();

      expect(viewModel.isDisposed, isTrue);

      repository.completeRound(0, [
        _observation(
          id: 'tardio',
          type: DurationMetricType.sleep,
          minutes: 480,
        ),
      ]);

      await request;

      expect(viewModel.overview, isNull);
    });

    test('no mezcla registros de seguimientos diferentes', () async {
      final repository = _FakeDurationRepository(
        observations: [
          _observation(
            id: 'perfil-a-sleep',
            type: DurationMetricType.sleep,
            minutes: 480,
            anonymousId: 'perfil-a',
          ),
          _observation(
            id: 'perfil-b-sleep',
            type: DurationMetricType.sleep,
            minutes: 600,
            anonymousId: 'perfil-b',
          ),
        ],
      );

      final viewModel = _createViewModel(repository, anonymousId: 'perfil-a');

      addTearDown(viewModel.dispose);

      await viewModel.load();

      final sleep = viewModel.overview!.resultFor(DurationMetricType.sleep);

      expect(sleep.validRecordCount, 1);
      expect(sleep.averageMinutes, 480);

      expect(viewModel.overview!.anonymousId, 'perfil-a');
    });
  });
}
