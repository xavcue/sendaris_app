import 'duration_metric_type.dart';

class DurationObservation {
  const DurationObservation({
    required this.recordId,
    required this.anonymousId,
    required this.metricType,
    required this.date,
    required this.durationMinutes,
  });

  final String recordId;

  final String anonymousId;

  final DurationMetricType metricType;

  final DateTime date;

  final int? durationMinutes;
}
