import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/data/repositories/firebase_routine_repository.dart';
import 'package:sendaris/features/routine/data/services/routine_remote_service.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';

void main() {
  group('FirebaseRoutineRepository', () {
    const routine = Routine(
      routineId: 'routine-test-id',
      anonymousId: 'anonimo-test',
      name: 'Preparar mochila',
      recurrence: 'diaria',
    );

    test('delega la creación al servicio remoto', () async {
      final service = _FakeRoutineRemoteService();

      final repository = FirebaseRoutineRepository(service);

      await repository.createRoutine(routine);

      expect(service.createdRoutine, same(routine));
    });

    test('recupera las rutinas del servicio remoto', () async {
      final service = _FakeRoutineRemoteService(
        recoveredRoutines: const [routine],
      );

      final repository = FirebaseRoutineRepository(service);

      final result = await repository.recoverRoutines(
        anonymousId: 'anonimo-test',
      );

      expect(result, hasLength(1));

      expect(result.single.name, 'Preparar mochila');
    });

    test('delega la modificación al servicio remoto', () async {
      final service = _FakeRoutineRemoteService();

      final repository = FirebaseRoutineRepository(service);

      await repository.updateRoutine(routine);

      expect(service.updatedRoutine, same(routine));
    });

    test('delega la eliminación al servicio remoto', () async {
      final service = _FakeRoutineRemoteService();

      final repository = FirebaseRoutineRepository(service);

      await repository.deleteRoutine(
        anonymousId: 'anonimo-test',
        routineId: 'routine-test-id',
      );

      expect(service.deletedAnonymousId, 'anonimo-test');

      expect(service.deletedRoutineId, 'routine-test-id');
    });
  });
}

class _FakeRoutineRemoteService implements RoutineRemoteService {
  _FakeRoutineRemoteService({this.recoveredRoutines = const []});

  final List<Routine> recoveredRoutines;

  Routine? createdRoutine;
  Routine? updatedRoutine;

  String? deletedAnonymousId;
  String? deletedRoutineId;

  @override
  Future<void> createRoutine(Routine routine) async {
    createdRoutine = routine;
  }

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    return recoveredRoutines;
  }

  @override
  Future<void> updateRoutine(Routine routine) async {
    updatedRoutine = routine;
  }

  @override
  Future<void> deleteRoutine({
    required String anonymousId,
    required String routineId,
  }) async {
    deletedAnonymousId = anonymousId;
    deletedRoutineId = routineId;
  }
}
