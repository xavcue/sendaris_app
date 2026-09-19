import '../models/duration_metric_type.dart';
import '../models/duration_observation.dart';

abstract interface class DurationRepository {
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  });
}
