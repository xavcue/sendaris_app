import '../exceptions/routine_compliance_query_validation_failure.dart';
import '../validation/routine_compliance_query_validator.dart';

class RoutineComplianceQuery {
  RoutineComplianceQuery._({
    required this.anonymousId,
    required this.startDate,
    required this.endDate,
  });

  factory RoutineComplianceQuery.create({
    required String anonymousId,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final errors = RoutineComplianceQueryValidator.validate(
      anonymousId: anonymousId,
      startDate: startDate,
      endDate: endDate,
    );

    if (errors.isNotEmpty) {
      throw RoutineComplianceQueryValidationFailure(errors);
    }

    return RoutineComplianceQuery._(
      anonymousId: anonymousId.trim(),
      startDate: _dateOnly(startDate),
      endDate: _dateOnly(endDate),
    );
  }

  final String anonymousId;

  final DateTime startDate;

  final DateTime endDate;

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
