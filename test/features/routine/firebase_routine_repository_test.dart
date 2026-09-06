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
      isActive: true,
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

    test('delega la desactivación sin eliminar la rutina', () async {
      final service = _FakeRoutineRemoteService();

      final repository = FirebaseRoutineRepository(service);

      await repository.deactivateRoutine(
        anonymousId: 'anonimo-test',
        routineId: 'routine-test-id',
      );

      expect(service.deactivatedAnonymousId, 'anonimo-test');

      expect(service.deactivatedRoutineId, 'routine-test-id');
    });
  });
}

class _FakeRoutineRemoteService implements RoutineRemoteService {
  _FakeRoutineRemoteService({this.recoveredRoutines = const []});

  final List<Routine> recoveredRoutines;

  Routine? createdRoutine;
  Routine? updatedRoutine;

  String? deactivatedAnonymousId;

  String? deactivatedRoutineId;

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
  Future<void> deactivateRoutine({
    required String anonymousId,
    required String routineId,
  }) async {
    deactivatedAnonymousId = anonymousId;

    deactivatedRoutineId = routineId;
  }
}
