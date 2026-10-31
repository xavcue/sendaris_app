import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Barras A/B de una unica metrica descriptiva.
///
/// Para duraciones, la escala es el mayor valor disponible.
/// Para porcentajes, la escala fija es 100.
/// Una ausencia de datos (null) nunca se interpreta como cero.
class PeriodComparisonBarChart extends StatelessWidget {
  const PeriodComparisonBarChart({
    required this.metricKey,
    required this.valueA,
    required this.valueB,
    required this.displayA,
    required this.displayB,
    required this.unit,
    required this.isPercentage,
    super.key,
  });

  final String metricKey;
  final double? valueA;
  final double? valueB;
  final String displayA;
  final String displayB;
  final String unit;
  final bool isPercentage;

  double? _safeValue(double? value) {
    if (value == null || !value.isFinite || value < 0) {
      return null;
    }

    if (isPercentage && value > 100) {
      return null;
    }

    return value;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final a = _safeValue(valueA);
    final b = _safeValue(valueB);

    final maximum = isPercentage ? 100.0 : math.max(a ?? 0.0, b ?? 0.0);

    return Column(
      key: Key('period-comparison-chart-$metricKey'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 15),
        Text(
          'Comparación visual',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _ComparisonBar(
          metricKey: metricKey,
          slot: 'a',
          label: 'Periodo A',
          value: a,
          display: a == null ? 'Sin datos' : displayA,
          maximum: maximum,
          color: const Color(0xFF6679B8),
        ),
        const SizedBox(height: 13),
        _ComparisonBar(
          metricKey: metricKey,
          slot: 'b',
          label: 'Periodo B',
          value: b,
          display: b == null ? 'Sin datos' : displayB,
          maximum: maximum,
          color: const Color(0xFF5CB9AA),
        ),
        const SizedBox(height: 11),
        Text(
          isPercentage
              ? 'Escala común de 0 a 100 %.'
              : 'Escala común entre A y B, expresada en $unit.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

class _ComparisonBar extends StatelessWidget {
  const _ComparisonBar({
    required this.metricKey,
    required this.slot,
    required this.label,
    required this.value,
    required this.display,
    required this.maximum,
    required this.color,
  });

  final String metricKey;
  final String slot;
  final String label;
  final double? value;
  final String display;
  final double maximum;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final fraction = value == null || maximum <= 0
        ? 0.0
        : (value! / maximum).clamp(0.0, 1.0).toDouble();

    return Semantics(
      label: '$label: $display',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  label,
                  softWrap: true,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Text(
                  '$label · $display',
                  key: Key('period-comparison-chart-label-$metricKey-$slot'),
                  softWrap: true,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          if (value == null)
            Container(
              key: Key('period-comparison-chart-empty-$metricKey-$slot'),
              height: 11,
              decoration: BoxDecoration(
                color: colors.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
            )
          else
            LinearProgressIndicator(
              key: Key('period-comparison-chart-bar-$metricKey-$slot'),
              value: fraction,
              minHeight: 11,
              borderRadius: BorderRadius.circular(8),
              color: color,
              backgroundColor: colors.surfaceContainerHighest,
            ),
        ],
      ),
    );
  }
}
