import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../duration/domain/models/duration_metric_type.dart';
import '../../../duration/domain/repositories/duration_repository.dart';
import '../../../duration/presentation/widgets/duration_summary_cards.dart';
import '../../../routine_compliance/domain/repositories/routine_compliance_repository.dart';
import '../../domain/models/comparison_period.dart';
import '../../domain/models/period_comparison_result.dart';
import '../../domain/services/period_comparison_service.dart';
import '../viewmodels/period_comparison_view_model.dart';
import '../widgets/period_comparison_bar_chart.dart';

class PeriodComparisonView extends StatefulWidget {
  const PeriodComparisonView({
    required this.durationRepository,
    required this.routineComplianceRepository,
    required this.anonymousId,
    this.clock,
    super.key,
  });

  final DurationRepository durationRepository;
  final RoutineComplianceRepository routineComplianceRepository;
  final String anonymousId;
  final DateTime Function()? clock;

  @override
  State<PeriodComparisonView> createState() => _PeriodComparisonViewState();
}

class _PeriodComparisonViewState extends State<PeriodComparisonView> {
  late PeriodComparisonViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = _createViewModel();
  }

  PeriodComparisonViewModel _createViewModel() {
    return PeriodComparisonViewModel(
      PeriodComparisonService(
        durationRepository: widget.durationRepository,
        routineComplianceRepository: widget.routineComplianceRepository,
      ),
      anonymousId: widget.anonymousId,
      clock: widget.clock,
    );
  }

  @override
  void didUpdateWidget(covariant PeriodComparisonView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.anonymousId != widget.anonymousId ||
        oldWidget.durationRepository != widget.durationRepository ||
        oldWidget.routineComplianceRepository !=
            widget.routineComplianceRepository) {
      final previousViewModel = _viewModel;
      _viewModel = _createViewModel();
      previousViewModel.dispose();
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PeriodComparisonViewModel>.value(
      value: _viewModel,
      child: const _PeriodComparisonContent(),
    );
  }
}

class _PeriodComparisonContent extends StatelessWidget {
  const _PeriodComparisonContent();

  Future<void> _pickDate(
    BuildContext context,
    PeriodComparisonViewModel viewModel, {
    required ComparisonPeriodSlot slot,
    required bool isStartDate,
  }) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final firstDate = DateTime(2000);

    final period = viewModel.periodFor(slot);
    final current = isStartDate ? period.startDate : period.endDate;

