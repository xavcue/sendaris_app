import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/frequency/domain/models/frequency_metric_type.dart';
import 'package:sendaris/features/frequency/domain/validation/frequency_query_validator.dart';

void main() {
  group('FrequencyQueryValidator', () {
    test('acepta periodo y categoría válidos para conducta', () {
      final errors = FrequencyQueryValidator.validate(
        anonymousId: 'perfil-a',
        metricType: FrequencyMetricType.behavior,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
        categoryCode: 'conducta_repetitiva',
      );

      expect(errors, isEmpty);
    });

    test('rechaza una consulta sin periodo', () {
      final errors = FrequencyQueryValidator.validate(
        anonymousId: 'perfil-a',
        metricType: FrequencyMetricType.dysregulation,
      );

      expect(
        errors['period'],
        'Selecciona una fecha inicial y una fecha final.',
      );
    });

    test('rechaza un periodo incompleto', () {
      final errors = FrequencyQueryValidator.validate(
        anonymousId: 'perfil-a',
        metricType: FrequencyMetricType.dysregulation,
        startDate: DateTime(2026, 9, 1),
      );

      expect(
        errors['period'],
        'Selecciona una fecha inicial y una fecha final.',
      );
    });

    test('rechaza fecha inicial posterior a fecha final', () {
      final errors = FrequencyQueryValidator.validate(
        anonymousId: 'perfil-a',
        metricType: FrequencyMetricType.dysregulation,
        startDate: DateTime(2026, 9, 16),
        endDate: DateTime(2026, 9, 15),
      );

      expect(
        errors['period'],
        'La fecha inicial no puede ser posterior a la fecha final.',
      );
    });

    test('exige categoría cuando la métrica la requiere', () {
      final errors = FrequencyQueryValidator.validate(
        anonymousId: 'perfil-a',
        metricType: FrequencyMetricType.behavior,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
      );

      expect(errors['category'], 'Selecciona una categoría aplicable.');
    });

    test('rechaza una categoría desconocida', () {
      final errors = FrequencyQueryValidator.validate(
        anonymousId: 'perfil-a',
        metricType: FrequencyMetricType.feeding,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
        categoryCode: 'categoria_inexistente',
      );

      expect(errors['category'], 'La categoría seleccionada no es válida.');
    });

    test('desregulación acepta consulta sin categoría', () {
      final errors = FrequencyQueryValidator.validate(
        anonymousId: 'perfil-a',
        metricType: FrequencyMetricType.dysregulation,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
      );

      expect(errors, isEmpty);
    });

    test('desregulación rechaza una categoría', () {
      final errors = FrequencyQueryValidator.validate(
        anonymousId: 'perfil-a',
        metricType: FrequencyMetricType.dysregulation,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
        categoryCode: 'otra',
      );

      expect(
        errors['category'],
        'La métrica seleccionada no utiliza categorías.',
      );
    });

    test('situaciones atípicas permiten consulta sin categoría específica', () {
      final errors = FrequencyQueryValidator.validate(
        anonymousId: 'perfil-a',
        metricType: FrequencyMetricType.atypicalSituation,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
      );

      expect(errors, isEmpty);
    });

    test('rechaza un identificador anónimo inválido', () {
      final errors = FrequencyQueryValidator.validate(
        anonymousId: 'perfil/invalido',
        metricType: FrequencyMetricType.dysregulation,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
      );

      expect(errors['anonymousId'], 'El perfil activo no es válido.');
    });
  });
}
