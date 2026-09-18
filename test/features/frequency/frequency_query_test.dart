import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/frequency/domain/exceptions/frequency_query_validation_failure.dart';
import 'package:sendaris/features/frequency/domain/models/frequency_metric_type.dart';
import 'package:sendaris/features/frequency/domain/models/frequency_query.dart';

void main() {
  group('FrequencyQuery', () {
    test('normaliza identificador fechas y categoría', () {
      final query = FrequencyQuery.create(
        anonymousId: ' perfil-a ',
        metricType: FrequencyMetricType.behavior,
        startDate: DateTime(2026, 9, 1, 18, 30),
        endDate: DateTime(2026, 9, 15, 23, 59),
        categoryCode: ' conducta_repetitiva ',
      );

      expect(query.anonymousId, 'perfil-a');

      expect(query.startDate, DateTime(2026, 9, 1));

      expect(query.endDate, DateTime(2026, 9, 15));

      expect(query.categoryCode, 'conducta_repetitiva');

      expect(query.hasCategory, isTrue);
    });

    test('conserva categoría nula cuando es opcional', () {
      final query = FrequencyQuery.create(
        anonymousId: 'perfil-a',
        metricType: FrequencyMetricType.atypicalSituation,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
      );

      expect(query.categoryCode, isNull);

      expect(query.hasCategory, isFalse);
    });

    test('rechaza la creación con criterios inválidos', () {
      expect(
        () => FrequencyQuery.create(
          anonymousId: 'perfil-a',
          metricType: FrequencyMetricType.behavior,
          startDate: DateTime(2026, 9, 16),
          endDate: DateTime(2026, 9, 15),
        ),
        throwsA(isA<FrequencyQueryValidationFailure>()),
      );
    });
  });
}
