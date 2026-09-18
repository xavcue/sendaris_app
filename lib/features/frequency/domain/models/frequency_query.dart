import '../exceptions/frequency_query_validation_failure.dart';
import '../validation/frequency_query_validator.dart';
import 'frequency_metric_type.dart';

class FrequencyQuery {
  FrequencyQuery._({
    required this.anonymousId,
    required this.metricType,
    required this.startDate,
    required this.endDate,
    required this.categoryCode,
  });

  factory FrequencyQuery.create({
    required String anonymousId,
    required FrequencyMetricType metricType,
    required DateTime startDate,
    required DateTime endDate,
    String? categoryCode,
  }) {
    final errors = FrequencyQueryValidator.validate(
      anonymousId: anonymousId,
      metricType: metricType,
      startDate: startDate,
      endDate: endDate,
      categoryCode: categoryCode,
    );

    if (errors.isNotEmpty) {
      throw FrequencyQueryValidationFailure(errors);
    }

    final normalizedCategory = categoryCode?.trim();

    return FrequencyQuery._(
      anonymousId: anonymousId.trim(),
      metricType: metricType,
      startDate: _dateOnly(startDate),
      endDate: _dateOnly(endDate),
      categoryCode: normalizedCategory == null || normalizedCategory.isEmpty
          ? null
          : normalizedCategory,
    );
  }

  final String anonymousId;

  final FrequencyMetricType metricType;

  final DateTime startDate;

  final DateTime endDate;

  final String? categoryCode;

  bool get hasCategory => categoryCode != null;

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
