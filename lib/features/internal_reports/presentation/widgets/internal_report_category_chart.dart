import 'package:flutter/material.dart';

import '../../../frequency/domain/models/monthly_calendar_record.dart';
import '../../domain/models/internal_report.dart';
import '../models/internal_report_display_data.dart';

/// Distribución descriptiva del reporte, sin nuevas consultas ni cálculos.
/// Usa el mismo modelo de presentación que se utilizará en el PDF.
class InternalReportCategoryChart extends StatelessWidget {
  const InternalReportCategoryChart({required this.report, super.key});

  final InternalReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final display = InternalReportDisplayData.fromReport(report);
    final categories = display.categories;
    final mainCategory = display.mostFrequentCategory;

    return Card(
      key: const Key('internal-report-category-chart'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(17, 18, 17, 19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: colors.primary, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Distribución de registros',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              'Cantidad y proporción de cada categoría en el periodo.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 15),
            if (mainCategory != null) ...[
              Container(
                key: const Key('internal-report-chart-highlight'),
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: 0.36),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: 0.22),
                  ),
                ),
                child: Wrap(
                  spacing: 18,
                  runSpacing: 10,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _SummaryValue(
                      label: 'MÁS FRECUENTE',
                      value: '${mainCategory.label} · ${mainCategory.count}',
                      accent: colors.onPrimaryContainer,
                    ),
                    _SummaryValue(
                      label: 'CATEGORÍAS CON REGISTROS',
                      value: '${categories.length}',
                      accent: colors.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (categories.isEmpty)
              Text(
                'Sin registros para representar.',
                key: const Key('internal-report-chart-empty'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              )
            else
              for (final category in categories) ...[
                _CategoryBar(category: category),
                if (!identical(category, categories.last))
                  const SizedBox(height: 17),
              ],
            const SizedBox(height: 15),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Cada barra usa la misma escala: 100 % es el total de '
                    '${display.totalRecords} registros. Las categorías '
                    'sin registros se omiten de este resumen.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            color: accent,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CategoryBar extends StatelessWidget {
  const _CategoryBar({required this.category});

  final InternalReportCategoryDisplay category;

  Color get accentColor => switch (category.type) {
    CalendarRecordType.behavior => const Color(0xFFE57A72),
    CalendarRecordType.sleep => const Color(0xFF8294D0),
    CalendarRecordType.feeding => const Color(0xFFE4AD62),
    CalendarRecordType.socialInteraction => const Color(0xFF7EAED2),
    CalendarRecordType.dysregulation => const Color(0xFFA08BCB),
    CalendarRecordType.atypicalSituation => const Color(0xFFC09B7C),
    CalendarRecordType.routineStatus => const Color(0xFF69BDAA),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final fraction = category.fraction.clamp(0.0, 1.0).toDouble();

    return Semantics(
      label:
          '${category.label}: ${category.count} de ${category.total} '
          'registros, ${category.percentageText}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${category.count} · ${category.percentageText}',
                key: Key('internal-report-chart-label-${category.type.name}'),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;

              return Container(
                key: Key('internal-report-chart-track-${category.type.name}'),
                height: 14,
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.centerLeft,
                child: Container(
                  key: Key('internal-report-chart-bar-${category.type.name}'),
                  height: 14,
                  width: width * fraction,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
