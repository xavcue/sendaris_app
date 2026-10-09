import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';
import 'package:sendaris/features/routine_status/domain/repositories/routine_status_management_repository.dart';
import 'package:sendaris/features/routine_status/presentation/viewmodels/routine_status_management_view_model.dart';

void main() {
  group('RoutineStatusManagementViewModel búsqueda de rutinas', () {
    late _FakeRoutineStatusManagementRepository repository;
    late _FakeRoutineRepository routineRepository;
    late RoutineStatusManagementViewModel viewModel;

    setUp(() {
      repository = _FakeRoutineStatusManagementRepository()
        ..records = [
          _record(
            recordId: 'estado-mochila',
            routineId: 'rutina-mochila',
            date: DateTime(2026, 10, 1),
          ),
          _record(
            recordId: 'estado-alimentacion',
            routineId: 'rutina-alimentacion',
            date: DateTime(2026, 9, 30),
          ),
          _record(
            recordId: 'estado-lectura',
            routineId: 'rutina-lectura',
            date: DateTime(2026, 9, 29),
          ),
        ];

      routineRepository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: 'rutina-mochila',
            anonymousId: 'seguimiento-actual',
            name: 'Preparar mochila',
          ),
          Routine(
            routineId: 'rutina-alimentacion',
            anonymousId: 'seguimiento-actual',
            name: 'Alimentación de la mañana',
          ),
          Routine(
            routineId: 'rutina-lectura',
            anonymousId: 'seguimiento-actual',
            name: 'Rutina de lectura',
          ),
        ],
      );

      viewModel = RoutineStatusManagementViewModel(
        repository,
        routineRepository,
        anonymousId: 'seguimiento-actual',
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('sin búsqueda muestra todos los grupos', () async {
      expect(await viewModel.initialize(), isTrue);

      expect(viewModel.routineGroupCount, 3);

      expect(viewModel.searchedRoutineGroupCount, 3);

      expect(viewModel.searchedRoutineGroups, hasLength(3));

      expect(viewModel.hasRoutineSearchQuery, isFalse);

      expect(viewModel.hasNoRoutineSearchResults, isFalse);
    });

    test('busca parcialmente ignorando mayúsculas y minúsculas', () async {
      await viewModel.initialize();

      viewModel.setRoutineSearchQuery('MOCHI');

      expect(viewModel.hasRoutineSearchQuery, isTrue);

      expect(viewModel.searchedRoutineGroups, hasLength(1));

      expect(
        viewModel.searchedRoutineGroups.single.routineName,
        'Preparar mochila',
      );

      expect(viewModel.searchedRoutineGroupCount, 1);
    });

    test('busca ignorando tildes y espacios sobrantes', () async {
      await viewModel.initialize();

      viewModel.setRoutineSearchQuery('   alimentacion   ');

      expect(viewModel.searchedRoutineGroups, hasLength(1));

      expect(
        viewModel.searchedRoutineGroups.single.routineName,
        'Alimentación de la mañana',
      );
    });

    test(
      'expone estado sin coincidencias y limpiar búsqueda restaura la lista',
      () async {
        await viewModel.initialize();

        viewModel.setRoutineSearchQuery('rutina inexistente');

        expect(viewModel.searchedRoutineGroups, isEmpty);

        expect(viewModel.searchedRoutineGroupCount, 0);

        expect(viewModel.hasNoRoutineSearchResults, isTrue);

        viewModel.clearRoutineSearch();

        expect(viewModel.routineSearchQuery, isEmpty);

        expect(viewModel.hasRoutineSearchQuery, isFalse);

        expect(viewModel.searchedRoutineGroups, hasLength(3));

        expect(viewModel.hasNoRoutineSearchResults, isFalse);
      },
    );
  });
}

RoutineStatusRecord _record({
  required String recordId,
  required String routineId,
  required DateTime date,
}) {
  final timestamp = DateTime.utc(2026, 10, 1, 18);

  return RoutineStatusRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    routineId: routineId,
    date: date,
    status: RoutineStatus.completed,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _FakeRoutineStatusManagementRepository
    implements RoutineStatusManagementRepository {
  List<RoutineStatusRecord> records = [];

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    return List.unmodifiable(records);
  }

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {}

  @override
  Future<void> updateRoutineStatus(RoutineStatusRecord record) async {}

  @override
  Future<void> deleteRoutineStatus({
    required String anonymousId,
    required String recordId,
  }) async {}
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository({this.routines = const []});

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
