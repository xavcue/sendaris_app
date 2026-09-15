import 'dysregulation_intensity.dart';

class DysregulationRecord {
  const DysregulationRecord({
    required this.recordId,
    required this.anonymousId,
    required this.date,
    required this.createdAt,
    required this.updatedAt,
    this.time,
    this.durationMinutes,
    this.intensity,
    this.context,
    this.observation,
  });

  final String recordId;
  final String anonymousId;

  final DateTime date;
  final String? time;

  final int? durationMinutes;
  final DysregulationIntensity? intensity;
  final String? context;
  final String? observation;

  final DateTime createdAt;
  final DateTime updatedAt;

  DateTime get eventDateTime {
    final currentTime = time;

    if (currentTime == null) {
      return DateTime(date.year, date.month, date.day);
    }

    final parts = currentTime.split(':');

    if (parts.length != 2) {
      throw const FormatException(
        'La hora del episodio no tiene un formato válido.',
      );
    }

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      throw const FormatException(
        'La hora del episodio no tiene un formato válido.',
      );
    }

    return DateTime(date.year, date.month, date.day, hour, minute);
  }
}
