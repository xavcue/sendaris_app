import '../models/frequency_event.dart';
import '../models/frequency_metric_type.dart';

abstract interface class FrequencyRepository {
  Future<List<FrequencyEvent>> recoverEvents({
    required String anonymousId,
    required FrequencyMetricType metricType,
  });
}
