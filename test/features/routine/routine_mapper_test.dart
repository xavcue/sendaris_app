import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/data/mappers/routine_mapper.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';

void main() {
  group('RoutineMapper', () {
    test('persiste únicamente los campos permitidos', () {
      const routine = Routine(
        routineId: 'routine-test-id',
        anonymousId: 'anonimo-test',
        name: 'Preparar mochila',
        description: 'Revisar materiales',
        scheduledTime: '20:00',
        recurrence: 'diaria',
      );

      final data = RoutineMapper.toFirestore(routine);

      expect(data.keys.toSet(), equals(RoutineMapper.allowedFields));

      expect(data.containsKey('routineId'), isFalse);

      expect(data.containsKey('anonymousId'), isFalse);

      expect(data['nombre'], 'Preparar mochila');

      expect(data['descripcion'], 'Revisar materiales');

      expect(data['horaProgramada'], '20:00');

      expect(data['recurrencia'], 'diaria');
    });

    test('omite campos opcionales cuando no aplican', () {
      const routine = Routine(
        routineId: 'routine-test-id',
        anonymousId: 'anonimo-test',
        name: 'Cena',
      );

      final data = RoutineMapper.toFirestore(routine);

      expect(data.keys.toSet(), {'nombre'});

      expect(data.containsKey('descripcion'), isFalse);

      expect(data.containsKey('horaProgramada'), isFalse);

      expect(data.containsKey('recurrencia'), isFalse);
    });

    test('reconstruye una rutina válida desde Firestore', () {
      final routine = RoutineMapper.fromFirestore(
        routineId: 'routine-test-id',
        anonymousId: 'anonimo-test',
        data: const {
          'nombre': 'Preparar mochila',
          'descripcion': 'Revisar materiales',
          'horaProgramada': '20:00',
          'recurrencia': 'semanal',
        },
      );

      expect(routine.routineId, 'routine-test-id');

      expect(routine.anonymousId, 'anonimo-test');

      expect(routine.name, 'Preparar mochila');

      expect(routine.description, 'Revisar materiales');

      expect(routine.scheduledTime, '20:00');

      expect(routine.recurrence, 'semanal');
    });

    test('rechaza una rutina con campos adicionales', () {
      expect(
        () => RoutineMapper.fromFirestore(
          routineId: 'routine-test-id',
          anonymousId: 'anonimo-test',
          data: const {'nombre': 'Cena', 'nombreNino': 'Dato prohibido'},
        ),
        throwsFormatException,
      );
    });

    test('rechaza una recurrencia fuera del catálogo', () {
      expect(
        () => RoutineMapper.fromFirestore(
          routineId: 'routine-test-id',
          anonymousId: 'anonimo-test',
          data: const {'nombre': 'Cena', 'recurrencia': 'invalida'},
        ),
        throwsFormatException,
      );
    });
  });
}
