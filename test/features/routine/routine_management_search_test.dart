import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine/presentation/viewmodels/routine_management_view_model.dart';

void main() {
  group('RoutineManagementViewModel búsqueda', () {
    late _FakeRoutineRepository repository;

    late RoutineManagementViewModel viewModel;

    setUp(() {
      repository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: '1',
            anonymousId: 'anonimo',
            name: 'Preparar mochila',
          ),
          Routine(
            routineId: '2',
            anonymousId: 'anonimo',
            name: 'Alimentación de la mañana',
          ),
          Routine(
            routineId: '3',
            anonymousId: 'anonimo',
            name: 'Rutina de lectura',
          ),
        ],
      );

      viewModel = RoutineManagementViewModel(
        repository,
        anonymousId: 'anonimo',
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('sin búsqueda muestra todas las rutinas', () async {
      expect(await viewModel.reload(), isTrue);

      expect(viewModel.routines, hasLength(3));

      expect(viewModel.searchedRoutines, hasLength(3));

      expect(viewModel.searchedRoutineCount, 3);

      expect(viewModel.hasSearchQuery, isFalse);

      expect(viewModel.hasNoSearchResults, isFalse);
    });

    test('busca parcialmente ignorando mayúsculas', () async {
      await viewModel.reload();

      viewModel.setSearchQuery('MOCHI');

      expect(viewModel.hasSearchQuery, isTrue);

      expect(viewModel.searchedRoutines, hasLength(1));

      expect(viewModel.searchedRoutines.single.name, 'Preparar mochila');

      expect(viewModel.searchedRoutineCount, 1);
    });

    test('busca ignorando tildes y espacios sobrantes', () async {
      await viewModel.reload();

      viewModel.setSearchQuery('   alimentacion   ');

      expect(viewModel.searchedRoutines, hasLength(1));

      expect(
        viewModel.searchedRoutines.single.name,
        'Alimentación de la mañana',
      );
    });

    test(
      'sin coincidencias expone el estado vacío y limpiar restaura la lista',
      () async {
        await viewModel.reload();

        viewModel.setSearchQuery('rutina inexistente');

        expect(viewModel.searchedRoutines, isEmpty);

        expect(viewModel.searchedRoutineCount, 0);

        expect(viewModel.hasNoSearchResults, isTrue);

        viewModel.clearSearch();

        expect(viewModel.searchQuery, isEmpty);

        expect(viewModel.hasSearchQuery, isFalse);

        expect(viewModel.searchedRoutines, hasLength(3));

        expect(viewModel.hasNoSearchResults, isFalse);
      },
    );
  });
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository({required this.routines});

  final List<Routine> routines;

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    return List.unmodifiable(routines);
  }

  @override
  Future<void> createRoutine(Routine routine) async {}

  @override
  Future<void> updateRoutine(Routine routine) async {}

  @override
  Future<void> deleteRoutine({
    required String anonymousId,
    required String routineId,
  }) async {}
}
