import 'package:flutter/material.dart';

import '../../../routine_status/domain/models/routine_status.dart';
import '../../domain/services/routine_overview_service.dart';

/// Representacion grafica de los estados de rutina.
///
/// Los conteos y el denominador provienen de RoutineOverview.
/// No calcula nuevamente el cumplimiento ni recupera datos.
class RoutineStatusDistributionBar extends StatelessWidget {
  const RoutineStatusDistributionBar({required this.overview, super.key});

  final RoutineOverview overview;

  static Color colorFor(RoutineStatus status) {
    return switch (status) {
      RoutineStatus.completed => const Color(0xFF5CB9AA),
      RoutineStatus.modified => const Color(0xFF78AFC1),
      RoutineStatus.interrupted => const Color(0xFFC9A353),
      RoutineStatus.notCompleted => const Color(0xFFE56F61),
    };
  }

  String _percentageFor(RoutineStatus status) {
    final count = overview.countForStatus(status);
    final total = overview.totalRecords;

    if (total == 0) {
      return 'Sin datos';
    }

    return '${(count / total * 100).toStringAsFixed(1)} %';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = overview.totalRecords;

    return Card(
      key: const Key('routine-status-distribution-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 17, 17, 19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.stacked_bar_chart_rounded,
                  color: colors.primary,
                  size: 23,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Distribución visual de estados',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              total == 1
                  ? '1 estado de rutina registrado'
                  : '$total estados de rutina registrados',
              key: const Key('routine-status-distribution-total'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (total == 0)
              Text(
                'Sin estados registrados para representar.',
                key: const Key('routine-status-distribution-empty'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              )
            else ...[
              Semantics(
                label:
                    'Distribución de $total estados de rutina: '
                    '${[for (final status in RoutineStatus.values) '${status.label}: '
                          '${overview.countForStatus(status)}'].join(', ')}',
                child: ExcludeSemantics(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: SizedBox(
                      key: const Key('routine-status-distribution-track'),
                      height: 17,
                      child: Row(
                        children: [
                          for (final status in RoutineStatus.values)
                            if (overview.countForStatus(status) > 0)
                              Expanded(
                                key: Key(
                                  'routine-status-segment-${status.name}',
                                ),
                                flex: overview.countForStatus(status),
                                child: ColoredBox(color: colorFor(status)),
                              ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Column(
                key: const Key('routine-status-distribution-legend'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final status in RoutineStatus.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 11),
                      child: _StatusLegendItem(
                        status: status,
                        count: overview.countForStatus(status),
                        percentage: _percentageFor(status),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'Cada segmento representa la proporción '
                'del estado respecto al total registrado.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusLegendItem extends StatelessWidget {
  const _StatusLegendItem({
    required this.status,
    required this.count,
    required this.percentage,
  });

  final RoutineStatus status;
  final int count;
  final String percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: RoutineStatusDistributionBar.colorFor(status),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            '${status.label}: $count ($percentage)',
            key: Key('routine-status-legend-${status.name}'),
            softWrap: true,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}
