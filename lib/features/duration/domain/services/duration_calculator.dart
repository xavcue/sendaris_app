import '../models/duration_observation.dart';
import '../models/duration_query.dart';
import '../models/duration_result.dart';

abstract final class DurationCalculator {
  static DurationResult calculate({
    required DurationQuery query,
    required Iterable<DurationObservation> observations,
  }) {
    final validObservations = observations.where((observation) {
      if (observation.anonymousId != query.anonymousId) {
        return false;
      }

      if (observation.metricType != query.metricType) {
        return false;
      }

      final eventDate = _dateOnly(observation.date);

      if (eventDate.isBefore(query.startDate) ||
          eventDate.isAfter(query.endDate)) {
        return false;
      }

      return query.metricType.isValidDuration(observation.durationMinutes);
    }).toList()..sort((first, second) => first.date.compareTo(second.date));

    return DurationResult(query: query, observations: validObservations);
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
