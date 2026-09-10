abstract final class SleepDurationCalculator {
  static final RegExp _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  static int calculate({required String startTime, required String endTime}) {
    final normalizedStart = startTime.trim();

    final normalizedEnd = endTime.trim();

    if (!_timePattern.hasMatch(normalizedStart) ||
        !_timePattern.hasMatch(normalizedEnd)) {
      throw ArgumentError(
        'Las horas deben tener un formato válido de 00:00 a 23:59.',
      );
    }

    final startMinutes = _minutesSinceMidnight(normalizedStart);

    final endMinutes = _minutesSinceMidnight(normalizedEnd);

    if (startMinutes == endMinutes) {
      throw ArgumentError(
        'La hora de finalización debe ser distinta de la hora de inicio.',
      );
    }

    if (endMinutes > startMinutes) {
      return endMinutes - startMinutes;
    }

    return (24 * 60) - startMinutes + endMinutes;
  }

  static int _minutesSinceMidnight(String time) {
    final parts = time.split(':');

    final hour = int.parse(parts[0]);

    final minute = int.parse(parts[1]);

    return (hour * 60) + minute;
  }
}
