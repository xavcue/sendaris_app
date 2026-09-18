import '../models/frequency_event.dart';
import '../models/frequency_query.dart';
import '../models/frequency_result.dart';

abstract final class FrequencyCalculator {
  static FrequencyResult calculate({
    required FrequencyQuery query,
    required Iterable<FrequencyEvent> events,
  }) {
    var count = 0;

    for (final event in events) {
      if (event.anonymousId != query.anonymousId) {
        continue;
      }

      if (event.metricType != query.metricType) {
        continue;
      }

      final eventDate = _dateOnly(event.date);

      if (eventDate.isBefore(query.startDate) ||
          eventDate.isAfter(query.endDate)) {
        continue;
      }

      final selectedCategory = query.categoryCode;

      if (selectedCategory != null &&
          event.categoryCode?.trim() != selectedCategory) {
        continue;
      }

      count++;
    }

    return FrequencyResult(query: query, count: count);
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
