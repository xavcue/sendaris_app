import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/exceptions/routine_failure.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine_status/domain/exceptions/routine_status_failure.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';
import 'package:sendaris/features/routine_status/domain/repositories/routine_status_management_repository.dart';
import 'package:sendaris/features/routine_status/presentation/viewmodels/routine_status_management_view_model.dart';

void main() {
  group('RoutineStatusManagementViewModel', () {
    late _FakeRoutineStatusManagementRepository repository;

    late _FakeRoutineRepository routineRepository;

    late RoutineStatusManagementViewModel viewModel;

    setUp(() {
      repository = _FakeRoutineStatusManagementRepository();

      routineRepository = _FakeRoutineRepository();

      viewModel = RoutineStatusManagementViewModel(
        repository,
        routineRepository,
        anonymousId: 'seguimiento-actual',
      );
    });

    tearDown(() {
      viewModel.dispose();
    });

    test('carga únicamente estados del seguimiento actual '
        'y resuelve el nombre de la rutina', () async {
      repository.recordsToRecover = [
        _record(
          recordId: 'estado-actual',
          routineId: 'rutina-1',
          anonymousId: 'seguimiento-actual',
          date: DateTime(2026, 9, 22),
        ),
        _record(
          recordId: 'estado-otro',
          routineId: 'rutina-2',
          anonymousId: 'otro-seguimiento',
          date: DateTime(2026, 9, 23),
        ),
      ];

      routineRepository.routinesToRecover = const [
        Routine(
          routineId: 'rutina-1',
          anonymousId: 'seguimiento-actual',
          name: 'Rutina de mañana',
        ),
        Routine(
          routineId: 'rutina-2',
          anonymousId: 'otro-seguimiento',
          name: 'Rutina externa',
        ),
      ];

      final success = await viewModel.initialize();

      expect(success, isTrue);

      expect(viewModel.records, hasLength(1));

      expect(viewModel.records.single.recordId, 'estado-actual');

      expect(viewModel.items.single.routineName, 'Rutina de mañana');

      expect(viewModel.hasLoaded, isTrue);

      expect(viewModel.errorMessage, isNull);
    });

    test('ordena por fecha y usa fecha de creación '
        'como desempate', () async {
      repository.recordsToRecover = [
        _record(
          recordId: 'antiguo',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 20),
        ),
        _record(
          recordId: 'mismo-dia-primero',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 22),
          createdAt: DateTime.utc(2026, 9, 22, 12),
        ),
        _record(
          recordId: 'mismo-dia-despues',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 22),
          createdAt: DateTime.utc(2026, 9, 22, 18),
        ),
      ];

      routineRepository.routinesToRecover = const [
        Routine(
          routineId: 'rutina-1',
          anonymousId: 'seguimiento-actual',
          name: 'Rutina',
        ),
      ];

      await viewModel.initialize();

      expect(viewModel.records.map((record) => record.recordId).toList(), [
        'mismo-dia-despues',
        'mismo-dia-primero',
        'antiguo',
      ]);
    });

    test('conserva un estado aunque su rutina ya '
        'no esté disponible', () async {
      repository.recordsToRecover = [
        _record(
          recordId: 'estado-huerfano',
          routineId: 'rutina-eliminada',
          date: DateTime(2026, 9, 22),
        ),
      ];

      final success = await viewModel.initialize();

      expect(success, isTrue);

      expect(viewModel.items, hasLength(1));

      expect(viewModel.items.single.routineName, 'Rutina no disponible');

      expect(viewModel.routineGroups, hasLength(1));

      expect(
        viewModel.routineGroups.single.routineName,
        'Rutina no disponible',
      );
    });

    test('filtra de forma inclusiva entre fecha '
        'inicial y final', () async {
      repository.recordsToRecover = [
        _record(
          recordId: '19',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 19),
        ),
        _record(
          recordId: '20',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 20),
        ),
        _record(
          recordId: '21',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 21),
        ),
        _record(
          recordId: '22',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 22),
        ),
        _record(
          recordId: '23',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 23),
        ),
      ];

      await viewModel.initialize();

      viewModel.setPendingStartDate(DateTime(2026, 9, 20));

      viewModel.setPendingEndDate(DateTime(2026, 9, 22));

      expect(viewModel.applyDateFilter(), isTrue);

      expect(
        viewModel.filteredItems.map((item) => item.record.recordId).toSet(),
        {'20', '21', '22'},
      );

      expect(viewModel.hasActiveDateFilter, isTrue);
    });

    test('rechaza un periodo cuya fecha inicial '
        'sea posterior a la final', () async {
      repository.recordsToRecover = [
        _record(
          recordId: 'estado-1',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 20),
        ),
      ];

      await viewModel.initialize();

      viewModel.setPendingStartDate(DateTime(2026, 9, 22));

      viewModel.setPendingEndDate(DateTime(2026, 9, 20));

      final success = viewModel.applyDateFilter();

      expect(success, isFalse);

      expect(viewModel.filterErrorMessage, isNotNull);

      expect(viewModel.hasActiveDateFilter, isFalse);
    });

    test('quitar filtro restaura todos los estados', () async {
      repository.recordsToRecover = [
        _record(
          recordId: '20',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 20),
        ),
        _record(
          recordId: '22',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 22),
        ),
      ];

      await viewModel.initialize();

      viewModel.setPendingStartDate(DateTime(2026, 9, 22));

      expect(viewModel.applyDateFilter(), isTrue);

      expect(viewModel.filteredItems, hasLength(1));

      viewModel.clearDateFilter();

      expect(viewModel.filteredItems, hasLength(2));

      expect(viewModel.hasActiveDateFilter, isFalse);

      expect(viewModel.pendingStartDate, isNull);

      expect(viewModel.pendingEndDate, isNull);
    });

    test('agrupa los estados por rutina sin repetir '
        'la rutina', () async {
      repository.recordsToRecover = [
        _record(
          recordId: 'mochila-01',
          routineId: 'rutina-mochila',
          date: DateTime(2026, 10, 1),
          status: RoutineStatus.modified,
        ),
        _record(
          recordId: 'lectura-01',
          routineId: 'rutina-lectura',
          date: DateTime(2026, 9, 30),
        ),
        _record(
          recordId: 'mochila-02',
          routineId: 'rutina-mochila',
          date: DateTime(2026, 9, 22),
          status: RoutineStatus.notCompleted,
        ),
        _record(
          recordId: 'mochila-03',
          routineId: 'rutina-mochila',
          date: DateTime(2026, 9, 21),
          status: RoutineStatus.notCompleted,
        ),
      ];

      routineRepository.routinesToRecover = const [
        Routine(
          routineId: 'rutina-mochila',
          anonymousId: 'seguimiento-actual',
          name: 'Preparar mochila',
        ),
        Routine(
          routineId: 'rutina-lectura',
          anonymousId: 'seguimiento-actual',
          name: 'Rutina de lectura',
        ),
      ];

      await viewModel.initialize();

      expect(viewModel.routineGroupCount, 2);

      expect(
        viewModel.routineGroups.map((group) => group.routineName).toList(),
        ['Preparar mochila', 'Rutina de lectura'],
      );

      final mochilaGroup = viewModel.routineGroups.first;

      expect(mochilaGroup.routineId, 'rutina-mochila');

      expect(mochilaGroup.recordCount, 3);

      expect(mochilaGroup.latestRecord.recordId, 'mochila-01');

      expect(mochilaGroup.latestRecord.status, RoutineStatus.modified);
    });

    test('ordena los grupos por el estado más '
        'reciente de cada rutina', () async {
      repository.recordsToRecover = [
        _record(
          recordId: 'rutina-b-reciente',
          routineId: 'rutina-b',
          date: DateTime(2026, 10, 3),
        ),
        _record(
          recordId: 'rutina-a-reciente',
          routineId: 'rutina-a',
          date: DateTime(2026, 10, 2),
        ),
        _record(
          recordId: 'rutina-b-antiguo',
          routineId: 'rutina-b',
          date: DateTime(2026, 9, 10),
        ),
      ];

      routineRepository.routinesToRecover = const [
        Routine(
          routineId: 'rutina-a',
          anonymousId: 'seguimiento-actual',
          name: 'Rutina A',
        ),
        Routine(
          routineId: 'rutina-b',
          anonymousId: 'seguimiento-actual',
          name: 'Rutina B',
        ),
      ];

      await viewModel.initialize();

      expect(viewModel.routineGroups.map((group) => group.routineId).toList(), [
        'rutina-b',
        'rutina-a',
      ]);

      expect(
        viewModel.routineGroups.first.latestRecord.recordId,
        'rutina-b-reciente',
      );
    });

    test('seleccionar una rutina expone únicamente '
        'sus estados', () async {
      repository.recordsToRecover = [
        _record(
          recordId: 'mochila-1',
          routineId: 'rutina-mochila',
          date: DateTime(2026, 10, 1),
        ),
        _record(
          recordId: 'lectura-1',
          routineId: 'rutina-lectura',
          date: DateTime(2026, 9, 30),
        ),
        _record(
          recordId: 'mochila-2',
          routineId: 'rutina-mochila',
          date: DateTime(2026, 9, 22),
        ),
      ];

      routineRepository.routinesToRecover = const [
        Routine(
          routineId: 'rutina-mochila',
          anonymousId: 'seguimiento-actual',
          name: 'Preparar mochila',
        ),
        Routine(
          routineId: 'rutina-lectura',
          anonymousId: 'seguimiento-actual',
          name: 'Rutina de lectura',
        ),
      ];

      await viewModel.initialize();

      viewModel.selectRoutineGroup('rutina-mochila');

      expect(viewModel.hasSelectedRoutine, isTrue);

      expect(viewModel.selectedRoutineId, 'rutina-mochila');

      expect(viewModel.selectedRoutineGroup?.routineName, 'Preparar mochila');

      expect(
        viewModel.selectedRoutineItems
            .map((item) => item.record.recordId)
            .toList(),
        ['mochila-1', 'mochila-2'],
      );
    });

    test('el filtro de fecha puede aplicarse únicamente '
        'a la rutina seleccionada', () async {
      repository.recordsToRecover = [
        _record(
          recordId: 'mochila-01',
          routineId: 'rutina-mochila',
          date: DateTime(2026, 10, 1),
        ),
        _record(
          recordId: 'lectura-01',
          routineId: 'rutina-lectura',
          date: DateTime(2026, 10, 1),
        ),
        _record(
          recordId: 'mochila-22',
          routineId: 'rutina-mochila',
          date: DateTime(2026, 9, 22),
        ),
        _record(
          recordId: 'mochila-21',
          routineId: 'rutina-mochila',
          date: DateTime(2026, 9, 21),
        ),
      ];

      routineRepository.routinesToRecover = const [
        Routine(
          routineId: 'rutina-mochila',
          anonymousId: 'seguimiento-actual',
          name: 'Preparar mochila',
        ),
        Routine(
          routineId: 'rutina-lectura',
          anonymousId: 'seguimiento-actual',
          name: 'Rutina de lectura',
        ),
      ];

      await viewModel.initialize();

      viewModel.selectRoutineGroup('rutina-mochila');

      viewModel.setPendingStartDate(DateTime(2026, 9, 22));

      viewModel.setPendingEndDate(DateTime(2026, 10, 1));

      expect(viewModel.applyDateFilter(), isTrue);

      expect(
        viewModel.filteredSelectedRoutineItems
            .map((item) => item.record.recordId)
            .toList(),
        ['mochila-01', 'mochila-22'],
      );

      expect(viewModel.filteredSelectedRoutineRecordCount, 2);

      expect(viewModel.hasNoSelectedRoutineFilterResults, isFalse);
    });

    test('salir de la rutina seleccionada también '
        'limpia el filtro de fechas', () async {
      repository.recordsToRecover = [
        _record(
          recordId: 'estado-1',
          routineId: 'rutina-1',
          date: DateTime(2026, 10, 1),
        ),
      ];

      routineRepository.routinesToRecover = const [
        Routine(
          routineId: 'rutina-1',
          anonymousId: 'seguimiento-actual',
          name: 'Preparar mochila',
        ),
      ];

      await viewModel.initialize();

      viewModel.selectRoutineGroup('rutina-1');

      viewModel.setPendingStartDate(DateTime(2026, 10, 1));

      expect(viewModel.applyDateFilter(), isTrue);

      expect(viewModel.hasActiveDateFilter, isTrue);

      viewModel.clearSelectedRoutine();

      expect(viewModel.hasSelectedRoutine, isFalse);

      expect(viewModel.selectedRoutineId, isNull);

      expect(viewModel.hasActiveDateFilter, isFalse);

      expect(viewModel.pendingStartDate, isNull);

      expect(viewModel.pendingEndDate, isNull);
    });

    test('eliminar borra el estado remoto y lo '
        'retira del listado local', () async {
      final recordToDelete = _record(
        recordId: 'estado-eliminar',
        routineId: 'rutina-1',
        date: DateTime(2026, 9, 22),
      );

      repository.recordsToRecover = [
        recordToDelete,
        _record(
          recordId: 'estado-conservar',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 21),
        ),
      ];

      await viewModel.initialize();

      final success = await viewModel.deleteRoutineStatus(recordToDelete);

      expect(success, isTrue);

      expect(repository.deletedRecords, [
        (anonymousId: 'seguimiento-actual', recordId: 'estado-eliminar'),
      ]);

      expect(viewModel.records.map((record) => record.recordId).toList(), [
        'estado-conservar',
      ]);

      expect(viewModel.actionErrorMessage, isNull);
    });

    test('eliminar el último estado de una rutina '
        'seleccionada vuelve a la agrupación', () async {
      final recordToDelete = _record(
        recordId: 'ultimo-estado',
        routineId: 'rutina-1',
        date: DateTime(2026, 10, 1),
      );

      repository.recordsToRecover = [
        recordToDelete,
        _record(
          recordId: 'otra-rutina',
          routineId: 'rutina-2',
          date: DateTime(2026, 9, 30),
        ),
      ];

      routineRepository.routinesToRecover = const [
        Routine(
          routineId: 'rutina-1',
          anonymousId: 'seguimiento-actual',
          name: 'Preparar mochila',
        ),
        Routine(
          routineId: 'rutina-2',
          anonymousId: 'seguimiento-actual',
          name: 'Rutina de lectura',
        ),
      ];

      await viewModel.initialize();

      viewModel.selectRoutineGroup('rutina-1');

      viewModel.setPendingStartDate(DateTime(2026, 10, 1));

      viewModel.applyDateFilter();

      final success = await viewModel.deleteRoutineStatus(recordToDelete);

      expect(success, isTrue);

      expect(viewModel.hasSelectedRoutine, isFalse);

      expect(viewModel.selectedRoutineId, isNull);

      expect(viewModel.hasActiveDateFilter, isFalse);

      expect(viewModel.routineGroups, hasLength(1));

      expect(viewModel.routineGroups.single.routineId, 'rutina-2');
    });

    test('si eliminar falla conserva el estado '
        'y expone el error', () async {
      final record = _record(
        recordId: 'estado-conservar',
        routineId: 'rutina-1',
        date: DateTime(2026, 9, 22),
      );

      repository.recordsToRecover = [record];

      await viewModel.initialize();

      repository.deleteFailure = const RoutineStatusFailure(
        'No fue posible eliminar el estado de la rutina.',
      );

      final success = await viewModel.deleteRoutineStatus(record);

      expect(success, isFalse);

      expect(viewModel.records, hasLength(1));

      expect(viewModel.records.single.recordId, 'estado-conservar');

      expect(
        viewModel.actionErrorMessage,
        'No fue posible eliminar el estado de la rutina.',
      );
    });

    test('si una recarga falla conserva los estados '
        'previamente cargados', () async {
      repository.recordsToRecover = [
        _record(
          recordId: 'estado-existente',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 22),
        ),
      ];

      expect(await viewModel.initialize(), isTrue);

      repository.recoveryFailure = const RoutineStatusFailure(
        'No fue posible cargar los estados de las rutinas.',
      );

      expect(await viewModel.reload(), isFalse);

      expect(viewModel.records, hasLength(1));

      expect(viewModel.records.single.recordId, 'estado-existente');

      expect(
        viewModel.errorMessage,
        'No fue posible cargar los estados de las rutinas.',
      );
    });

    test('si falla la recuperación de rutinas expone '
        'el error sin destruir datos previos', () async {
      repository.recordsToRecover = [
        _record(
          recordId: 'estado-existente',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 22),
        ),
      ];

      routineRepository.routinesToRecover = const [
        Routine(
          routineId: 'rutina-1',
          anonymousId: 'seguimiento-actual',
          name: 'Rutina existente',
        ),
      ];

      expect(await viewModel.initialize(), isTrue);

      routineRepository.recoveryFailure = const RoutineFailure(
        'No fue posible cargar las rutinas.',
      );

      expect(await viewModel.reload(), isFalse);

      expect(viewModel.items, hasLength(1));

      expect(viewModel.items.single.routineName, 'Rutina existente');

      expect(viewModel.errorMessage, 'No fue posible cargar las rutinas.');
    });
  });
}

