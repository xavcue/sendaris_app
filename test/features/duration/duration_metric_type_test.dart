import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';

void main() {
  group('DurationMetricType', () {
    test('expone únicamente las tres fuentes con duración aplicable', () {
      expect(DurationMetricType.values, hasLength(3));

      expect(DurationMetricType.values.map((type) => type.code).toList(), [
        'sueno',
        'conducta',
        'desregulacion',
      ]);
    });

    test('mantiene la trazabilidad de los indicadores de promedio', () {
      expect(DurationMetricType.sleep.averageIndicatorCode, 'IND-02');

      expect(DurationMetricType.behavior.averageIndicatorCode, 'IND-05');

      expect(DurationMetricType.dysregulation.averageIndicatorCode, 'IND-07');
    });

    test('sueño mantiene IND-01 como indicador de duración individual', () {
      expect(DurationMetricType.sleep.individualIndicatorCode, 'IND-01');

      expect(DurationMetricType.behavior.individualIndicatorCode, isNull);

      expect(DurationMetricType.dysregulation.individualIndicatorCode, isNull);
    });

    test('aplica las reglas vigentes de duración válida', () {
      expect(DurationMetricType.sleep.isValidDuration(1), isTrue);

      expect(DurationMetricType.sleep.isValidDuration(0), isFalse);

      expect(DurationMetricType.behavior.isValidDuration(0), isFalse);

      expect(DurationMetricType.dysregulation.isValidDuration(0), isTrue);

      expect(DurationMetricType.dysregulation.isValidDuration(-1), isFalse);

      expect(DurationMetricType.behavior.isValidDuration(null), isFalse);
    });
  });
}
