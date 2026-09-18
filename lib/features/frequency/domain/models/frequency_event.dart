import 'frequency_metric_type.dart';

class FrequencyEvent {
  const FrequencyEvent({
    required this.recordId,
    required this.anonymousId,
    required this.metricType,
    required this.date,
    this.categoryCode,
  });

  final String recordId;
  final String anonymousId;

  final FrequencyMetricType metricType;

  final DateTime date;

  final String? categoryCode;
}
