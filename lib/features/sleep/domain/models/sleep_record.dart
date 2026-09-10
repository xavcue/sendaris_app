class SleepRecord {
  const SleepRecord({
    required this.recordId,
    required this.anonymousId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.observation,
  });

  final String recordId;
  final String anonymousId;

  final DateTime date;
  final String startTime;
  final String endTime;

  final int durationMinutes;
  final String? observation;

  final DateTime createdAt;
  final DateTime updatedAt;

  DateTime get startDateTime {
    return _combineDateAndTime(date, startTime);
  }

  DateTime get endDateTime {
    final start = startDateTime;

    final sameDayEnd = _combineDateAndTime(date, endTime);

    if (sameDayEnd.isAfter(start)) {
      return sameDayEnd;
    }

    return sameDayEnd.add(const Duration(days: 1));
  }

  DateTime get eventDateTime => startDateTime;

  static DateTime _combineDateAndTime(DateTime date, String time) {
    final parts = time.split(':');

    if (parts.length != 2) {
      throw const FormatException(
        'La hora del registro no tiene un formato válido.',
      );
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      throw const FormatException(
        'La hora del registro no tiene un formato válido.',
      );
    }

    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
