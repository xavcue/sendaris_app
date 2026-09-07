import '../../domain/models/routine_status_record.dart';

abstract interface class RoutineStatusRemoteService {
  Future<void> saveRoutineStatus(RoutineStatusRecord record);

  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  });
}
