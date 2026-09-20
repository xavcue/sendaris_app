import '../../../routine/domain/models/routine.dart';
import '../../../routine/domain/repositories/routine_repository.dart';
import '../../../routine_status/domain/models/routine_status_record.dart';
import '../../../routine_status/domain/repositories/routine_status_repository.dart';
import '../../domain/exceptions/routine_compliance_failure.dart';
import '../../domain/models/routine_compliance_entry.dart';
import '../../domain/repositories/routine_compliance_repository.dart';

class CompositeRoutineComplianceRepository
    implements RoutineComplianceRepository {
  factory CompositeRoutineComplianceRepository({
    required RoutineRepository routineRepository,
    required RoutineStatusRepository routineStatusRepository,
  }) {
    return CompositeRoutineComplianceRepository._(
      routineRepository,
      routineStatusRepository,
    );
  }

  CompositeRoutineComplianceRepository._(
    this._routineRepository,
    this._routineStatusRepository,
  );

  final RoutineRepository _routineRepository;

  final RoutineStatusRepository _routineStatusRepository;

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    final normalizedAnonymousId = anonymousId.trim();

    if (normalizedAnonymousId.isEmpty || normalizedAnonymousId.contains('/')) {
      throw const RoutineComplianceFailure(
        'El perfil seleccionado no es válido.',
      );
    }

    try {
      final routines = await _routineRepository.recoverRoutines(
        anonymousId: normalizedAnonymousId,
      );

      final routineStatuses = await _routineStatusRepository
          .recoverRoutineStatuses(anonymousId: normalizedAnonymousId);

      final validRoutineIds = _buildValidRoutineIds(
        routines: routines,
        anonymousId: normalizedAnonymousId,
      );

      return _mapValidEntries(
        records: routineStatuses,
        validRoutineIds: validRoutineIds,
        anonymousId: normalizedAnonymousId,
      );
    } on RoutineComplianceFailure {
      rethrow;
    } catch (_) {
      throw const RoutineComplianceFailure(
        'No fue posible recuperar la información '
        'para calcular el cumplimiento de rutinas. '
        'Inténtalo nuevamente.',
      );
    }
  }

  Set<String> _buildValidRoutineIds({
    required Iterable<Routine> routines,
    required String anonymousId,
  }) {
    return Set.unmodifiable(
      routines
          .where((routine) => routine.anonymousId == anonymousId)
          .map((routine) => routine.routineId),
    );
  }

  List<RoutineComplianceEntry> _mapValidEntries({
    required Iterable<RoutineStatusRecord> records,
    required Set<String> validRoutineIds,
    required String anonymousId,
  }) {
    final entries =
        records
            .where(
              (record) =>
                  record.anonymousId == anonymousId &&
                  validRoutineIds.contains(record.routineId),
            )
            .map(
              (record) => RoutineComplianceEntry(
                recordId: record.recordId,
                anonymousId: record.anonymousId,
                routineId: record.routineId,
                date: record.date,
                status: record.status,
              ),
            )
            .toList()
          ..sort((first, second) {
            final dateComparison = first.date.compareTo(second.date);

            if (dateComparison != 0) {
              return dateComparison;
            }

            final routineComparison = first.routineId.compareTo(
              second.routineId,
            );

            if (routineComparison != 0) {
              return routineComparison;
            }

            return first.recordId.compareTo(second.recordId);
          });

    return List.unmodifiable(entries);
  }
}
