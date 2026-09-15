import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/dysregulation/domain/validation/dysregulation_record_validator.dart';

void main() {
  group('DysregulationRecordValidator', () {
    test('acepta un episodio con datos opcionales válidos', () {
      final errors = DysregulationRecordValidator.validate(
        anonymousId: 'seguimiento-anonimo',
        time: '14:30',
        durationMinutes: 12,
      );

      expect(errors, isEmpty);
    });

    test('acepta duración igual a cero', () {
      final errors = DysregulationRecordValidator.validate(
        anonymousId: 'seguimiento-anonimo',
        durationMinutes: 0,
      );

      expect(errors.containsKey('durationMinutes'), isFalse);
    });

    test('rechaza duración negativa', () {
      final errors = DysregulationRecordValidator.validate(
        anonymousId: 'seguimiento-anonimo',
        durationMinutes: -1,
      );

      expect(errors['durationMinutes'], 'La duración no puede ser negativa.');
    });

    test('rechaza una hora fuera del formato permitido', () {
      final errors = DysregulationRecordValidator.validate(
        anonymousId: 'seguimiento-anonimo',
        time: '25:90',
      );

      expect(errors['time'], isNotNull);
    });

    test('rechaza un identificador anónimo vacío', () {
      final errors = DysregulationRecordValidator.validate(anonymousId: '   ');

      expect(errors['anonymousId'], isNotNull);
    });

    test('rechaza un identificador anónimo con separador de ruta', () {
      final errors = DysregulationRecordValidator.validate(
        anonymousId: 'perfil/invalido',
      );

      expect(errors['anonymousId'], isNotNull);
    });
  });
}
