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
  test('rechaza un segundo estado para la misma rutina y fecha', () async {
    const anonymousId = 'anonimo-test';

    const routineId = 'rutina-test';

    final existingRecord = RoutineStatusRecord(
      recordId: 'estado-existente',
      anonymousId: anonymousId,
      routineId: routineId,
      date: DateTime(2026, 9, 6),
      status: RoutineStatus.modified,
      observation: 'Registro existente.',
      createdAt: DateTime.utc(2026, 9, 6, 20),
      updatedAt: DateTime.utc(2026, 9, 6, 20),
    );

    final routineRepository = _FakeRoutineRepository(const [
      Routine(
        routineId: routineId,
        anonymousId: anonymousId,
        name: 'Rutina de prueba',
        isActive: true,
      ),
    ]);

    final statusRepository = _FakeRoutineStatusRepository(
      existingRecords: [existingRecord],
    );

    final viewModel = RoutineStatusFormViewModel(
      routineRepository,
      statusRepository,
      const RoutineStatusRecordFactory(_FakeRoutineStatusRecordIdGenerator()),
      anonymousId: anonymousId,
      initialDate: DateTime(2026, 9, 6),
    );

    await viewModel.initialize();

    viewModel.selectRoutine(routineId);

    viewModel.selectStatus(RoutineStatus.completed);

    final success = await viewModel.save();

    expect(success, isFalse);

    expect(
      viewModel.errorMessage,
      'Ya existe un estado registrado '
      'para esta rutina en la fecha '
      'seleccionada.',
    );

    expect(statusRepository.saveCalls, 0);
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
  _FakeRoutineStatusRepository({required this.existingRecords});

  final List<RoutineStatusRecord> existingRecords;

  int saveCalls = 0;

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    return existingRecords;
  }

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {
    saveCalls++;
  }
}

class _FakeRoutineStatusRecordIdGenerator
    implements RoutineStatusRecordIdGenerator {
  const _FakeRoutineStatusRecordIdGenerator();

  @override
  String generate() {
    return 'nuevo-estado-test';
  }
}
