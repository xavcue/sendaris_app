import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/presentation/formatters/duration_display_formatter.dart';
import 'package:sendaris/features/duration/presentation/widgets/duration_observation_chart.dart';
import 'package:sendaris/features/duration/presentation/widgets/duration_summary_cards.dart';

void main() {
  group('HU-16 - Formato uniforme de duraciones', () {
    test('presenta promedios fraccionarios de sueño sin decimales', () {
      expect(
        DurationDisplayFormatter.format(DurationMetricType.sleep, 462.5),
        '7 h 42 min 30 s',
      );

      expect(
        DurationDisplayFormatter.format(DurationMetricType.sleep, 538.3),
        '8 h 58 min 18 s',
      );
    });

    test('presenta minutos y segundos en conducta y desregulación', () {
      expect(
        DurationDisplayFormatter.format(DurationMetricType.behavior, 8.5),
        '8 min 30 s',
      );

      expect(
        DurationDisplayFormatter.format(DurationMetricType.dysregulation, 12.5),
        '12 min 30 s',
      );
    });

    test('conserva la representación de las duraciones enteras', () {
      expect(
        DurationDisplayFormatter.format(DurationMetricType.sleep, 480),
        '8 h',
      );

      expect(
        DurationDisplayFormatter.format(DurationMetricType.sleep, 450),
        '7 h 30 min',
      );

      expect(
        DurationDisplayFormatter.format(DurationMetricType.behavior, 12),
        '12 min',
      );

      expect(
        DurationDisplayFormatter.format(DurationMetricType.dysregulation, 0),
        '0 min',
      );
    });

    test('mantiene minutos totales para eventos que superan una hora', () {
      expect(
        DurationDisplayFormatter.format(DurationMetricType.behavior, 65.5),
        '65 min 30 s',
      );
    });

    test('redondea segundos y normaliza el cambio de hora', () {
      expect(
        DurationDisplayFormatter.format(DurationMetricType.sleep, 59.999),
        '1 h',
      );

      expect(
        DurationDisplayFormatter.format(DurationMetricType.sleep, 60.5),
        '1 h 30 s',
      );
    });

    test('no representa números negativos o no finitos', () {
      expect(
        DurationDisplayFormatter.format(DurationMetricType.sleep, -1),
        'Sin datos',
      );

      expect(
        DurationDisplayFormatter.format(
          DurationMetricType.behavior,
          double.nan,
        ),
        'Sin datos',
      );

      expect(
        DurationDisplayFormatter.format(
          DurationMetricType.dysregulation,
          double.infinity,
        ),
        'Sin datos',
      );
    });

    test('las tarjetas y los gráficos utilizan el mismo formato', () {
      const minutes = 462.5;
      const expected = '7 h 42 min 30 s';

      expect(
        DurationSummaryCards.formatDuration(DurationMetricType.sleep, minutes),
        expected,
      );

      expect(DurationObservationChart.formatMinutes(minutes), expected);
    });

    test('los promedios de conducta se presentan sin decimales', () {
      expect(
        DurationSummaryCards.formatDuration(DurationMetricType.behavior, 8.5),
        '8 min 30 s',
      );
    });
  });
}
