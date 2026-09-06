import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine_status/domain/exceptions/routine_status_validation_failure.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/services/routine_status_record_factory.dart';
import 'package:sendaris/features/routine_status/domain/services/routine_status_record_id_generator.dart';

void main() {
  group('RoutineStatusRecordFactory', () {
    const factory = RoutineStatusRecordFactory(
      _FakeRoutineStatusRecordIdGenerator(),
    );

    test('crea un estado válido asociado a rutina y seguimiento anónimo', () {
      final createdAt = DateTime.utc(2026, 9, 6, 18);

      final record = factory.create(
        anonymousId: ' anonimo-test ',
        routineId: ' rutina-test ',
        date: DateTime(2026, 9, 5, 17, 30),
        status: RoutineStatus.completed,
        observation: ' Actividad realizada ',
        createdAt: createdAt,
      );

      expect(record.recordId, 'routine-status-test-id');

      expect(record.anonymousId, 'anonimo-test');

      expect(record.routineId, 'rutina-test');

      expect(record.date, DateTime(2026, 9, 5));

      expect(record.status, RoutineStatus.completed);

      expect(record.observation, 'Actividad realizada');

      expect(record.createdAt, createdAt);

      expect(record.updatedAt, createdAt);
    });

    test('permite los cuatro estados definidos', () {
      for (final status in RoutineStatus.values) {
        final record = factory.create(
          anonymousId: 'anonimo-test',
          routineId: 'rutina-test',
          date: DateTime(2026, 9, 6),
          status: status,
        );

        expect(record.status, status);
      }
    });

    test('normaliza una observación vacía como nula', () {
      final record = factory.create(
        anonymousId: 'anonimo-test',
        routineId: 'rutina-test',
        date: DateTime(2026, 9, 6),
        status: RoutineStatus.modified,
        observation: '   ',
      );

      expect(record.observation, isNull);
    });

    test('rechaza una rutina sin identificador', () {
      expect(
        () => factory.create(
          anonymousId: 'anonimo-test',
          routineId: '   ',
          date: DateTime(2026, 9, 6),
          status: RoutineStatus.interrupted,
        ),
        throwsA(isA<RoutineStatusValidationFailure>()),
      );
    });
  });
}

class _FakeRoutineStatusRecordIdGenerator
    implements RoutineStatusRecordIdGenerator {
  const _FakeRoutineStatusRecordIdGenerator();

  @override
  String generate() {
    return 'routine-status-test-id';
  }
}
