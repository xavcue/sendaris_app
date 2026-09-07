import '../exceptions/atypical_situation_validation_failure.dart';
import '../models/atypical_situation_category.dart';
import '../models/atypical_situation_record.dart';
import '../validation/atypical_situation_record_validator.dart';
import 'atypical_situation_record_id_generator.dart';

class AtypicalSituationRecordFactory {
  const AtypicalSituationRecordFactory(this._idGenerator);

  final AtypicalSituationRecordIdGenerator _idGenerator;

  AtypicalSituationRecord create({
    required String anonymousId,
    required DateTime date,
    required AtypicalSituationCategory category,
    required String observation,
    DateTime? createdAt,
  }) {
    final normalizedAnonymousId = anonymousId.trim();

    final normalizedObservation = observation.trim();

    final errors = AtypicalSituationRecordValidator.validate(
      anonymousId: normalizedAnonymousId,
      observation: normalizedObservation,
    );

    if (errors.isNotEmpty) {
      throw AtypicalSituationValidationFailure(errors);
    }

    final timestamp = (createdAt ?? DateTime.now()).toUtc();

    return AtypicalSituationRecord(
      recordId: _idGenerator.generate(),
      anonymousId: normalizedAnonymousId,
      date: DateTime(date.year, date.month, date.day),
      category: category,
      observation: normalizedObservation,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }
}
