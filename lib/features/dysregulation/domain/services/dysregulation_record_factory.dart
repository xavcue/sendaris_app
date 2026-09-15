import '../exceptions/dysregulation_validation_failure.dart';
import '../models/dysregulation_intensity.dart';
import '../models/dysregulation_record.dart';
import '../validation/dysregulation_record_validator.dart';
import 'dysregulation_record_id_generator.dart';

class DysregulationRecordFactory {
  const DysregulationRecordFactory(this._idGenerator);

  final DysregulationRecordIdGenerator _idGenerator;

  DysregulationRecord create({
    required String anonymousId,
    required DateTime date,
    String? time,
    int? durationMinutes,
    DysregulationIntensity? intensity,
    String? context,
    String? observation,
    DateTime? createdAt,
  }) {
    final normalizedAnonymousId = anonymousId.trim();
    final normalizedTime = _normalizeOptionalText(time);
    final normalizedContext = _normalizeOptionalText(context);
    final normalizedObservation = _normalizeOptionalText(observation);

    final errors = DysregulationRecordValidator.validate(
      anonymousId: normalizedAnonymousId,
      time: normalizedTime,
      durationMinutes: durationMinutes,
    );

    if (errors.isNotEmpty) {
      throw DysregulationValidationFailure(errors);
    }

    final timestamp = (createdAt ?? DateTime.now()).toUtc();

    return DysregulationRecord(
      recordId: _idGenerator.generate(),
      anonymousId: normalizedAnonymousId,
      date: DateTime(date.year, date.month, date.day),
      time: normalizedTime,
      durationMinutes: durationMinutes,
      intensity: intensity,
      context: normalizedContext,
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
