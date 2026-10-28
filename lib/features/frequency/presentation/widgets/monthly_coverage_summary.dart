import 'package:flutter/material.dart';

import '../../domain/models/monthly_calendar_record.dart';
import '../../domain/services/coverage_calculator.dart';

class MonthlyCoverageSummary extends StatelessWidget {
  const MonthlyCoverageSummary({
    required this.index,
    required this.visibleMonth,
    required this.startDate,
    required this.endDate,
    required this.isLoading,
    required this.hasError,
    super.key,
  });

  final MonthlyCalendarIndex? index;
  final DateTime visibleMonth;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isLoading;
  final bool hasError;

  static String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || hasError || index == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final monthStart = DateTime(visibleMonth.year, visibleMonth.month);

    final monthEnd = DateTime(visibleMonth.year, visibleMonth.month + 1, 0);

    final normalizedStart = startDate == null
        ? null
        : DateTime(startDate!.year, startDate!.month, startDate!.day);

    final normalizedEnd = endDate == null
        ? null
        : DateTime(endDate!.year, endDate!.month, endDate!.day);

    final effectiveStart =
        normalizedStart != null && normalizedStart.isAfter(monthStart)
        ? normalizedStart
        : monthStart;

    final effectiveEnd =
        normalizedEnd != null && normalizedEnd.isBefore(monthEnd)
        ? normalizedEnd
        : monthEnd;

    if (effectiveStart.isAfter(effectiveEnd)) {
      return Card(
        key: const Key('monthly-calendar-coverage-outside-range'),
        margin: EdgeInsets.zero,
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Text('El mes visible está fuera del período seleccionado.'),
        ),
      );
    }

    final result = CoverageCalculator.calculate(
      index: index!,
      startDate: effectiveStart,
      endDate: effectiveEnd,
    );

    final percentageText = result.percentage % 1 == 0
        ? result.percentage.toStringAsFixed(0)
        : result.percentage.toStringAsFixed(1);

    return Card(
      key: const Key('monthly-calendar-coverage-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: colors.primary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cobertura de registros',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$percentageText %',
                  key: const Key('monthly-calendar-coverage-percentage'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              key: const Key('monthly-calendar-coverage-progress'),
              value: result.percentage / 100,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: colors.surfaceContainerHighest,
            ),
            const SizedBox(height: 9),
            Text(
              '${result.daysWithRecords} de '
              '${result.totalDays} días con registros',
              key: const Key('monthly-calendar-coverage-days'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Período: ${_formatDate(result.startDate)} '
              '– ${_formatDate(result.endDate)}',
              key: const Key('monthly-calendar-coverage-period'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
