import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/exceptions/routine_failure.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine/presentation/viewmodels/routine_management_view_model.dart';

void main() {
  group('RoutineManagementViewModel', () {
    test(
      'recupera las rutinas del seguimiento y las ordena por nombre',
      () async {
        final repository = _FakeRoutineRepository(
          routines: const [
            Routine(routineId: '2', anonymousId: 'anonimo', name: 'Mochila'),
            Routine(routineId: '1', anonymousId: 'anonimo', name: 'Almuerzo'),
            Routine(routineId: '3', anonymousId: 'anonimo', name: 'Cena'),
            Routine(
              routineId: '4',
              anonymousId: 'otro-seguimiento',
              name: 'Rutina externa',
            ),
          ],
        );

        final viewModel = RoutineManagementViewModel(
          repository,
          anonymousId: 'anonimo',
        );

        addTearDown(viewModel.dispose);

        final success = await viewModel.reload();

        expect(success, isTrue);

        expect(viewModel.routines.map((routine) => routine.name).toList(), [
          'Almuerzo',
          'Cena',
          'Mochila',
        ]);

        expect(viewModel.hasRoutines, isTrue);

        expect(
          viewModel.routines.any((routine) => routine.anonymousId != 'anonimo'),
          isFalse,
        );
      },
    );

    test('elimina una rutina y la retira de la lista visible', () async {
      final repository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: '1',
            anonymousId: 'anonimo',
            name: 'Preparar mochila',
          ),
          Routine(
            routineId: '2',
            anonymousId: 'anonimo',
            name: 'Rutina de lectura',
          ),
        ],
      );

      final viewModel = RoutineManagementViewModel(
        repository,
        anonymousId: 'anonimo',
      );

      addTearDown(viewModel.dispose);

      await viewModel.reload();

      final routineToDelete = viewModel.routines.firstWhere(
        (routine) => routine.routineId == '1',
      );

      final success = await viewModel.deleteRoutine(routineToDelete);

      expect(success, isTrue);

      expect(viewModel.routines.map((routine) => routine.routineId).toList(), [
        '2',
      ]);

      expect(repository.deletedAnonymousId, 'anonimo');

      expect(repository.deletedRoutineId, '1');
    });

    test('no elimina una rutina perteneciente a otro seguimiento', () async {
      final repository = _FakeRoutineRepository(
        routines: const [
          Routine(routineId: '1', anonymousId: 'anonimo', name: 'Rutina local'),
        ],
      );

      final viewModel = RoutineManagementViewModel(
        repository,
        anonymousId: 'anonimo',
      );

      addTearDown(viewModel.dispose);

      await viewModel.reload();

      const externalRoutine = Routine(
        routineId: 'externa',
        anonymousId: 'otro-seguimiento',
        name: 'Rutina externa',
      );

      final success = await viewModel.deleteRoutine(externalRoutine);

      expect(success, isFalse);

      expect(viewModel.routines, hasLength(1));

      expect(repository.deletedRoutineId, isNull);
    });

    test('conserva la rutina visible cuando la eliminación falla', () async {
      final repository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: '1',
            anonymousId: 'anonimo',
            name: 'Preparar mochila',
          ),
        ],
        deleteError: const RoutineFailure('No fue posible eliminar la rutina.'),
      );

      final viewModel = RoutineManagementViewModel(
        repository,
        anonymousId: 'anonimo',
      );

      addTearDown(viewModel.dispose);

      await viewModel.reload();

      final success = await viewModel.deleteRoutine(viewModel.routines.single);

      expect(success, isFalse);

      expect(viewModel.routines, hasLength(1));

      expect(viewModel.errorMessage, 'No fue posible eliminar la rutina.');

      expect(viewModel.isUpdating, isFalse);
    });
  });
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository({this.routines = const [], this.deleteError});

  final List<Routine> routines;
  final Object? deleteError;

  String? deletedAnonymousId;
  String? deletedRoutineId;

  @override
  Future<void> createRoutine(Routine routine) async {}

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    return List.unmodifiable(routines);
  }

  @override
  Future<void> updateRoutine(Routine routine) async {}

  @override
  Future<void> deleteRoutine({
    required String anonymousId,
    required String routineId,
  }) async {
    final currentError = deleteError;

    if (currentError != null) {
      throw currentError;
    }

    deletedAnonymousId = anonymousId;

    deletedRoutineId = routineId;
  }
}
