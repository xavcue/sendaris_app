import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';
import 'package:sendaris/features/routine_status/domain/repositories/routine_status_management_repository.dart';
import 'package:sendaris/features/routine_status/domain/services/routine_status_record_factory.dart';
import 'package:sendaris/features/routine_status/domain/services/routine_status_record_id_generator.dart';
import 'package:sendaris/features/routine_status/presentation/viewmodels/routine_status_form_view_model.dart';

void main() {
  group('RoutineStatusFormViewModel', () {
    const anonymousId = 'anonimo-test';

    RoutineStatusFormViewModel createViewModel({
      List<Routine> routines = const [],
      _FakeRoutineStatusRepository? statusRepository,
      RoutineStatusRecord? initialRecord,
    }) {
      return RoutineStatusFormViewModel(
        _FakeRoutineRepository(routines),
        statusRepository ?? _FakeRoutineStatusRepository(),
        const RoutineStatusRecordFactory(_FakeRoutineStatusRecordIdGenerator()),
        anonymousId: anonymousId,
        initialRecord: initialRecord,
      );
    }

    test('recupera únicamente las rutinas del seguimiento actual y las ordena por nombre', () async {
      final viewModel = createViewModel(
        routines: const [
          Routine(
            routineId: 'rutina-b',
            anonymousId: anonymousId,
            name: 'Cena',
          ),
          Routine(
            routineId: 'rutina-a',
            anonymousId: anonymousId,
            name: 'Alistarse',
          ),
          Routine(
            routineId: 'rutina-otro',
            anonymousId: 'otro-anonimo',
            name: 'Otra rutina',
          ),
        ],
      );

      addTearDown(viewModel.dispose);

      final success = await viewModel.initialize();

      expect(success, isTrue);

      expect(viewModel.routines.map((routine) => routine.routineId).toList(), [
        'rutina-a',
        'rutina-b',
      ]);

      expect(viewModel.hasRoutines, isTrue);
    });

    test('inicia sin fecha seleccionada al crear', () {
      final viewModel = createViewModel();

      addTearDown(viewModel.dispose);

      expect(viewModel.isEditing, isFalse);
      expect(viewModel.selectedDate, isNull);
    });

    test('requiere rutina fecha y estado antes de guardar', () async {
      final viewModel = createViewModel();

      addTearDown(viewModel.dispose);

      final result = await viewModel.save();

      expect(result, isFalse);

      expect(viewModel.routineError, 'Selecciona una rutina.');

      expect(viewModel.dateError, 'Selecciona una fecha.');

      expect(viewModel.statusError, 'Selecciona el estado de la rutina.');
    });

    test('guarda un estado válido de rutina', () async {
      final repository = _FakeRoutineStatusRepository();

      final viewModel = createViewModel(
        routines: const [
          Routine(
            routineId: 'rutina-test',
            anonymousId: anonymousId,
            name: 'Preparar mochila',
          ),
        ],
        statusRepository: repository,
      );

      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      viewModel.selectRoutine('rutina-test');

      viewModel.selectDate(DateTime(2026, 9, 5, 20, 30));

      viewModel.selectStatus(RoutineStatus.completed);

      viewModel.setObservation(' Actividad realizada ');

      final result = await viewModel.save();

      expect(result, isTrue);

      final saved = repository.savedRecord;

      expect(saved, isNotNull);

      expect(saved!.routineId, 'rutina-test');

      expect(saved.date, DateTime(2026, 9, 5));

      expect(saved.status, RoutineStatus.completed);

      expect(saved.observation, 'Actividad realizada');
    });

    test('impide crear un duplicado para la misma rutina y fecha', () async {
      final repository = _FakeRoutineStatusRepository()
        ..existingRecords = [
          _record(
            recordId: 'estado-existente',
            routineId: 'rutina-test',
            date: DateTime(2026, 9, 5),
          ),
        ];

      final viewModel = createViewModel(
        routines: const [
          Routine(
            routineId: 'rutina-test',
            anonymousId: anonymousId,
            name: 'Preparar mochila',
          ),
        ],
        statusRepository: repository,
      );

      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      viewModel.selectRoutine('rutina-test');
      viewModel.selectDate(DateTime(2026, 9, 5));
      viewModel.selectStatus(RoutineStatus.completed);

      final result = await viewModel.save();

      expect(result, isFalse);
      expect(repository.savedRecord, isNull);
      expect(repository.updatedRecord, isNull);
      expect(
        viewModel.errorMessage,
        'Ya existe un estado registrado '
        'para esta rutina en la fecha seleccionada.',
      );
    });

    test('limpia las selecciones después de guardar correctamente', () async {
      final repository = _FakeRoutineStatusRepository();

      final viewModel = createViewModel(
        routines: const [
          Routine(
            routineId: 'rutina-test',
            anonymousId: anonymousId,
            name: 'Preparar mochila',
          ),
        ],
        statusRepository: repository,
      );

      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      viewModel.selectRoutine('rutina-test');

      viewModel.selectDate(DateTime(2026, 9, 5));

      viewModel.selectStatus(RoutineStatus.completed);

      viewModel.setObservation('Observación');

      final result = await viewModel.save();

      expect(result, isTrue);

      expect(viewModel.selectedRoutineId, isNull);

      expect(viewModel.selectedDate, isNull);

      expect(viewModel.selectedStatus, isNull);

      expect(viewModel.observation, isNull);
    });

    test('normaliza la fecha seleccionada sin hora', () {
      final viewModel = createViewModel();

      addTearDown(viewModel.dispose);

      viewModel.selectDate(DateTime(2026, 9, 4, 23, 45));

      expect(viewModel.selectedDate, DateTime(2026, 9, 4));
    });

    test('permite deseleccionar el estado seleccionado', () {
      final viewModel = createViewModel();

      addTearDown(viewModel.dispose);

      viewModel.selectStatus(RoutineStatus.modified);

      expect(viewModel.selectedStatus, RoutineStatus.modified);

      viewModel.selectStatus(RoutineStatus.modified);

      expect(viewModel.selectedStatus, isNull);
    });

    test(
      'ignora una rutina que no pertenece a la colección disponible',
      () async {
        final viewModel = createViewModel(
          routines: const [
            Routine(
              routineId: 'rutina-test',
              anonymousId: anonymousId,
              name: 'Preparar mochila',
            ),
          ],
        );

        addTearDown(viewModel.dispose);

        await viewModel.initialize();

        viewModel.selectRoutine('rutina-inexistente');

        expect(viewModel.selectedRoutineId, isNull);
      },
    );

    test('precarga rutina fecha estado y observación al editar', () async {
      final initialRecord = _record(
        recordId: 'estado-editar',
        routineId: 'rutina-test',
        date: DateTime(2026, 9, 20, 22, 30),
        status: RoutineStatus.modified,
        observation: 'Horario ajustado.',
      );

      final viewModel = createViewModel(
        routines: const [
          Routine(
            routineId: 'rutina-test',
            anonymousId: anonymousId,
            name: 'Preparar mochila',
          ),
        ],
        initialRecord: initialRecord,
      );

      addTearDown(viewModel.dispose);

      expect(viewModel.isEditing, isTrue);
      expect(viewModel.selectedRoutineId, 'rutina-test');
      expect(viewModel.selectedDate, DateTime(2026, 9, 20));
      expect(viewModel.selectedStatus, RoutineStatus.modified);
      expect(viewModel.observation, 'Horario ajustado.');
      expect(viewModel.initialObservation, 'Horario ajustado.');

      final success = await viewModel.initialize();

      expect(success, isTrue);
      expect(viewModel.selectedRoutine?.name, 'Preparar mochila');
    });

    test('permite editar manteniendo la misma rutina y fecha porque excluye el registro actual', () async {
      final initialRecord = _record(
        recordId: 'estado-editar',
        routineId: 'rutina-test',
        date: DateTime(2026, 9, 20),
        status: RoutineStatus.completed,
        observation: 'Original',
      );

      final repository = _FakeRoutineStatusRepository()
        ..existingRecords = [initialRecord];

      final viewModel = createViewModel(
        routines: const [
          Routine(
            routineId: 'rutina-test',
            anonymousId: anonymousId,
            name: 'Preparar mochila',
          ),
        ],
        statusRepository: repository,
        initialRecord: initialRecord,
      );

      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      viewModel.setObservation('Actualizada');

      final result = await viewModel.save();

      expect(result, isTrue);
      expect(repository.savedRecord, isNull);
      expect(repository.updatedRecord, isNotNull);
      expect(repository.updatedRecord!.recordId, initialRecord.recordId);
      expect(repository.updatedRecord!.anonymousId, initialRecord.anonymousId);
      expect(repository.updatedRecord!.createdAt, initialRecord.createdAt);
      expect(repository.updatedRecord!.routineId, 'rutina-test');
      expect(repository.updatedRecord!.date, DateTime(2026, 9, 20));
      expect(repository.updatedRecord!.observation, 'Actualizada');
    });

    test(
      'actualiza rutina fecha estado y observación sin cambiar la identidad',
      () async {
        final initialRecord = _record(
          recordId: 'estado-editar',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 20),
          status: RoutineStatus.completed,
          observation: 'Original',
          createdAt: DateTime.utc(2026, 9, 20, 10),
        );

        final repository = _FakeRoutineStatusRepository()
          ..existingRecords = [initialRecord];

        final viewModel = createViewModel(
          routines: const [
            Routine(
              routineId: 'rutina-1',
              anonymousId: anonymousId,
              name: 'Rutina 1',
            ),
            Routine(
              routineId: 'rutina-2',
              anonymousId: anonymousId,
              name: 'Rutina 2',
            ),
          ],
          statusRepository: repository,
          initialRecord: initialRecord,
        );

        addTearDown(viewModel.dispose);

        await viewModel.initialize();

        viewModel.selectRoutine('rutina-2');
        viewModel.selectDate(DateTime(2026, 9, 21, 18, 30));
        viewModel.selectStatus(RoutineStatus.interrupted);
        viewModel.setObservation(' Cambio aplicado ');

        final result = await viewModel.save();

        expect(result, isTrue);

        final updated = repository.updatedRecord;

        expect(updated, isNotNull);
        expect(updated!.recordId, initialRecord.recordId);
        expect(updated.anonymousId, initialRecord.anonymousId);
        expect(updated.createdAt, initialRecord.createdAt);
        expect(updated.routineId, 'rutina-2');
        expect(updated.date, DateTime(2026, 9, 21));
        expect(updated.status, RoutineStatus.interrupted);
        expect(updated.observation, 'Cambio aplicado');
        expect(updated.updatedAt, isNot(initialRecord.updatedAt));
      },
    );

    test('bloquea la edición cuando otro registro ya usa la rutina y fecha seleccionadas', () async {
      final initialRecord = _record(
        recordId: 'estado-a',
        routineId: 'rutina-1',
        date: DateTime(2026, 9, 20),
      );

      final duplicateRecord = _record(
        recordId: 'estado-b',
        routineId: 'rutina-2',
        date: DateTime(2026, 9, 21),
      );

      final repository = _FakeRoutineStatusRepository()
        ..existingRecords = [initialRecord, duplicateRecord];

      final viewModel = createViewModel(
        routines: const [
          Routine(
            routineId: 'rutina-1',
            anonymousId: anonymousId,
            name: 'Rutina 1',
          ),
          Routine(
            routineId: 'rutina-2',
            anonymousId: anonymousId,
            name: 'Rutina 2',
          ),
        ],
        statusRepository: repository,
        initialRecord: initialRecord,
      );

      addTearDown(viewModel.dispose);

      await viewModel.initialize();

      viewModel.selectRoutine('rutina-2');
      viewModel.selectDate(DateTime(2026, 9, 21));

      final result = await viewModel.save();

      expect(result, isFalse);
      expect(repository.updatedRecord, isNull);
      expect(
        viewModel.errorMessage,
        'Ya existe un estado registrado '
        'para esta rutina en la fecha seleccionada.',
      );
    });
  });
}

