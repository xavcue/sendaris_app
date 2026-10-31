import 'package:flutter/material.dart';

import '../../domain/models/duration_metric_type.dart';
import '../../domain/models/duration_observation.dart';
import '../../domain/models/duration_result.dart';
import '../../domain/services/duration_overview_service.dart';
import '../formatters/duration_display_formatter.dart';
import 'duration_observation_chart.dart';

class DurationSummaryCards extends StatelessWidget {
  const DurationSummaryCards({required this.overview, super.key});

  final DurationOverview overview;

  static String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  /// Punto de entrada compartido por Duraciones, Comparar periodos,
  /// Reportes internos y el generador PDF.
  static String formatDuration(DurationMetricType type, double minutes) {
    return DurationDisplayFormatter.format(type, minutes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen del periodo',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${formatDate(overview.startDate)} – '
          '${formatDate(overview.endDate)}',
          key: const Key('duration-overview-period'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Los promedios consideran únicamente registros '
          'con una duración válida.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        for (final type in DurationMetricType.values) ...[
          _DurationSummaryCard(type: type, result: overview.resultFor(type)),
          const SizedBox(height: 12),
        ],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: colors.onSurfaceVariant,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Estos resultados son descriptivos y no '
                  'representan una evaluación clínica.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DurationSummaryCard extends StatelessWidget {
  const _DurationSummaryCard({required this.type, required this.result});

  final DurationMetricType type;
  final DurationResult result;

  IconData get _icon {
    return switch (type) {
      DurationMetricType.sleep => Icons.bedtime_outlined,
      DurationMetricType.behavior => Icons.psychology_outlined,
      DurationMetricType.dysregulation => Icons.self_improvement_rounded,
    };
  }

  String get _title {
    return switch (type) {
      DurationMetricType.sleep => 'Sueño',
      DurationMetricType.behavior => 'Conducta',
      DurationMetricType.dysregulation => 'Desregulación',
    };
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

    final count = result.validRecordCount;
    final hasData = result.hasSufficientData;
    final average = result.averageMinutes;

    final formattedAverage = hasData && average != null
        ? DurationSummaryCards.formatDuration(type, average)
        : 'Sin datos';

    return Card(
      key: Key('duration-summary-${type.name}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 17, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: _accentColor.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.20 : 0.13,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(_icon, color: _accentColor, size: 25),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formattedAverage,
                        key: Key('duration-summary-value-${type.name}'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: hasData
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasData
                            ? 'Duración promedio registrada'
                            : 'Sin duraciones válidas en el periodo',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Divider(color: colors.outlineVariant, height: 1),
            const SizedBox(height: 10),
            Text(
              '$count '
              '${count == 1 ? 'registro válido' : 'registros válidos'}',
              key: Key('duration-summary-count-${type.name}'),
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (hasData) ...[
              const SizedBox(height: 12),
              DurationObservationChart(type: type, result: result),
              const SizedBox(height: 7),
              ExpansionTile(
                key: Key('duration-summary-expansion-${type.name}'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  'Ver duraciones individuales',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                children: [
                  for (final observation in result.observations)
                    _DurationObservationRow(
                      observation: observation,
                      type: type,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DurationObservationRow extends StatelessWidget {
  const _DurationObservationRow({
    required this.observation,
    required this.type,
  });

  final DurationObservation observation;
  final DurationMetricType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final minutes = observation.durationMinutes;

    if (minutes == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      key: Key('duration-observation-${observation.recordId}'),
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
      child: Row(
        children: [
          Icon(Icons.event_note_outlined, color: colors.primary, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              DurationSummaryCards.formatDate(observation.date),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Text(
            DurationSummaryCards.formatDuration(type, minutes.toDouble()),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
