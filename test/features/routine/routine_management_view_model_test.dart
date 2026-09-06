import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine/presentation/viewmodels/routine_management_view_model.dart';

void main() {
  group('RoutineManagementViewModel', () {
    test('recupera y ordena activas antes que desactivadas', () async {
      final repository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: '3',
            anonymousId: 'anonimo',
            name: 'Cena',
            isActive: false,
          ),
          Routine(
            routineId: '2',
            anonymousId: 'anonimo',
            name: 'Mochila',
            isActive: true,
          ),
          Routine(
            routineId: '1',
            anonymousId: 'anonimo',
            name: 'Almuerzo',
            isActive: true,
          ),
        ],
      );

      final viewModel = RoutineManagementViewModel(
        repository,
        anonymousId: 'anonimo',
      );

      final success = await viewModel.reload();

      expect(success, isTrue);

      expect(viewModel.routines.map((routine) => routine.name).toList(), [
        'Almuerzo',
        'Mochila',
        'Cena',
      ]);

      expect(viewModel.activeRoutines, hasLength(2));

      expect(viewModel.inactiveRoutines, hasLength(1));
    });

    test('desactiva una rutina sin eliminarla del listado', () async {
      final repository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: '1',
            anonymousId: 'anonimo',
            name: 'Preparar mochila',
            isActive: true,
          ),
        ],
      );

      final viewModel = RoutineManagementViewModel(
        repository,
        anonymousId: 'anonimo',
      );

      await viewModel.reload();

      final success = await viewModel.deactivateRoutine(
        viewModel.routines.single,
      );

      expect(success, isTrue);

      expect(viewModel.routines, hasLength(1));

      expect(viewModel.routines.single.isActive, isFalse);

      expect(repository.deactivatedRoutineId, '1');
    });
  });
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository({this.routines = const []});

  final List<Routine> routines;

  String? deactivatedRoutineId;

  @override
  Future<void> createRoutine(Routine routine) async {}

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    return routines;
  }

  @override
  Future<void> updateRoutine(Routine routine) async {}

  @override
  Future<void> deactivateRoutine({
    required String anonymousId,
    required String routineId,
  }) async {
    deactivatedRoutineId = routineId;
  }
}
