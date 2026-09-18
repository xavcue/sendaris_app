import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/frequency/domain/models/frequency_event.dart';
import 'package:sendaris/features/frequency/domain/models/frequency_metric_type.dart';
import 'package:sendaris/features/frequency/domain/models/frequency_query.dart';
import 'package:sendaris/features/frequency/domain/models/frequency_result.dart';
import 'package:sendaris/features/frequency/domain/services/frequency_calculator.dart';

void main() {
  group('FrequencyCalculator', () {
    test(
      'cuenta exactamente conducta de la categoría y periodo seleccionados',
      () {
        final query = _behaviorQuery();

        final result = FrequencyCalculator.calculate(
          query: query,
          events: [
            _event(
              id: 'inicio',
              metric: FrequencyMetricType.behavior,
              date: DateTime(2026, 9, 1),
              category: 'conducta_repetitiva',
            ),
            _event(
              id: 'fin',
              metric: FrequencyMetricType.behavior,
              date: DateTime(2026, 9, 15),
              category: 'conducta_repetitiva',
            ),
            _event(
              id: 'otra-categoria',
              metric: FrequencyMetricType.behavior,
              date: DateTime(2026, 9, 10),
              category: 'iniciativa_social',
            ),
            _event(
              id: 'fuera-periodo',
              metric: FrequencyMetricType.behavior,
              date: DateTime(2026, 9, 16),
              category: 'conducta_repetitiva',
            ),
          ],
        );

        expect(result.count, 2);
      },
    );

    test('no mezcla registros de otro identificador anónimo', () {
      final result = FrequencyCalculator.calculate(
        query: _behaviorQuery(),
        events: [
          _event(
            id: 'perfil-a',
            metric: FrequencyMetricType.behavior,
            date: DateTime(2026, 9, 5),
            category: 'conducta_repetitiva',
          ),
          _event(
            id: 'perfil-b',
            anonymousId: 'perfil-b',
            metric: FrequencyMetricType.behavior,
            date: DateTime(2026, 9, 5),
            category: 'conducta_repetitiva',
          ),
        ],
      );

      expect(result.count, 1);
    });

    test('no incluye registros de otra métrica', () {
      final result = FrequencyCalculator.calculate(
        query: _behaviorQuery(),
        events: [
          _event(
            id: 'conducta',
            metric: FrequencyMetricType.behavior,
            date: DateTime(2026, 9, 5),
            category: 'conducta_repetitiva',
          ),
          _event(
            id: 'social',
            metric: FrequencyMetricType.socialInteraction,
            date: DateTime(2026, 9, 5),
            category: 'conducta_repetitiva',
          ),
        ],
      );

      expect(result.count, 1);
    });

    test('cuenta episodios de desregulación sin categoría', () {
      final query = FrequencyQuery.create(
        anonymousId: 'perfil-a',
        metricType: FrequencyMetricType.dysregulation,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
      );

      final result = FrequencyCalculator.calculate(
        query: query,
        events: [
          _event(
            id: 'd1',
            metric: FrequencyMetricType.dysregulation,
            date: DateTime(2026, 9, 4),
          ),
          _event(
            id: 'd2',
            metric: FrequencyMetricType.dysregulation,
            date: DateTime(2026, 9, 12),
          ),
        ],
      );

      expect(result.count, 2);
    });

    test('situaciones atípicas sin categoría cuentan todas las categorías', () {
      final query = FrequencyQuery.create(
        anonymousId: 'perfil-a',
        metricType: FrequencyMetricType.atypicalSituation,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
      );

      final result = FrequencyCalculator.calculate(
        query: query,
        events: [
          _event(
            id: 'a1',
            metric: FrequencyMetricType.atypicalSituation,
            date: DateTime(2026, 9, 4),
            category: 'cambio_entorno',
          ),
          _event(
            id: 'a2',
            metric: FrequencyMetricType.atypicalSituation,
            date: DateTime(2026, 9, 5),
            category: 'evento_inesperado',
          ),
        ],
      );

      expect(result.count, 2);
    });

    test('situaciones atípicas permiten limitar el conteo por categoría', () {
      final query = FrequencyQuery.create(
        anonymousId: 'perfil-a',
        metricType: FrequencyMetricType.atypicalSituation,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
        categoryCode: 'evento_inesperado',
      );

      final result = FrequencyCalculator.calculate(
        query: query,
        events: [
          _event(
            id: 'a1',
            metric: FrequencyMetricType.atypicalSituation,
            date: DateTime(2026, 9, 4),
            category: 'cambio_entorno',
          ),
          _event(
            id: 'a2',
            metric: FrequencyMetricType.atypicalSituation,
            date: DateTime(2026, 9, 5),
            category: 'evento_inesperado',
          ),
        ],
      );

      expect(result.count, 1);
    });

    test('devuelve cero cuando no existen coincidencias', () {
      final result = FrequencyCalculator.calculate(
        query: _behaviorQuery(),
        events: const [],
      );

      expect(result.count, 0);
    });

    test('recalcula a partir de los registros fuente actuales', () {
      final query = _behaviorQuery();

      final initial = FrequencyCalculator.calculate(
        query: query,
        events: [
          _event(
            id: 'r1',
            metric: FrequencyMetricType.behavior,
            date: DateTime(2026, 9, 5),
            category: 'conducta_repetitiva',
          ),
        ],
      );

      final updated = FrequencyCalculator.calculate(
        query: query,
        events: [
          _event(
            id: 'r1',
            metric: FrequencyMetricType.behavior,
            date: DateTime(2026, 9, 5),
            category: 'conducta_repetitiva',
          ),
          _event(
            id: 'r2',
            metric: FrequencyMetricType.behavior,
            date: DateTime(2026, 9, 6),
            category: 'conducta_repetitiva',
          ),
        ],
      );

      expect(initial.count, 1);

      expect(updated.count, 2);
    });

    test('FrequencyResult impide una frecuencia negativa', () {
      expect(
        () => FrequencyResult(query: _behaviorQuery(), count: -1),
        throwsArgumentError,
      );
    });
  });
}

FrequencyQuery _behaviorQuery() {
  return FrequencyQuery.create(
    anonymousId: 'perfil-a',
    metricType: FrequencyMetricType.behavior,
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 15),
    categoryCode: 'conducta_repetitiva',
  );
}

FrequencyEvent _event({
  required String id,
  required FrequencyMetricType metric,
  required DateTime date,
  String anonymousId = 'perfil-a',
  String? category,
}) {
  return FrequencyEvent(
    recordId: id,
    anonymousId: anonymousId,
    metricType: metric,
    date: date,
    categoryCode: category,
  );
}
