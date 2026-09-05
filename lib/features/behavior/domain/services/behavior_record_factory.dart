import '../exceptions/behavior_validation_failure.dart';
import '../models/behavior_category.dart';
import '../models/behavior_intensity.dart';
import '../models/behavior_record.dart';
import '../validation/behavior_record_validator.dart';
import 'behavior_record_id_generator.dart';

class BehaviorRecordFactory {
  const BehaviorRecordFactory(this._idGenerator);

  final BehaviorRecordIdGenerator _idGenerator;

  BehaviorRecord create({
    required String anonymousId,
    required DateTime date,
    required BehaviorCategory category,
    String? time,
    int? durationMinutes,
    BehaviorIntensity? intensity,
    String? context,
    String? observation,
    DateTime? createdAt,
  }) {
    final normalizedAnonymousId = anonymousId.trim();
    final normalizedTime = _normalizeOptionalText(time);
    final normalizedContext = _normalizeOptionalText(context);
    final normalizedObservation = _normalizeOptionalText(observation);

    final errors = BehaviorRecordValidator.validate(
      anonymousId: normalizedAnonymousId,
      time: normalizedTime,
      durationMinutes: durationMinutes,
    );

    if (errors.isNotEmpty) {
      throw BehaviorValidationFailure(errors);
    }

    final timestamp = (createdAt ?? DateTime.now()).toUtc();

    return BehaviorRecord(
      recordId: _idGenerator.generate(),
      anonymousId: normalizedAnonymousId,
      date: DateTime(date.year, date.month, date.day),
      time: normalizedTime,
      category: category,
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
