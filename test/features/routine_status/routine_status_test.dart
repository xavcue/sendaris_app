import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

void main() {
  group('RoutineStatus', () {
    test('define el catálogo funcional permitido', () {
      expect(RoutineStatus.values.map((status) => status.code).toList(), [
        'completada',
        'modificada',
        'interrumpida',
        'no_realizada',
      ]);

      expect(RoutineStatus.values.map((status) => status.label).toList(), [
        'Completada',
        'Modificada',
        'Interrumpida',
        'No realizada',
      ]);
    });

    test('rechaza un código fuera del catálogo', () {
      expect(
        () => RoutineStatus.fromCode('estado_invalido'),
        throwsFormatException,
      );
    });
  });
}
