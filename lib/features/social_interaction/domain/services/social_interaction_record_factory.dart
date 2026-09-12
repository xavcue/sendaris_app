import '../exceptions/social_interaction_validation_failure.dart';
import '../models/social_interaction_category.dart';
import '../models/social_interaction_record.dart';
import '../validation/social_interaction_record_validator.dart';
import 'social_interaction_record_id_generator.dart';

class SocialInteractionRecordFactory {
  const SocialInteractionRecordFactory(this._idGenerator);

  final SocialInteractionRecordIdGenerator _idGenerator;

  SocialInteractionRecord create({
    required String anonymousId,
    required DateTime date,
    required SocialInteractionCategory category,
    String? context,
    String? observation,
    DateTime? createdAt,
  }) {
    final normalizedAnonymousId = anonymousId.trim();

    final normalizedContext = _normalizeOptionalText(context);

    final normalizedObservation = _normalizeOptionalText(observation);

    final errors = SocialInteractionRecordValidator.validate(
      anonymousId: normalizedAnonymousId,
    );

    if (errors.isNotEmpty) {
      throw SocialInteractionValidationFailure(errors);
    }

    final timestamp = (createdAt ?? DateTime.now()).toUtc();

    return SocialInteractionRecord(
      recordId: _idGenerator.generate(),
      anonymousId: normalizedAnonymousId,
      date: DateTime(date.year, date.month, date.day),
      category: category,
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
