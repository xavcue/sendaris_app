import '../models/duration_metric_type.dart';
import '../models/duration_query.dart';
import '../models/duration_result.dart';
import '../repositories/duration_repository.dart';
import 'duration_calculator.dart';

class DurationOverview {
  DurationOverview._({
    required this.anonymousId,
    required this.startDate,
    required this.endDate,
    required Map<DurationMetricType, DurationResult> results,
  }) : results = Map.unmodifiable(results);

  final String anonymousId;
  final DateTime startDate;
  final DateTime endDate;

  final Map<DurationMetricType, DurationResult> results;

  DurationResult resultFor(DurationMetricType type) {
    return results[type]!;
  }

  bool get hasAnyData {
    return results.values.any((result) => result.hasSufficientData);
  }

  int get totalValidRecords {
    return results.values.fold<int>(
      0,
      (total, result) => total + result.validRecordCount,
    );
  }
}

class DurationOverviewService {
  const DurationOverviewService(this._repository);

  final DurationRepository _repository;

  Future<DurationOverview> load({
    required String anonymousId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final types = DurationMetricType.values;

    // Primero se validan todas las consultas.
    // Si el perfil o el periodo son inválidos,
    // no se solicita información al repositorio.
    final queries = <DurationMetricType, DurationQuery>{
      for (final type in types)
        type: DurationQuery.create(
          anonymousId: anonymousId,
          metricType: type,
          startDate: startDate,
          endDate: endDate,
        ),
    };

    final normalizedId = queries[types.first]!.anonymousId;
    final normalizedStart = queries[types.first]!.startDate;
    final normalizedEnd = queries[types.first]!.endDate;

    // Las tres recuperaciones son independientes.
    // No existe una consulta por cada registro o día.
    final observations = await Future.wait([
      for (final type in types)
        _repository.recoverObservations(
          anonymousId: normalizedId,
          metricType: type,
        ),
    ]);

    final results = <DurationMetricType, DurationResult>{};

    for (var index = 0; index < types.length; index++) {
      final type = types[index];

      results[type] = DurationCalculator.calculate(
        query: queries[type]!,
        observations: observations[index],
      );
    }

    return DurationOverview._(
      anonymousId: normalizedId,
      startDate: normalizedStart,
      endDate: normalizedEnd,
      results: results,
    );
  }
}
