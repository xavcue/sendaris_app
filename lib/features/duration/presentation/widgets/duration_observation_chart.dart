import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/models/duration_metric_type.dart';
import '../../domain/models/duration_observation.dart';
import '../../domain/models/duration_result.dart';
import '../formatters/duration_display_formatter.dart';

class DurationObservationChart extends StatelessWidget {
  const DurationObservationChart({
    required this.type,
    required this.result,
    super.key,
  });

  final DurationMetricType type;
  final DurationResult result;

  static String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  /// Conserva la API de formato utilizada anteriormente por el gráfico.
  /// Para valores con horas emplea el formato propio de sueño.
  static String formatMinutes(double minutes) {
    return DurationDisplayFormatter.format(DurationMetricType.sleep, minutes);
  }

  String _formatObservation(double minutes) {
    return DurationDisplayFormatter.format(type, minutes);
  }

  Color get _accentColor {
    return switch (type) {
      DurationMetricType.sleep => const Color(0xFF6679B8),
      DurationMetricType.behavior => const Color(0xFFE56F61),
      DurationMetricType.dysregulation => const Color(0xFF8173AE),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final observations =
        result.observations
            .where(
              (observation) =>
                  observation.durationMinutes != null &&
                  type.isValidDuration(observation.durationMinutes),
            )
            .toList()
          ..sort((a, b) {
            final byDate = b.date.compareTo(a.date);

            if (byDate != 0) {
              return byDate;
            }

            return a.recordId.compareTo(b.recordId);
          });

    final visible = observations.take(5).toList();

    final maximum = visible.fold<int>(
      0,
      (maxValue, observation) =>
          math.max(maxValue, observation.durationMinutes!),
    );

    return Card(
      key: Key('duration-observation-chart-${type.name}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Duraciones registradas: ${type.label}',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Hasta cinco registros válidos, del más reciente '
              'al más antiguo. Las barras se comparan '
              'únicamente dentro de esta categoría.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            if (visible.isEmpty)
              Text(
                'Sin duraciones válidas para representar.',
                key: Key('duration-chart-empty-${type.name}'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              )
            else
              for (var index = 0; index < visible.length; index++) ...[
                _DurationChartRow(
                  observation: visible[index],
                  type: type,
                  index: index,
                  maximum: maximum,
                  color: _accentColor,
                  formattedValue: _formatObservation(
                    visible[index].durationMinutes!.toDouble(),
                  ),
                ),
                if (index != visible.length - 1) const SizedBox(height: 16),
              ],
            if (observations.length > visible.length) ...[
              const SizedBox(height: 12),
              Text(
                'Se muestran ${visible.length} de '
                '${observations.length} duraciones válidas.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DurationChartRow extends StatelessWidget {
  const _DurationChartRow({
    required this.observation,
    required this.type,
    required this.index,
    required this.maximum,
    required this.color,
    required this.formattedValue,
  });

  final DurationObservation observation;
  final DurationMetricType type;
  final int index;
  final int maximum;
  final Color color;
  final String formattedValue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final minutes = observation.durationMinutes!;

    final fraction = maximum == 0
        ? 0.0
        : (minutes / maximum).clamp(0.0, 1.0).toDouble();

    return Semantics(
      label:
          '${type.label}, '
          '${formatDate(observation.date)}, '
          '$formattedValue',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  formatDate(observation.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$formattedValue · registro',
                key: Key('duration-chart-value-${type.name}-$index'),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          LinearProgressIndicator(
            key: Key('duration-chart-bar-${type.name}-$index'),
            value: fraction,
            minHeight: 10,
            borderRadius: BorderRadius.circular(8),
            color: color,
            backgroundColor: colors.surfaceContainerHighest,
          ),
        ],
      ),
    );
  }

  static String formatDate(DateTime date) {
    return DurationObservationChart.formatDate(date);
  }
}
