import '../exceptions/duration_query_validation_failure.dart';
import '../validation/duration_query_validator.dart';
import 'duration_metric_type.dart';

class DurationQuery {
  DurationQuery._({
    required this.anonymousId,
    required this.metricType,
    required this.startDate,
    required this.endDate,
  });

  factory DurationQuery.create({
    required String anonymousId,
    required DurationMetricType metricType,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final errors = DurationQueryValidator.validate(
      anonymousId: anonymousId,
      metricType: metricType,
      startDate: startDate,
      endDate: endDate,
    );

    if (errors.isNotEmpty) {
      throw DurationQueryValidationFailure(errors);
    }

    return DurationQuery._(
      anonymousId: anonymousId.trim(),
      metricType: metricType,
      startDate: _dateOnly(startDate),
      endDate: _dateOnly(endDate),
    );
  }

  final String anonymousId;

  final DurationMetricType metricType;

  final DateTime startDate;

  final DateTime endDate;

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
