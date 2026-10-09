import '../../domain/models/routine_status_record.dart';

abstract interface class RoutineStatusRemoteService {
  Future<void> saveRoutineStatus(RoutineStatusRecord record);

  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  });
}

abstract interface class RoutineStatusManagementRemoteService
    implements RoutineStatusRemoteService {
  Future<void> updateRoutineStatus(RoutineStatusRecord record);

  Future<void> deleteRoutineStatus({
    required String anonymousId,
    required String recordId,
  });
}
