import '../models/routine_compliance_entry.dart';
import '../models/routine_compliance_query.dart';
import '../models/routine_compliance_result.dart';

abstract final class RoutineComplianceCalculator {
  static RoutineComplianceResult calculate({
    required RoutineComplianceQuery query,
    required Iterable<RoutineComplianceEntry> entries,
  }) {
    final validEntries =
        entries.where((entry) {
          if (entry.anonymousId != query.anonymousId) {
            return false;
          }

          final eventDate = _dateOnly(entry.date);

          if (eventDate.isBefore(query.startDate) ||
              eventDate.isAfter(query.endDate)) {
            return false;
          }

          return true;
        }).toList()..sort((first, second) {
          final dateComparison = first.date.compareTo(second.date);

          if (dateComparison != 0) {
            return dateComparison;
          }

          return first.routineId.compareTo(second.routineId);
        });

    return RoutineComplianceResult(query: query, entries: validEntries);
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
