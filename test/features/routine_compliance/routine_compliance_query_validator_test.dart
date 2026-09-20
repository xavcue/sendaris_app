import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine_compliance/domain/validation/routine_compliance_query_validator.dart';

void main() {
  group('RoutineComplianceQueryValidator', () {
    test('acepta un perfil y periodo válidos', () {
      final errors = RoutineComplianceQueryValidator.validate(
        anonymousId: 'perfil-a',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
      );

      expect(errors, isEmpty);
    });

    test('rechaza un periodo ausente', () {
      final errors = RoutineComplianceQueryValidator.validate(
        anonymousId: 'perfil-a',
      );

      expect(
        errors['period'],
        'Selecciona una fecha inicial y una fecha final.',
      );
    });

    test('rechaza un periodo incompleto', () {
      final errors = RoutineComplianceQueryValidator.validate(
        anonymousId: 'perfil-a',
        startDate: DateTime(2026, 9, 1),
      );

      expect(
        errors['period'],
        'Selecciona una fecha inicial y una fecha final.',
      );
    });

    test('rechaza fecha inicial posterior a fecha final', () {
      final errors = RoutineComplianceQueryValidator.validate(
        anonymousId: 'perfil-a',
        startDate: DateTime(2026, 9, 20),
        endDate: DateTime(2026, 9, 10),
      );

      expect(
        errors['period'],
        'La fecha inicial no puede ser posterior '
        'a la fecha final.',
      );
    });

    test('rechaza un identificador anónimo inválido', () {
      final errors = RoutineComplianceQueryValidator.validate(
        anonymousId: 'perfil/invalido',
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
      );

      expect(errors['anonymousId'], 'El perfil activo no es válido.');
    });
  });
}