RoutineStatusRecord _record({
  required String recordId,
  required String routineId,
  required DateTime date,
  String anonymousId = 'seguimiento-actual',
  RoutineStatus status = RoutineStatus.completed,
  DateTime? createdAt,
}) {
  final timestamp = createdAt ?? DateTime.utc(2026, 9, 20, 18);

  return RoutineStatusRecord(
    recordId: recordId,
    anonymousId: anonymousId,
    routineId: routineId,
    date: date,
    status: status,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _FakeRoutineStatusManagementRepository
    implements RoutineStatusManagementRepository {
  List<RoutineStatusRecord> recordsToRecover = [];

  final List<({String anonymousId, String recordId})> deletedRecords = [];

  RoutineStatusFailure? recoveryFailure;

  RoutineStatusFailure? deleteFailure;

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {}

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    final failure = recoveryFailure;

    if (failure != null) {
      throw failure;
    }

    return List.unmodifiable(recordsToRecover);
  }

  @override
  Future<void> updateRoutineStatus(RoutineStatusRecord record) async {}

  @override
  Future<void> deleteRoutineStatus({
    required String anonymousId,
    required String recordId,
  }) async {
    final failure = deleteFailure;

    if (failure != null) {
      throw failure;
    }

    deletedRecords.add((anonymousId: anonymousId, recordId: recordId));
  }
}

class _FakeRoutineRepository implements RoutineRepository {
  List<Routine> routinesToRecover = [];

  RoutineFailure? recoveryFailure;

  @override
  Future<void> createRoutine(Routine routine) async {}

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    final failure = recoveryFailure;

    if (failure != null) {
      throw failure;
    }

    return List.unmodifiable(routinesToRecover);
  }

  @override
  Future<void> updateRoutine(Routine routine) async {}

  @override
  Future<void> deleteRoutine({
    required String anonymousId,
    required String routineId,
  }) async {}
}
