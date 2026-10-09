import '../models/routine.dart';

abstract interface class RoutineRepository {
  Future<void> createRoutine(Routine routine);

  Future<List<Routine>> recoverRoutines({required String anonymousId});

  Future<void> updateRoutine(Routine routine);

  Future<void> deleteRoutine({
    required String anonymousId,
    required String routineId,
  });
}
