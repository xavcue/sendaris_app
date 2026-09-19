import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/duration_metric_type.dart';
import '../../domain/models/duration_observation.dart';
import '../../domain/models/duration_result.dart';
import '../../domain/repositories/duration_repository.dart';
import '../viewmodels/duration_view_model.dart';

class DurationView extends StatelessWidget {
  const DurationView({
    required this.repository,
    required this.anonymousId,
    super.key,
  });

  final DurationRepository repository;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DurationViewModel(repository, anonymousId: anonymousId),
      child: const _DurationContent(),
    );
  }
}

class _DurationContent extends StatefulWidget {
  const _DurationContent();

  @override
  State<_DurationContent> createState() => _DurationContentState();
}

class _DurationContentState extends State<_DurationContent> {
  final GlobalKey _resultAnchorKey = GlobalKey();

  Future<void> _calculateAndRevealResult(DurationViewModel viewModel) async {
    final success = await viewModel.calculate();

    if (!success || !mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final resultContext = _resultAnchorKey.currentContext;

      if (resultContext == null) {
        return;
      }

      await Scrollable.ensureVisible(
        resultContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DurationViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('duration-screen'),
      appBar: AppBar(
        title: const Text('Duraciones y promedios'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          key: const Key('duration-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            const _DurationIntroCard(),
            const SizedBox(height: 20),
            _DurationCriteriaCard(
              viewModel: viewModel,
              onCalculate: () {
                return _calculateAndRevealResult(viewModel);
              },
            ),
            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 18),
              _DurationErrorCard(message: viewModel.errorMessage!),
            ],
            if (viewModel.result != null) ...[
              const SizedBox(height: 24),
              KeyedSubtree(
                key: _resultAnchorKey,
                child: viewModel.hasSufficientData
                    ? _DurationResultCard(result: viewModel.result!)
                    : _InsufficientDurationDataCard(result: viewModel.result!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DurationIntroCard extends StatelessWidget {
  const _DurationIntroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('duration-intro-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.timer_outlined,
              color: colorScheme.onPrimary,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consulta datos temporales',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Consulta duraciones válidas y el promedio '
                  'descriptivo registrado dentro de un periodo.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationCriteriaCard extends StatelessWidget {
  const _DurationCriteriaCard({
    required this.viewModel,
    required this.onCalculate,
  });

  final DurationViewModel viewModel;

  final Future<void> Function() onCalculate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: const Key('duration-criteria-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.tune_rounded, color: colorScheme.primary),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Criterios de consulta',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Selecciona qué duración deseas consultar.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Tipo de duración',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Solo se muestran módulos con una variable temporal aplicable.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final metric in DurationMetricType.values)
                  ChoiceChip(
                    key: Key('duration-metric-${metric.code}'),
                    showCheckmark: false,
                    avatar: Icon(_iconForMetric(metric), size: 18),
                    label: Text(metric.label),
                    selected: viewModel.selectedMetricType == metric,
                    onSelected: (_) {
                      viewModel.setMetricType(metric);
                    },
                  ),
              ],
            ),
            if (viewModel.errorFor('metricType') != null) ...[
              const SizedBox(height: 10),
              _DurationFieldError(
                key: const Key('duration-metric-error'),
                message: viewModel.errorFor('metricType')!,
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'Periodo',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DurationDateButton(
                    key: const Key('duration-start-date-button'),
                    label: 'Desde',
                    value: viewModel.startDate,
                    onTap: () async {
                      final selected = await _selectDate(
                        context: context,
                        title: 'Fecha inicial',
                        initialDate: viewModel.startDate ?? DateTime.now(),
                      );

                      if (selected != null) {
                        viewModel.setStartDate(selected);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DurationDateButton(
                    key: const Key('duration-end-date-button'),
                    label: 'Hasta',
                    value: viewModel.endDate,
                    onTap: () async {
                      final selected = await _selectDate(
                        context: context,
                        title: 'Fecha final',
                        initialDate: viewModel.endDate ?? DateTime.now(),
                      );

                      if (selected != null) {
                        viewModel.setEndDate(selected);
                      }
                    },
                  ),
                ),
              ],
            ),
            if (viewModel.errorFor('period') != null) ...[
              const SizedBox(height: 10),
              _DurationFieldError(
                key: const Key('duration-period-error'),
                message: viewModel.errorFor('period')!,
              ),
            ],
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('duration-calculate-button'),
                onPressed: viewModel.isCalculating
                    ? null
                    : () async {
                        await onCalculate();
                      },
                icon: viewModel.isCalculating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.calculate_outlined),
                label: Text(
                  viewModel.isCalculating
                      ? 'Calculando...'
                      : 'Calcular promedio',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationDateButton extends StatelessWidget {
  const _DurationDateButton({
    required this.label,
    required this.value,
    required this.onTap,
    super.key,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        alignment: Alignment.centerLeft,
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value == null ? 'Sin seleccionar' : _formatDate(value!),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationResultCard extends StatelessWidget {
  const _DurationResultCard({required this.result});

  final DurationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final metric = result.query.metricType;
    final average = result.averageMinutes!;

    return Card(
      key: const Key('duration-result-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _accentColorForMetric(metric).withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.20 : 0.13,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    _iconForMetric(metric),
                    color: _accentColorForMetric(metric),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Promedio descriptivo',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        metric.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              _formatDuration(metric, average),
              key: const Key('duration-average-value'),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Promedio calculado únicamente con las '
              'duraciones válidas del periodo seleccionado.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 12),
            _ResultDetail(
              icon: Icons.date_range_outlined,
              label: 'Periodo',
              value:
                  '${_formatDate(result.query.startDate)}'
                  ' – '
                  '${_formatDate(result.query.endDate)}',
            ),
            const SizedBox(height: 10),
            _ResultDetail(
              icon: Icons.fact_check_outlined,
              label: 'Registros válidos',
              value: result.validRecordCount.toString(),
            ),
            const SizedBox(height: 24),
            Text(
              'Duraciones individuales',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Valores temporales válidos utilizados para calcular el promedio.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            ListView.separated(
              key: const Key('duration-observation-list'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: result.observations.length,
              separatorBuilder: (context, index) {
                return const SizedBox(height: 8);
              },
              itemBuilder: (context, index) {
                final observation = result.observations[index];

                return _DurationObservationTile(observation: observation);
              },
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 19,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Estos valores son descriptivos y no '
                      'representan una evaluación clínica.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DurationObservationTile extends StatelessWidget {
  const _DurationObservationTile({required this.observation});

  final DurationObservation observation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: Key('duration-observation-${observation.recordId}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.timer_outlined,
              size: 20,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(observation.date),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Duración registrada',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatDuration(
              observation.metricType,
              observation.durationMinutes!.toDouble(),
            ),
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsufficientDurationDataCard extends StatelessWidget {
  const _InsufficientDurationDataCard({required this.result});

  final DurationResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: const Key('duration-insufficient-data-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.hourglass_empty_rounded,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay datos temporales suficientes',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No existen duraciones válidas suficientes '
              'para calcular un promedio en el periodo seleccionado.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            _ResultDetail(
              icon: Icons.date_range_outlined,
              label: 'Periodo',
              value:
                  '${_formatDate(result.query.startDate)}'
                  ' – '
                  '${_formatDate(result.query.endDate)}',
            ),
            const SizedBox(height: 10),
            _ResultDetail(
              icon: Icons.analytics_outlined,
              label: 'Tipo',
              value: result.query.metricType.label,
            ),
            const SizedBox(height: 16),
            Text(
              'No se muestra un promedio numérico porque '
              'hacerlo podría representar incorrectamente '
              'los registros disponibles.',
              key: const Key('duration-no-invented-average-message'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultDetail extends StatelessWidget {
  const _ResultDetail({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 9),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DurationFieldError extends StatelessWidget {
  const _DurationFieldError({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 19,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DurationErrorCard extends StatelessWidget {
  const _DurationErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('duration-general-error'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<DateTime?> _selectDate({
  required BuildContext context,
  required String title,
  required DateTime initialDate,
}) {
  final firstDate = DateTime(2000, 1, 1);

  final lastDate = DateTime(DateTime.now().year + 1, 12, 31);

  var normalizedInitial = DateTime(
    initialDate.year,
    initialDate.month,
    initialDate.day,
  );

  if (normalizedInitial.isBefore(firstDate)) {
    normalizedInitial = firstDate;
  }

  if (normalizedInitial.isAfter(lastDate)) {
    normalizedInitial = lastDate;
  }

  return showDatePicker(
    context: context,
    initialDate: normalizedInitial,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: title,
    cancelText: 'Cancelar',
    confirmText: 'Aceptar',
  );
}

IconData _iconForMetric(DurationMetricType metric) {
  switch (metric) {
    case DurationMetricType.sleep:
      return Icons.bedtime_outlined;

    case DurationMetricType.behavior:
      return Icons.psychology_alt_outlined;

    case DurationMetricType.dysregulation:
      return Icons.sentiment_dissatisfied_outlined;
  }
}

Color _accentColorForMetric(DurationMetricType metric) {
  switch (metric) {
    case DurationMetricType.sleep:
      return const Color(0xFF6679B8);

    case DurationMetricType.behavior:
      return const Color(0xFFE56F61);

    case DurationMetricType.dysregulation:
      return const Color(0xFF8173AE);
  }
}

String _formatDuration(DurationMetricType metric, double minutes) {
  if (metric == DurationMetricType.sleep) {
    return _formatSleepDuration(minutes);
  }

  return _formatMinutes(minutes);
}

String _formatSleepDuration(double minutes) {
  final normalizedMinutes = double.parse(minutes.toStringAsFixed(1));

  final hours = normalizedMinutes ~/ 60;

  final remainingMinutes = normalizedMinutes - (hours * 60);

  if (hours == 0) {
    return _formatMinutes(remainingMinutes);
  }

  if (remainingMinutes.abs() < 0.000001) {
    return '$hours h';
  }

  final roundedRemaining = remainingMinutes.roundToDouble();

  if ((remainingMinutes - roundedRemaining).abs() < 0.000001) {
    return '$hours h ${roundedRemaining.toInt()} min';
  }

  return '$hours h '
      '${remainingMinutes.toStringAsFixed(1)} min';
}

String _formatMinutes(double minutes) {
  final rounded = minutes.roundToDouble();

  if ((minutes - rounded).abs() < 0.000001) {
    return '${rounded.toInt()} min';
  }

  return '${minutes.toStringAsFixed(1)} min';
}

String _formatDate(DateTime value) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  return '${value.day.toString().padLeft(2, '0')} '
      '${months[value.month - 1]} '
      '${value.year}';
}
