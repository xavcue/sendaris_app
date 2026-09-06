import '../exceptions/routine_validation_failure.dart';
import '../models/routine.dart';
import '../validation/routine_validator.dart';
import 'routine_id_generator.dart';

class RoutineFactory {
  const RoutineFactory(this._idGenerator);

  final RoutineIdGenerator _idGenerator;

  Routine create({
    required String anonymousId,
    required String name,
    String? description,
    String? scheduledTime,
    String? recurrence,
  }) {
    final normalizedAnonymousId = anonymousId.trim();

    final normalizedName = name.trim();

    final normalizedDescription = _normalizeOptionalText(description);

    final normalizedScheduledTime = _normalizeOptionalText(scheduledTime);

    final normalizedRecurrence = _normalizeOptionalText(recurrence);

    final errors = RoutineValidator.validate(
      anonymousId: normalizedAnonymousId,
      name: normalizedName,
      scheduledTime: normalizedScheduledTime,
      recurrence: normalizedRecurrence,
    );

    if (errors.isNotEmpty) {
      throw RoutineValidationFailure(errors);
    }

    return Routine(
      routineId: _idGenerator.generate(),
      anonymousId: normalizedAnonymousId,
      name: normalizedName,
      description: normalizedDescription,
      scheduledTime: normalizedScheduledTime,
      recurrence: normalizedRecurrence,
      isActive: true,
    );
  }

  Routine update({
    required Routine routine,
    required String name,
    String? description,
    String? scheduledTime,
    String? recurrence,
  }) {
    final normalizedName = name.trim();

    final normalizedDescription = _normalizeOptionalText(description);

    final normalizedScheduledTime = _normalizeOptionalText(scheduledTime);

    final normalizedRecurrence = _normalizeOptionalText(recurrence);

    final errors = RoutineValidator.validate(
      anonymousId: routine.anonymousId,
      name: normalizedName,
      scheduledTime: normalizedScheduledTime,
      recurrence: normalizedRecurrence,
    );

    if (errors.isNotEmpty) {
      throw RoutineValidationFailure(errors);
    }

    return routine.copyWith(
      name: normalizedName,
      description: normalizedDescription,
      clearDescription: normalizedDescription == null,
      scheduledTime: normalizedScheduledTime,
      clearScheduledTime: normalizedScheduledTime == null,
      recurrence: normalizedRecurrence,
      clearRecurrence: normalizedRecurrence == null,
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
