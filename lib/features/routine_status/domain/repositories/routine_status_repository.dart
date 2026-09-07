import '../models/routine_status_record.dart';

abstract interface class RoutineStatusRepository {
  Future<void> saveRoutineStatus(RoutineStatusRecord record);

  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  });
}
