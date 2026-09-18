import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/frequency_category_option.dart';
import '../../domain/models/frequency_metric_type.dart';
import '../../domain/models/frequency_result.dart';
import '../../domain/repositories/frequency_repository.dart';
import '../viewmodels/frequency_view_model.dart';

class FrequencyView extends StatelessWidget {
  const FrequencyView({
    required this.repository,
    required this.anonymousId,
    super.key,
  });

  final FrequencyRepository repository;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FrequencyViewModel(repository, anonymousId: anonymousId),
      child: const _FrequencyContent(),
    );
  }
}

class _FrequencyContent extends StatefulWidget {
  const _FrequencyContent();

  @override
  State<_FrequencyContent> createState() => _FrequencyContentState();
}

class _FrequencyContentState extends State<_FrequencyContent> {
  final GlobalKey _resultAnchorKey = GlobalKey();

  Future<void> _calculateAndRevealResult(FrequencyViewModel viewModel) async {
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
    final viewModel = context.watch<FrequencyViewModel>();

    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('frequency-screen'),
      appBar: AppBar(
        title: const Text('Frecuencias descriptivas'),
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
          key: const Key('frequency-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            const _FrequencyIntroCard(),

            const SizedBox(height: 20),

            _FrequencyCriteriaCard(
              viewModel: viewModel,
              onCalculate: () => _calculateAndRevealResult(viewModel),
            ),

            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 18),

              _FrequencyErrorCard(message: viewModel.errorMessage!),
            ],

            if (viewModel.result != null) ...[
              const SizedBox(height: 24),

              KeyedSubtree(
                key: _resultAnchorKey,
                child: _FrequencyResultCard(
                  result: viewModel.result!,
                  categoryLabel: viewModel.selectedCategoryLabel,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _FrequencyIntroCard extends StatelessWidget {
  const _FrequencyIntroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('frequency-intro-card'),
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
              Icons.bar_chart_rounded,
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
                  'Consulta frecuencias',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Cuenta los registros del perfil activo '
                  'que cumplen un periodo y los criterios '
                  'seleccionados.',
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

class _FrequencyCriteriaCard extends StatelessWidget {
  const _FrequencyCriteriaCard({
    required this.viewModel,
    required this.onCalculate,
  });

  final FrequencyViewModel viewModel;

  final Future<void> Function() onCalculate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Card(
      key: const Key('frequency-criteria-card'),
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
                        'Selecciona qué deseas contar.',
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
              'Tipo de frecuencia',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 5),

            Text(
              'Selecciona el tipo de registro que deseas contar.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final metric in FrequencyMetricType.values)
                  ChoiceChip(
                    key: Key('frequency-metric-${metric.code}'),
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

              _FieldError(
                key: const Key('frequency-metric-error'),
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
                  child: _FrequencyDateButton(
                    key: const Key('frequency-start-date-button'),
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
                  child: _FrequencyDateButton(
                    key: const Key('frequency-end-date-button'),
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

              _FieldError(
                key: const Key('frequency-period-error'),
                message: viewModel.errorFor('period')!,
              ),
            ],

            if (viewModel.metricSupportsCategories) ...[
              const SizedBox(height: 24),

              Text(
                'Categoría',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                viewModel.metricRequiresCategory
                    ? 'Selecciona una categoría para realizar el conteo.'
                    : 'Puedes dejar la categoría sin seleccionar para '
                          'contar todas, o elegir una categoría específica.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 12),

              _FrequencyCategorySelector(viewModel: viewModel),

              if (viewModel.errorFor('category') != null) ...[
                const SizedBox(height: 10),

                _FieldError(
                  key: const Key('frequency-category-error'),
                  message: viewModel.errorFor('category')!,
                ),
              ],
            ],

            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('frequency-calculate-button'),
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
                      : 'Calcular frecuencia',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FrequencyCategorySelector extends StatelessWidget {
  const _FrequencyCategorySelector({required this.viewModel});

  final FrequencyViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      key: const Key('frequency-category-selector'),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final option in viewModel.availableCategories)
          _CategoryChip(
            option: option,
            selected: viewModel.selectedCategoryCode == option.code,
            onSelected: (selected) {
              if (selected) {
                viewModel.setCategoryCode(option.code);

                return;
              }

              if (!viewModel.metricRequiresCategory) {
                viewModel.clearCategory();
              }
            },
          ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.option,
    required this.selected,
    required this.onSelected,
  });

  final FrequencyCategoryOption option;

  final bool selected;

  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      key: Key('frequency-category-${option.code}'),
      showCheckmark: false,
      label: Text(option.label),
      selected: selected,
      onSelected: onSelected,
    );
  }
}

class _FrequencyDateButton extends StatelessWidget {
  const _FrequencyDateButton({
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

class _FrequencyResultCard extends StatelessWidget {
  const _FrequencyResultCard({
    required this.result,
    required this.categoryLabel,
  });

  final FrequencyResult result;

  final String? categoryLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final count = result.count;

    final metric = result.query.metricType;

    final countLabel = count == 1 ? '1 registro' : '$count registros';

    return Card(
      key: const Key('frequency-result-card'),
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
                        'Frecuencia descriptiva',
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
              countLabel,
              key: const Key('frequency-result-count'),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                letterSpacing: -1,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Conteo descriptivo de los registros que '
              'cumplen los criterios seleccionados.',
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

            if (metric.supportsCategories) ...[
              const SizedBox(height: 10),

              _ResultDetail(
                icon: Icons.category_outlined,
                label: 'Categoría',
                value: categoryLabel ?? 'Todas las categorías',
              ),
            ],
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

class _FieldError extends StatelessWidget {
  const _FieldError({required this.message, super.key});

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

class _FrequencyErrorCard extends StatelessWidget {
  const _FrequencyErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('frequency-general-error'),
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

IconData _iconForMetric(FrequencyMetricType metric) {
  switch (metric) {
    case FrequencyMetricType.behavior:
      return Icons.psychology_alt_outlined;

    case FrequencyMetricType.dysregulation:
      return Icons.sentiment_dissatisfied_outlined;

    case FrequencyMetricType.socialInteraction:
      return Icons.groups_outlined;

    case FrequencyMetricType.feeding:
      return Icons.restaurant_outlined;

    case FrequencyMetricType.atypicalSituation:
      return Icons.event_note_outlined;
  }
}

Color _accentColorForMetric(FrequencyMetricType metric) {
  switch (metric) {
    case FrequencyMetricType.behavior:
      return const Color(0xFFE56F61);

    case FrequencyMetricType.dysregulation:
      return const Color(0xFF8173AE);

    case FrequencyMetricType.socialInteraction:
      return const Color(0xFF69AA98);

    case FrequencyMetricType.feeding:
      return const Color(0xFFC9A353);

    case FrequencyMetricType.atypicalSituation:
      return const Color(0xFF9B8564);
  }
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
