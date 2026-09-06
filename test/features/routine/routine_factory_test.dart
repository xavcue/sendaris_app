import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/exceptions/routine_validation_failure.dart';
import 'package:sendaris/features/routine/domain/services/routine_factory.dart';
import 'package:sendaris/features/routine/domain/services/routine_id_generator.dart';

void main() {
  group('RoutineFactory', () {
    const factory = RoutineFactory(_FakeRoutineIdGenerator());

    test('crea una rutina válida asociada al seguimiento anónimo', () {
      final routine = factory.create(
        anonymousId: '550e8400-e29b-41d4-a716-446655440000',
        name: 'Preparar mochila',
        scheduledTime: '08:00',
        recurrence: 'diaria',
      );

      expect(routine.routineId, 'routine-test-id');

      expect(routine.anonymousId, '550e8400-e29b-41d4-a716-446655440000');

      expect(routine.name, 'Preparar mochila');

      expect(routine.scheduledTime, '08:00');

      expect(routine.recurrence, 'diaria');

      expect(routine.isActive, isTrue);
    });

    test('permite una recurrencia semanal', () {
      final routine = factory.create(
        anonymousId: 'anonimo-test',
        name: 'Organizar materiales',
        recurrence: 'semanal',
      );

      expect(routine.recurrence, 'semanal');
    });

    test('permite una recurrencia mensual', () {
      final routine = factory.create(
        anonymousId: 'anonimo-test',
        name: 'Revisar calendario',
        recurrence: 'mensual',
      );

      expect(routine.recurrence, 'mensual');
    });

    test('normaliza y omite campos opcionales vacíos', () {
      final routine = factory.create(
        anonymousId: 'anonimo-test',
        name: '  Cena  ',
        description: '   ',
        scheduledTime: '   ',
        recurrence: '   ',
      );

      expect(routine.name, 'Cena');

      expect(routine.description, isNull);

      expect(routine.scheduledTime, isNull);

      expect(routine.recurrence, isNull);
    });

    test('rechaza una rutina sin nombre', () {
      expect(
        () => factory.create(anonymousId: 'anonimo-test', name: '   '),
        throwsA(isA<RoutineValidationFailure>()),
      );
    });

    test('rechaza una hora inválida', () {
      expect(
        () => factory.create(
          anonymousId: 'anonimo-test',
          name: 'Cena',
          scheduledTime: '25:80',
        ),
        throwsA(isA<RoutineValidationFailure>()),
      );
    });

    test('rechaza una recurrencia fuera del catálogo', () {
      expect(
        () => factory.create(
          anonymousId: 'anonimo-test',
          name: 'Cena',
          recurrence: 'recurrencia_invalida',
        ),
        throwsA(isA<RoutineValidationFailure>()),
      );
    });

    test('permite modificar una rutina sin cambiar su identidad', () {
      final original = factory.create(
        anonymousId: 'anonimo-test',
        name: 'Preparar mochila',
        scheduledTime: '08:00',
        recurrence: 'diaria',
      );

      final updated = factory.update(
        routine: original,
        name: 'Preparar mochila escolar',
        scheduledTime: '07:45',
        recurrence: 'semanal',
      );

      expect(updated.routineId, original.routineId);

      expect(updated.anonymousId, original.anonymousId);

      expect(updated.name, 'Preparar mochila escolar');

      expect(updated.scheduledTime, '07:45');

      expect(updated.recurrence, 'semanal');
    });
  });
}

class _FakeRoutineIdGenerator implements RoutineIdGenerator {
  const _FakeRoutineIdGenerator();

  @override
  String generate() {
    return 'routine-test-id';
  }
}
