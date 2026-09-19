import 'duration_observation.dart';
import 'duration_query.dart';

class DurationResult {
  DurationResult._({
    required this.query,
    required this.observations,
    required this.averageMinutes,
  });

  factory DurationResult({
    required DurationQuery query,
    required Iterable<DurationObservation> observations,
  }) {
    final normalizedObservations = List<DurationObservation>.unmodifiable(
      observations,
    );

    if (normalizedObservations.isEmpty) {
      return DurationResult._(
        query: query,
        observations: normalizedObservations,
        averageMinutes: null,
      );
    }

    final totalMinutes = normalizedObservations.fold<int>(0, (
      total,
      observation,
    ) {
      return total + observation.durationMinutes!;
    });

    return DurationResult._(
      query: query,
      observations: normalizedObservations,
      averageMinutes: totalMinutes / normalizedObservations.length,
    );
  }

  final DurationQuery query;

  final List<DurationObservation> observations;

  final double? averageMinutes;

  int get validRecordCount => observations.length;

  bool get hasSufficientData =>
      observations.isNotEmpty && averageMinutes != null;
}
