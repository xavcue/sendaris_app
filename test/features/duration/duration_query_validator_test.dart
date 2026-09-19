import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/validation/duration_query_validator.dart';

void main() {
  group('DurationQueryValidator', () {
    test('acepta un periodo válido', () {
      final errors = DurationQueryValidator.validate(
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.sleep,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
      );

      expect(errors, isEmpty);
    });

    test('rechaza un periodo ausente', () {
      final errors = DurationQueryValidator.validate(
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.sleep,
      );

      expect(
        errors['period'],
        'Selecciona una fecha inicial y una fecha final.',
      );
    });

    test('rechaza un periodo incompleto', () {
      final errors = DurationQueryValidator.validate(
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.behavior,
        startDate: DateTime(2026, 9, 1),
      );

      expect(
        errors['period'],
        'Selecciona una fecha inicial y una fecha final.',
      );
    });

    test('rechaza fecha inicial posterior a fecha final', () {
      final errors = DurationQueryValidator.validate(
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.dysregulation,
        startDate: DateTime(2026, 9, 20),
        endDate: DateTime(2026, 9, 10),
      );

      expect(
        errors['period'],
        'La fecha inicial no puede ser posterior a la fecha final.',
      );
    });

    test('rechaza un identificador anónimo inválido', () {
      final errors = DurationQueryValidator.validate(
        anonymousId: 'perfil/invalido',
        metricType: DurationMetricType.sleep,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
      );

      expect(errors['anonymousId'], 'El perfil activo no es válido.');
    });
  });
}
