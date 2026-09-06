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
        isActive: true,
      );

      final data = RoutineMapper.toFirestore(routine);

      expect(data.keys.toSet(), equals(RoutineMapper.allowedFields));

      expect(data.containsKey('routineId'), isFalse);

      expect(data.containsKey('anonymousId'), isFalse);

      expect(data['nombre'], 'Preparar mochila');

      expect(data['recurrencia'], 'diaria');

      expect(data['activa'], isTrue);
    });

    test('omite campos opcionales cuando no aplican', () {
      const routine = Routine(
        routineId: 'routine-test-id',
        anonymousId: 'anonimo-test',
        name: 'Cena',
        isActive: true,
      );

      final data = RoutineMapper.toFirestore(routine);

      expect(data.keys.toSet(), {'nombre', 'activa'});

      expect(data.containsKey('descripcion'), isFalse);

      expect(data.containsKey('horaProgramada'), isFalse);

      expect(data.containsKey('recurrencia'), isFalse);
    });

    test('reconstruye una rutina válida desde Firestore', () {
      final routine = RoutineMapper.fromFirestore(
        routineId: 'routine-test-id',
        anonymousId: 'anonimo-test',
        data: {
          'nombre': 'Preparar mochila',
          'descripcion': 'Revisar materiales',
          'horaProgramada': '20:00',
          'recurrencia': 'semanal',
          'activa': true,
        },
      );

      expect(routine.routineId, 'routine-test-id');

      expect(routine.anonymousId, 'anonimo-test');

      expect(routine.name, 'Preparar mochila');

      expect(routine.recurrence, 'semanal');

      expect(routine.isActive, isTrue);
    });

    test('rechaza una rutina con campos adicionales', () {
      expect(
        () => RoutineMapper.fromFirestore(
          routineId: 'routine-test-id',
          anonymousId: 'anonimo-test',
          data: {
            'nombre': 'Cena',
            'activa': true,
            'nombreNino': 'Dato prohibido',
          },
        ),
        throwsFormatException,
      );
    });

    test('rechaza una recurrencia fuera del catálogo', () {
      expect(
        () => RoutineMapper.fromFirestore(
          routineId: 'routine-test-id',
          anonymousId: 'anonimo-test',
          data: {'nombre': 'Cena', 'recurrencia': 'invalida', 'activa': true},
        ),
        throwsFormatException,
      );
    });
  });
}
