import '../exceptions/routine_status_validation_failure.dart';
import '../models/routine_status.dart';
import '../models/routine_status_record.dart';
import '../validation/routine_status_record_validator.dart';
import 'routine_status_record_id_generator.dart';

class RoutineStatusRecordFactory {
  const RoutineStatusRecordFactory(this._idGenerator);

  final RoutineStatusRecordIdGenerator _idGenerator;

  RoutineStatusRecord create({
    required String anonymousId,
    required String routineId,
    required DateTime date,
    required RoutineStatus status,
    String? observation,
    DateTime? createdAt,
  }) {
    final normalizedAnonymousId = anonymousId.trim();

    final normalizedRoutineId = routineId.trim();

    final normalizedObservation = _normalizeOptionalText(observation);

    final errors = RoutineStatusRecordValidator.validate(
      anonymousId: normalizedAnonymousId,
      routineId: normalizedRoutineId,
    );

    if (errors.isNotEmpty) {
      throw RoutineStatusValidationFailure(errors);
    }

    final timestamp = (createdAt ?? DateTime.now()).toUtc();

    return RoutineStatusRecord(
      recordId: _idGenerator.generate(),
      anonymousId: normalizedAnonymousId,
      routineId: normalizedRoutineId,
      date: DateTime(date.year, date.month, date.day),
      status: status,
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