RoutineStatusRecord _record({
  required String recordId,
  required String routineId,
  required DateTime date,
  RoutineStatus status = RoutineStatus.completed,
  String? observation,
  DateTime? createdAt,
}) {
  final created = createdAt ?? DateTime.utc(2026, 9, 20, 12);

  return RoutineStatusRecord(
    recordId: recordId,
    anonymousId: 'anonimo-test',
    routineId: routineId,
    date: date,
    status: status,
    observation: observation,
    createdAt: created,
    updatedAt: created,
  );
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository(this.routines);

  final List<Routine> routines;

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    return routines;
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

class _FakeRoutineStatusRepository
    implements RoutineStatusManagementRepository {
  RoutineStatusRecord? savedRecord;

  RoutineStatusRecord? updatedRecord;

  List<RoutineStatusRecord> existingRecords = const [];

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {
    savedRecord = record;
  }

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    return existingRecords;
  }

  @override
  Future<void> updateRoutineStatus(RoutineStatusRecord record) async {
    updatedRecord = record;
  }

  @override
  Future<void> deleteRoutineStatus({
    required String anonymousId,
    required String recordId,
  }) async {}
}

class _FakeRoutineStatusRecordIdGenerator
    implements RoutineStatusRecordIdGenerator {
  const _FakeRoutineStatusRecordIdGenerator();

  @override
  String generate() {
    return 'routine-status-test-id';
  }
}
