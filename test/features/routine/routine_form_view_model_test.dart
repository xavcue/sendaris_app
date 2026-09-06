import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine/domain/services/routine_factory.dart';
import 'package:sendaris/features/routine/domain/services/routine_id_generator.dart';
import 'package:sendaris/features/routine/presentation/viewmodels/routine_form_view_model.dart';

void main() {
  group('RoutineFormViewModel', () {
    const factory = RoutineFactory(_FakeRoutineIdGenerator());

    test('crea una rutina con hora y recurrencia', () async {
      final repository = _FakeRoutineRepository();

      final viewModel = RoutineFormViewModel(
        repository,
        factory,
        anonymousId: 'anonimo-test',
      );

      viewModel.setTime(hour: 20, minute: 15);

      viewModel.setRecurrence('diaria');

      final routine = await viewModel.save(
        name: 'Preparar mochila',
        description: 'Revisar materiales',
      );

      expect(routine, isNotNull);

      expect(routine!.scheduledTime, '20:15');

      expect(routine.recurrence, 'diaria');

      expect(repository.createdRoutine, same(routine));

      expect(viewModel.successMessage, 'Rutina creada correctamente.');
    });

    test('expone error de nombre obligatorio sin persistir', () async {
      final repository = _FakeRoutineRepository();

      final viewModel = RoutineFormViewModel(
        repository,
        factory,
        anonymousId: 'anonimo-test',
      );

      final routine = await viewModel.save(name: '   ', description: '');

      expect(routine, isNull);

      expect(viewModel.errorFor('name'), isNotNull);

      expect(repository.createdRoutine, isNull);
    });

    test('actualiza una rutina conservando su identificador', () async {
      final repository = _FakeRoutineRepository();

      const existing = Routine(
        routineId: 'rutina-original',
        anonymousId: 'anonimo-test',
        name: 'Preparar mochila',
        scheduledTime: '20:00',
        recurrence: 'diaria',
        isActive: true,
      );

      final viewModel = RoutineFormViewModel(
        repository,
        factory,
        anonymousId: 'anonimo-test',
        initialRoutine: existing,
      );

      viewModel.setTime(hour: 19, minute: 30);

      viewModel.setRecurrence('semanal');

      final updated = await viewModel.save(
        name: 'Preparar mochila escolar',
        description: '',
      );

      expect(updated, isNotNull);

      expect(updated!.routineId, 'rutina-original');

      expect(updated.scheduledTime, '19:30');

      expect(updated.recurrence, 'semanal');

      expect(repository.updatedRoutine, same(updated));
    });
  });
}

class _FakeRoutineIdGenerator implements RoutineIdGenerator {
  const _FakeRoutineIdGenerator();

  @override
  String generate() {
    return 'routine-test-id';
  }
}

class _FakeRoutineRepository implements RoutineRepository {
  Routine? createdRoutine;
  Routine? updatedRoutine;

  @override
  Future<void> createRoutine(Routine routine) async {
    createdRoutine = routine;
  }

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    return [];
  }

  @override
  Future<void> updateRoutine(Routine routine) async {
    updatedRoutine = routine;
  }

  @override
  Future<void> deactivateRoutine({
    required String anonymousId,
    required String routineId,
  }) async {}
}
