import '../../domain/models/routine.dart';

abstract interface class RoutineRemoteService {
  Future<void> createRoutine(Routine routine);

  Future<List<Routine>> recoverRoutines({required String anonymousId});

  Future<void> updateRoutine(Routine routine);

  Future<void> deactivateRoutine({
    required String anonymousId,
    required String routineId,
  });
}