    var initialDate = current;

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }

    if (initialDate.isAfter(today)) {
      initialDate = today;
    }

    final selected = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: today,
      initialDate: initialDate,
      helpText: isStartDate
          ? 'Fecha inicial del periodo ${slot.name.toUpperCase()}'
          : 'Fecha final del periodo ${slot.name.toUpperCase()}',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (!context.mounted || selected == null || viewModel.isDisposed) {
      return;
    }

    final currentViewModel = context.read<PeriodComparisonViewModel>();

    if (!identical(currentViewModel, viewModel)) {
      return;
    }

    viewModel.setDate(slot: slot, isStartDate: isStartDate, date: selected);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PeriodComparisonViewModel>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      key: const Key('period-comparison-screen'),
      appBar: AppBar(title: const Text('Comparar periodos')),
      body: SafeArea(
        child: ListView(
          key: const Key('period-comparison-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
          children: [
            Text(
              'Comparación descriptiva',
              key: const Key('period-comparison-title'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona dos intervalos del seguimiento actual '
              'para consultar sus indicadores por separado.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardA = _ComparisonPeriodCard(
                  slot: ComparisonPeriodSlot.a,
                  period: viewModel.periodA,
                  onPickDate: (isStartDate) => _pickDate(
                    context,
                    viewModel,
                    slot: ComparisonPeriodSlot.a,
                    isStartDate: isStartDate,
                  ),
                );

                final cardB = _ComparisonPeriodCard(
                  slot: ComparisonPeriodSlot.b,
                  period: viewModel.periodB,
                  onPickDate: (isStartDate) => _pickDate(
                    context,
                    viewModel,
                    slot: ComparisonPeriodSlot.b,
                    isStartDate: isStartDate,
                  ),
                );

                if (constraints.maxWidth >= 680) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: cardA),
                      const SizedBox(width: 14),
                      Expanded(child: cardB),
                    ],
                  );
                }

                return Column(
                  children: [cardA, const SizedBox(height: 12), cardB],
                );
              },
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('period-comparison-compare-button'),
              onPressed: viewModel.isLoading
                  ? null
                  : () {
                      unawaited(viewModel.load());
                    },
              icon: const Icon(Icons.compare_arrows_rounded),
              label: const Text('Comparar periodos'),
            ),
            const SizedBox(height: 24),
            if (viewModel.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(
                    key: Key('period-comparison-loading'),
                  ),
                ),
              )
            else if (viewModel.errorMessage != null)
              Card(
                key: const Key('period-comparison-error'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline_rounded, color: colors.error),
                      const SizedBox(width: 12),
                      Expanded(child: Text(viewModel.errorMessage!)),
                    ],
                  ),
                ),
              )
            else if (viewModel.result != null)
              _ComparisonResults(result: viewModel.result!)
            else
              Card(
                key: const Key('period-comparison-prompt'),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, color: colors.primary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Selecciona los periodos A y B y pulsa '
                          '«Comparar periodos» para consultar '
                          'sus métricas.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonPeriodCard extends StatelessWidget {
  const _ComparisonPeriodCard({
    required this.slot,
    required this.period,
    required this.onPickDate,
  });

  final ComparisonPeriodSlot slot;
  final ComparisonPeriod period;
  final Future<void> Function(bool isStartDate) onPickDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final name = slot.name.toUpperCase();

    return Card(
      key: Key('period-comparison-period-${slot.name}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Periodo $name',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${DurationSummaryCards.formatDate(period.startDate)} – '
              '${DurationSummaryCards.formatDate(period.endDate)}',
              key: Key('period-comparison-dates-${slot.name}'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: Key('period-comparison-start-${slot.name}'),
                  onPressed: () {
                    unawaited(onPickDate(true));
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 17),
                  label: const Text('Desde'),
                ),
                OutlinedButton.icon(
                  key: Key('period-comparison-end-${slot.name}'),
                  onPressed: () {
                    unawaited(onPickDate(false));
                  },
                  icon: const Icon(Icons.event_outlined, size: 17),
                  label: const Text('Hasta'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonResults extends StatelessWidget {
  const _ComparisonResults({required this.result});

  final PeriodComparisonResult result;

  String _formatPercentage(double? value) {
    if (value == null) {
      return 'Sin datos';
    }

    final rounded = double.parse(value.toStringAsFixed(1));

    if (rounded == rounded.roundToDouble()) {
      return '${rounded.toStringAsFixed(0)} %';
    }

    return '${rounded.toStringAsFixed(1)} %';
  }

  String _formatDuration(
    PeriodComparisonSnapshot snapshot,
    DurationMetricType type,
  ) {
    final average = snapshot.averageMinutesFor(type);

    return average == null
        ? 'Sin datos'
        : DurationSummaryCards.formatDuration(type, average);
  }

  String _validCount(
    PeriodComparisonSnapshot snapshot,
    DurationMetricType type,
  ) {
    final count = snapshot.validDurationsFor(type);

    return '$count ${count == 1 ? 'registro válido' : 'registros válidos'}';
  }

  String _routineCount(PeriodComparisonSnapshot snapshot) {
    final total = snapshot.routineStatusCount;
    final completed = snapshot.completedRoutineCount;

    if (total == 0) {
      return 'Sin estados registrados';
    }

    return '$completed completadas de $total registradas';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      key: const Key('period-comparison-results'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, color: colors.primary, size: 27),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Resultados por periodo',
                key: const Key('period-comparison-results-heading'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        Text(
          'Valores descriptivos calculados de forma '
          'independiente para cada intervalo.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 15),
        Container(
          key: const Key('period-comparison-result-periods'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.primary.withValues(alpha: 0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _ComparisonPeriodLabel(
                  label: 'Periodo A',
                  period: result.periodA.period,
                  dateKey: const Key('period-comparison-result-dates-a'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ComparisonPeriodLabel(
                  label: 'Periodo B',
                  period: result.periodB.period,
                  dateKey: const Key('period-comparison-result-dates-b'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (!result.hasAnyData) ...[
          const Card(
            key: Key('period-comparison-no-data'),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No existen datos suficientes para calcular '
                'las métricas de los periodos seleccionados.',
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        for (final type in DurationMetricType.values) ...[
          _ComparisonMetricCard(
            metricKey: type.name,
            title: 'Duración promedio: ${type.label}',
            valueA: _formatDuration(result.periodA, type),
            valueB: _formatDuration(result.periodB, type),
            detailA: _validCount(result.periodA, type),
            detailB: _validCount(result.periodB, type),
            numericA: result.periodA.averageMinutesFor(type),
            numericB: result.periodB.averageMinutesFor(type),
            unit: 'minutos',
          ),
          const SizedBox(height: 14),
        ],
        _ComparisonMetricCard(
          metricKey: 'routine-compliance',
          title: 'Cumplimiento de rutinas',
          valueA: _formatPercentage(result.periodA.routineCompliancePercentage),
          valueB: _formatPercentage(result.periodB.routineCompliancePercentage),
          detailA: _routineCount(result.periodA),
          detailB: _routineCount(result.periodB),
          numericA: result.periodA.routineCompliancePercentage,
          numericB: result.periodB.routineCompliancePercentage,
          unit: '%',
          isPercentage: true,
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 19,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'La comparación presenta únicamente datos descriptivos. '
                'No establece mejoras, empeoramientos, riesgos '
                'ni interpretaciones clínicas.',
                key: const Key('period-comparison-disclaimer'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ComparisonPeriodLabel extends StatelessWidget {
  const _ComparisonPeriodLabel({
    required this.label,
    required this.period,
    required this.dateKey,
  });

  final String label;
  final ComparisonPeriod period;
  final Key dateKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${DurationSummaryCards.formatDate(period.startDate)} – '
          '${DurationSummaryCards.formatDate(period.endDate)}',
          key: dateKey,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurface,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}

class _ComparisonMetricCard extends StatelessWidget {
  const _ComparisonMetricCard({
    required this.metricKey,
    required this.title,
    required this.valueA,
    required this.valueB,
    required this.detailA,
    required this.detailB,
    required this.numericA,
    required this.numericB,
    required this.unit,
    this.isPercentage = false,
  });

  final String metricKey;
  final String title;
  final String valueA;
  final String valueB;
  final String detailA;
  final String detailB;
  final double? numericA;
  final double? numericB;
  final String unit;
  final bool isPercentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      key: Key('period-comparison-metric-$metricKey'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 12),
            Divider(color: colors.outlineVariant, height: 1),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final first = _ComparisonMetricValue(
                  label: 'Periodo A',
                  value: valueA,
                  detail: detailA,
                  valueKey: Key('period-comparison-value-$metricKey-a'),
                );

                final second = _ComparisonMetricValue(
                  label: 'Periodo B',
                  value: valueB,
                  detail: detailB,
                  valueKey: Key('period-comparison-value-$metricKey-b'),
                );

                // En pantallas muy estrechas se apilan los resultados.
                if (constraints.maxWidth < 260) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [first, const SizedBox(height: 16), second],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: first),
                    const SizedBox(width: 14),
                    Expanded(child: second),
                  ],
                );
              },
            ),
            PeriodComparisonBarChart(
              metricKey: metricKey,
              valueA: numericA,
              valueB: numericB,
              displayA: valueA,
              displayB: valueB,
              unit: unit,
              isPercentage: isPercentage,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonMetricValue extends StatelessWidget {
  const _ComparisonMetricValue({
    required this.label,
    required this.value,
    required this.detail,
    required this.valueKey,
  });

  final String label;
  final String value;
  final String detail;
  final Key valueKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final hasData = value != 'Sin datos';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: colors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          key: valueKey,
          softWrap: true,
          style: theme.textTheme.titleLarge?.copyWith(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: hasData ? colors.primary : colors.onSurface,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: 13,
            color: colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
