import '../models/routine_status_record.dart';
import 'routine_status_repository.dart';

abstract interface class RoutineStatusManagementRepository
    implements RoutineStatusRepository {
  Future<void> updateRoutineStatus(RoutineStatusRecord record);

  Future<void> deleteRoutineStatus({
    required String anonymousId,
    required String recordId,
  });
}
