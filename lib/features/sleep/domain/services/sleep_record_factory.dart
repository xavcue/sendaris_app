import '../exceptions/sleep_validation_failure.dart';
import '../models/sleep_record.dart';
import '../validation/sleep_record_validator.dart';
import 'sleep_duration_calculator.dart';
import 'sleep_record_id_generator.dart';

class SleepRecordFactory {
  const SleepRecordFactory(this._idGenerator);

  final SleepRecordIdGenerator _idGenerator;

  SleepRecord create({
    required String anonymousId,
    required DateTime date,
    required String startTime,
    required String endTime,
    String? observation,
    DateTime? createdAt,
  }) {
    final normalizedAnonymousId = anonymousId.trim();

    final normalizedStartTime = startTime.trim();

    final normalizedEndTime = endTime.trim();

    final normalizedObservation = _normalizeOptionalText(observation);

    final errors = SleepRecordValidator.validate(
      anonymousId: normalizedAnonymousId,
      startTime: normalizedStartTime,
      endTime: normalizedEndTime,
    );

    if (errors.isNotEmpty) {
      throw SleepValidationFailure(errors);
    }

    final durationMinutes = SleepDurationCalculator.calculate(
      startTime: normalizedStartTime,
      endTime: normalizedEndTime,
    );

    final timestamp = (createdAt ?? DateTime.now()).toUtc();

    return SleepRecord(
      recordId: _idGenerator.generate(),
      anonymousId: normalizedAnonymousId,
      date: DateTime(date.year, date.month, date.day),
      startTime: normalizedStartTime,
      endTime: normalizedEndTime,
      durationMinutes: durationMinutes,
      observation: normalizedObservation,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  String? _normalizeOptionalText(String? value) {
    if (value == null) {
      return null;
    }

    final normalized = value.trim();

    return normalized.isEmpty ? null : normalized;
  }
}
