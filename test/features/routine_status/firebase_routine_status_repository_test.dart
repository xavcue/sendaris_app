import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine_status/data/repositories/firebase_routine_status_repository.dart';
import 'package:sendaris/features/routine_status/data/services/routine_status_remote_service.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';

void main() {
  group('FirebaseRoutineStatusRepository', () {
    final record = RoutineStatusRecord(
      recordId: 'registro-test',
      anonymousId: 'anonimo-test',
      routineId: 'rutina-test',
      date: DateTime(2026, 9, 6),
      status: RoutineStatus.completed,
      createdAt: DateTime.utc(2026, 9, 6),
      updatedAt: DateTime.utc(2026, 9, 6),
    );

    test('delega el guardado al servicio remoto', () async {
      final service = _FakeRoutineStatusRemoteService();

      final repository = FirebaseRoutineStatusRepository(service);

      await repository.saveRoutineStatus(record);

      expect(service.savedRecord, same(record));
    });

    test('recupera los estados del servicio remoto', () async {
      final service = _FakeRoutineStatusRemoteService(
        recoveredRecords: [record],
      );

      final repository = FirebaseRoutineStatusRepository(service);

      final result = await repository.recoverRoutineStatuses(
        anonymousId: 'anonimo-test',
      );

      expect(result, hasLength(1));

      expect(result.single, same(record));
    });

    test('envía el identificador anónimo en la recuperación', () async {
      final service = _FakeRoutineStatusRemoteService();

      final repository = FirebaseRoutineStatusRepository(service);

      await repository.recoverRoutineStatuses(anonymousId: 'anonimo-test');

      expect(service.recoveredAnonymousId, 'anonimo-test');
    });
  });
}

class _FakeRoutineStatusRemoteService implements RoutineStatusRemoteService {
  _FakeRoutineStatusRemoteService({this.recoveredRecords = const []});

  final List<RoutineStatusRecord> recoveredRecords;

  RoutineStatusRecord? savedRecord;

  String? recoveredAnonymousId;

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {
    savedRecord = record;
  }

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    recoveredAnonymousId = anonymousId;

    return recoveredRecords;
  }
}
