import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/models/duration_query.dart';
import 'package:sendaris/features/duration/domain/services/duration_calculator.dart';

void main() {
  group('DurationCalculator', () {
    test('calcula el promedio exacto de duraciones válidas', () {
      final result = DurationCalculator.calculate(
        query: _query(DurationMetricType.sleep),
        observations: [
          _observation(
            id: 's1',
            type: DurationMetricType.sleep,
            date: DateTime(2026, 9, 5),
            minutes: 420,
          ),
          _observation(
            id: 's2',
            type: DurationMetricType.sleep,
            date: DateTime(2026, 9, 6),
            minutes: 480,
          ),
          _observation(
            id: 's3',
            type: DurationMetricType.sleep,
            date: DateTime(2026, 9, 7),
            minutes: 450,
          ),
        ],
      );

      expect(result.validRecordCount, 3);

      expect(result.averageMinutes, 450);
    });

    test('incluye las fechas inicial y final del periodo', () {
      final result = DurationCalculator.calculate(
        query: _query(DurationMetricType.behavior),
        observations: [
          _observation(
            id: 'inicio',
            type: DurationMetricType.behavior,
            date: DateTime(2026, 9, 1),
            minutes: 10,
          ),
          _observation(
            id: 'fin',
            type: DurationMetricType.behavior,
            date: DateTime(2026, 9, 15),
            minutes: 20,
          ),
        ],
      );

      expect(result.validRecordCount, 2);

      expect(result.averageMinutes, 15);
    });

    test('excluye registros fuera del periodo', () {
      final result = DurationCalculator.calculate(
        query: _query(DurationMetricType.behavior),
        observations: [
          _observation(
            id: 'dentro',
            type: DurationMetricType.behavior,
            date: DateTime(2026, 9, 10),
            minutes: 15,
          ),
          _observation(
            id: 'fuera',
            type: DurationMetricType.behavior,
            date: DateTime(2026, 9, 20),
            minutes: 100,
          ),
        ],
      );

      expect(result.validRecordCount, 1);

      expect(result.averageMinutes, 15);
    });

    test('excluye registros de otro perfil anónimo', () {
      final result = DurationCalculator.calculate(
        query: _query(DurationMetricType.sleep),
        observations: [
          _observation(
            id: 'a',
            type: DurationMetricType.sleep,
            date: DateTime(2026, 9, 5),
            minutes: 420,
          ),
          _observation(
            id: 'b',
            anonymousId: 'perfil-b',
            type: DurationMetricType.sleep,
            date: DateTime(2026, 9, 5),
            minutes: 600,
          ),
        ],
      );

      expect(result.validRecordCount, 1);

      expect(result.averageMinutes, 420);
    });

    test('excluye observaciones de otra métrica', () {
      final result = DurationCalculator.calculate(
        query: _query(DurationMetricType.sleep),
        observations: [
          _observation(
            id: 's',
            type: DurationMetricType.sleep,
            date: DateTime(2026, 9, 5),
            minutes: 420,
          ),
          _observation(
            id: 'c',
            type: DurationMetricType.behavior,
            date: DateTime(2026, 9, 5),
            minutes: 30,
          ),
        ],
      );

      expect(result.validRecordCount, 1);

      expect(result.averageMinutes, 420);
    });

    test('excluye una duración incompleta', () {
      final result = DurationCalculator.calculate(
        query: _query(DurationMetricType.behavior),
        observations: [
          _observation(
            id: 'valido',
            type: DurationMetricType.behavior,
            date: DateTime(2026, 9, 5),
            minutes: 20,
          ),
          _observation(
            id: 'incompleto',
            type: DurationMetricType.behavior,
            date: DateTime(2026, 9, 6),
            minutes: null,
          ),
        ],
      );

      expect(result.validRecordCount, 1);

      expect(result.averageMinutes, 20);
    });

    test('excluye una duración inválida de conducta', () {
      final result = DurationCalculator.calculate(
        query: _query(DurationMetricType.behavior),
        observations: [
          _observation(
            id: 'cero',
            type: DurationMetricType.behavior,
            date: DateTime(2026, 9, 5),
            minutes: 0,
          ),
          _observation(
            id: 'negativo',
            type: DurationMetricType.behavior,
            date: DateTime(2026, 9, 6),
            minutes: -5,
          ),
        ],
      );

      expect(result.validRecordCount, 0);

      expect(result.averageMinutes, isNull);

      expect(result.hasSufficientData, isFalse);
    });

    test('respeta que desregulación actualmente admite duración cero', () {
      final result = DurationCalculator.calculate(
        query: _query(DurationMetricType.dysregulation),
        observations: [
          _observation(
            id: 'd1',
            type: DurationMetricType.dysregulation,
            date: DateTime(2026, 9, 5),
            minutes: 0,
          ),
          _observation(
            id: 'd2',
            type: DurationMetricType.dysregulation,
            date: DateTime(2026, 9, 6),
            minutes: 10,
          ),
        ],
      );

      expect(result.validRecordCount, 2);

      expect(result.averageMinutes, 5);
    });

    test('sin datos válidos no inventa un promedio numérico', () {
      final result = DurationCalculator.calculate(
        query: _query(DurationMetricType.sleep),
        observations: const [],
      );

      expect(result.observations, isEmpty);

      expect(result.averageMinutes, isNull);

      expect(result.hasSufficientData, isFalse);
    });
  });
}

DurationQuery _query(DurationMetricType type) {
  return DurationQuery.create(
    anonymousId: 'perfil-a',
    metricType: type,
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 15),
  );
}

DurationObservation _observation({
  required String id,
  required DurationMetricType type,
  required DateTime date,
  required int? minutes,
  String anonymousId = 'perfil-a',
}) {
  return DurationObservation(
    recordId: id,
    anonymousId: anonymousId,
    metricType: type,
    date: date,
    durationMinutes: minutes,
  );
}
