import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/duration/domain/exceptions/duration_query_validation_failure.dart';
import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_query.dart';

void main() {
  group('DurationQuery', () {
    test('normaliza identificador y fechas', () {
      final query = DurationQuery.create(
        anonymousId: ' perfil-a ',
        metricType: DurationMetricType.sleep,
        startDate: DateTime(2026, 9, 1, 18, 30),
        endDate: DateTime(2026, 9, 15, 23, 59),
      );

      expect(query.anonymousId, 'perfil-a');

      expect(query.startDate, DateTime(2026, 9, 1));

      expect(query.endDate, DateTime(2026, 9, 15));
    });

    test('conserva el tipo de métrica seleccionado', () {
      final query = DurationQuery.create(
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.behavior,
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 15),
      );

      expect(query.metricType, DurationMetricType.behavior);
    });

    test('rechaza criterios inválidos', () {
      expect(
        () => DurationQuery.create(
          anonymousId: 'perfil-a',
          metricType: DurationMetricType.sleep,
          startDate: DateTime(2026, 9, 20),
          endDate: DateTime(2026, 9, 10),
        ),
        throwsA(isA<DurationQueryValidationFailure>()),
      );
    });
  });
}
