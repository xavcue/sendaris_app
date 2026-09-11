import '../exceptions/feeding_validation_failure.dart';
import '../models/feeding_category.dart';
import '../models/feeding_record.dart';
import '../validation/feeding_record_validator.dart';
import 'feeding_record_id_generator.dart';

class FeedingRecordFactory {
  const FeedingRecordFactory(this._idGenerator);

  final FeedingRecordIdGenerator _idGenerator;

  FeedingRecord create({
    required String anonymousId,
    required DateTime date,
    required FeedingCategory category,
    String? observation,
    DateTime? createdAt,
  }) {
    final normalizedAnonymousId = anonymousId.trim();

    final normalizedObservation = _normalizeOptionalText(observation);

    final errors = FeedingRecordValidator.validate(
      anonymousId: normalizedAnonymousId,
    );

    if (errors.isNotEmpty) {
      throw FeedingValidationFailure(errors);
    }

    final timestamp = (createdAt ?? DateTime.now()).toUtc();

    return FeedingRecord(
      recordId: _idGenerator.generate(),
      anonymousId: normalizedAnonymousId,
      date: DateTime(date.year, date.month, date.day),
      category: category,
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
