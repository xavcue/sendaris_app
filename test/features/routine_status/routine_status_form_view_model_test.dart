import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';
import 'package:sendaris/features/routine_status/domain/repositories/routine_status_repository.dart';
import 'package:sendaris/features/routine_status/domain/services/routine_status_record_factory.dart';
import 'package:sendaris/features/routine_status/domain/services/routine_status_record_id_generator.dart';
import 'package:sendaris/features/routine_status/presentation/viewmodels/routine_status_form_view_model.dart';

void main() {
  group('RoutineStatusFormViewModel', () {
    const anonymousId = 'anonimo-test';

    RoutineStatusFormViewModel createViewModel({
      List<Routine> routines = const [],
      _FakeRoutineStatusRepository? statusRepository,
    }) {
      return RoutineStatusFormViewModel(
        _FakeRoutineRepository(routines),
        statusRepository ?? _FakeRoutineStatusRepository(),
        const RoutineStatusRecordFactory(_FakeRoutineStatusRecordIdGenerator()),
        anonymousId: anonymousId,
        initialDate: DateTime(2026, 9, 6),
      );
    }

    test('recupera solo rutinas activas del seguimiento actual', () async {
      final viewModel = createViewModel(
        routines: const [
          Routine(
            routineId: 'rutina-b',
            anonymousId: anonymousId,
            name: 'Cena',
            isActive: true,
          ),
          Routine(
            routineId: 'rutina-inactiva',
            anonymousId: anonymousId,
            name: 'Dormir',
            isActive: false,
          ),
          Routine(
            routineId: 'rutina-a',
            anonymousId: anonymousId,
            name: 'Alistarse',
            isActive: true,
          ),
          Routine(
            routineId: 'rutina-otro',
            anonymousId: 'otro-anonimo',
            name: 'Otra rutina',
            isActive: true,
          ),
        ],
      );

      await viewModel.initialize();

      expect(
        viewModel.activeRoutines.map((routine) => routine.routineId).toList(),
        ['rutina-a', 'rutina-b'],
      );
    });

    test('requiere rutina y estado antes de guardar', () async {
      final viewModel = createViewModel();

      final result = await viewModel.save();

      expect(result, isFalse);

      expect(viewModel.routineError, isNotNull);

      expect(viewModel.statusError, isNotNull);
    });

    test('guarda un estado válido de rutina', () async {
      final repository = _FakeRoutineStatusRepository();

      final viewModel = createViewModel(
        routines: const [
          Routine(
            routineId: 'rutina-test',
            anonymousId: anonymousId,
            name: 'Preparar mochila',
            isActive: true,
          ),
        ],
        statusRepository: repository,
      );

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

    test('normaliza la fecha seleccionada sin hora', () {
      final viewModel = createViewModel();

      viewModel.selectDate(DateTime(2026, 9, 4, 23, 45));

      expect(viewModel.selectedDate, DateTime(2026, 9, 4));
    });
  });
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
  Future<void> deactivateRoutine({
    required String anonymousId,
    required String routineId,
  }) async {}
}

class _FakeRoutineStatusRepository implements RoutineStatusRepository {
  RoutineStatusRecord? savedRecord;

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {
    savedRecord = record;
  }

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    return const [];
  }
}

class _FakeRoutineStatusRecordIdGenerator
    implements RoutineStatusRecordIdGenerator {
  const _FakeRoutineStatusRecordIdGenerator();

  @override
  String generate() {
    return 'routine-status-test-id';
  }
}
