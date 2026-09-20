import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/routine_compliance_result.dart';
import '../../domain/repositories/routine_compliance_repository.dart';
import '../viewmodels/routine_compliance_view_model.dart';

class RoutineComplianceView extends StatelessWidget {
  const RoutineComplianceView({
    required this.repository,
    required this.anonymousId,
    super.key,
  });

  final RoutineComplianceRepository repository;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          RoutineComplianceViewModel(repository, anonymousId: anonymousId),
      child: const _RoutineComplianceContent(),
    );
  }
}

class _RoutineComplianceContent extends StatefulWidget {
  const _RoutineComplianceContent();

  @override
  State<_RoutineComplianceContent> createState() =>
      _RoutineComplianceContentState();
}

class _RoutineComplianceContentState extends State<_RoutineComplianceContent> {
  final GlobalKey _resultAnchorKey = GlobalKey();

  Future<void> _calculateAndRevealResult(
    RoutineComplianceViewModel viewModel,
  ) async {
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
    final viewModel = context.watch<RoutineComplianceViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('routine-compliance-screen'),
      appBar: AppBar(
        title: const Text('Cumplimiento de rutinas'),
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
          key: const Key('routine-compliance-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            const _ComplianceIntroCard(),

            const SizedBox(height: 20),

            _ComplianceCriteriaCard(
              viewModel: viewModel,
              onCalculate: () {
                return _calculateAndRevealResult(viewModel);
              },
            ),

            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 18),

              _ComplianceErrorCard(message: viewModel.errorMessage!),
            ],

            if (viewModel.result != null) ...[
              const SizedBox(height: 24),

              KeyedSubtree(
                key: _resultAnchorKey,
                child: viewModel.hasProgrammedRoutines
                    ? _ComplianceResultCard(result: viewModel.result!)
                    : _NoProgrammedRoutinesCard(result: viewModel.result!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ComplianceIntroCard extends StatelessWidget {
  const _ComplianceIntroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('routine-compliance-intro-card'),
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
              Icons.fact_check_outlined,
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
                  'Consulta el cumplimiento registrado',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Selecciona un periodo para ver cuántos '
                  'estados de rutina se registraron y cuántos '
                  'quedaron como completados.',
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

class _ComplianceCriteriaCard extends StatelessWidget {
  const _ComplianceCriteriaCard({
    required this.viewModel,
    required this.onCalculate,
  });

  final RoutineComplianceViewModel viewModel;

  final Future<void> Function() onCalculate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: const Key('routine-compliance-criteria-card'),
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
                  child: Icon(
                    Icons.date_range_outlined,
                    color: colorScheme.primary,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Periodo de consulta',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Selecciona las fechas que deseas revisar.',
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

            Row(
              children: [
                Expanded(
                  child: _ComplianceDateButton(
                    key: const Key('routine-compliance-start-date-button'),
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
                  child: _ComplianceDateButton(
                    key: const Key('routine-compliance-end-date-button'),
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

              _ComplianceFieldError(
                key: const Key('routine-compliance-period-error'),
                message: viewModel.errorFor('period')!,
              ),
            ],

            const SizedBox(height: 26),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('routine-compliance-calculate-button'),
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
                      : 'Calcular cumplimiento',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComplianceDateButton extends StatelessWidget {
  const _ComplianceDateButton({
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

class _ComplianceResultCard extends StatelessWidget {
  const _ComplianceResultCard({required this.result});

  final RoutineComplianceResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final percentage = result.compliancePercentage!;

    final progress = (percentage / 100).clamp(0.0, 1.0);

    return Card(
      key: const Key('routine-compliance-result-card'),
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
                    color: colorScheme.primaryContainer.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.assessment_outlined,
                    color: colorScheme.primary,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cumplimiento descriptivo',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        'Resumen del periodo seleccionado',
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
              _formatPercentage(percentage),
              key: const Key('routine-compliance-percentage-value'),
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
                letterSpacing: -1,
              ),
            ),

            const SizedBox(height: 12),

            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                key: const Key('routine-compliance-progress'),
                value: progress,
                minHeight: 9,
                backgroundColor: colorScheme.surfaceContainerHighest,
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Este porcentaje muestra qué parte de los '
              'registros de rutina del periodo está marcada '
              'como completada.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            Divider(color: colorScheme.outlineVariant),

            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ComplianceMetricTile(
                    key: const Key('routine-compliance-programmed-count'),
                    icon: Icons.event_note_outlined,
                    label: 'Registros de rutina',
                    value: result.programmedCount.toString(),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: _ComplianceMetricTile(
                    key: const Key('routine-compliance-completed-count'),
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Completados',
                    value: result.completedCount.toString(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            _ComplianceDetail(
              icon: Icons.date_range_outlined,
              label: 'Periodo',
              value:
                  '${_formatDate(result.query.startDate)}'
                  ' – '
                  '${_formatDate(result.query.endDate)}',
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                          'En este periodo hay '
                          '${result.programmedCount} '
                          '${_recordWord(result.programmedCount)} '
                          'de rutina y ${result.completedCount} '
                          '${_completedWord(result.completedCount)} '
                          'como completados.',
                          key: const Key(
                            'routine-compliance-descriptive-message',
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Padding(
                    padding: const EdgeInsets.only(left: 28),
                    child: Text(
                      'Cada registro corresponde al estado de '
                      'una rutina en una fecha.',
                      key: const Key('routine-compliance-record-explanation'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
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

class _ComplianceMetricTile extends StatelessWidget {
  const _ComplianceMetricTile({
    required this.icon,
    required this.label,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colorScheme.primary, size: 21),

          const SizedBox(height: 10),

          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoProgrammedRoutinesCard extends StatelessWidget {
  const _NoProgrammedRoutinesCard({required this.result});

  final RoutineComplianceResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: const Key('routine-compliance-no-programmed-card'),
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
                Icons.event_busy_outlined,
                color: colorScheme.onSecondaryContainer,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'No hay registros de rutina en el periodo',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'No se encontraron estados de rutina registrados '
              'entre las fechas seleccionadas.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            _ComplianceDetail(
              icon: Icons.date_range_outlined,
              label: 'Periodo',
              value:
                  '${_formatDate(result.query.startDate)}'
                  ' – '
                  '${_formatDate(result.query.endDate)}',
            ),

            const SizedBox(height: 16),

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
                      'El porcentaje no se calcula porque '
                      'todavía no hay registros de rutina '
                      'en este periodo.',
                      key: const Key(
                        'routine-compliance-no-percentage-message',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
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

class _ComplianceDetail extends StatelessWidget {
  const _ComplianceDetail({
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

class _ComplianceFieldError extends StatelessWidget {
  const _ComplianceFieldError({required this.message, super.key});

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

class _ComplianceErrorCard extends StatelessWidget {
  const _ComplianceErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('routine-compliance-general-error'),
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

String _formatPercentage(double value) {
  final rounded = value.roundToDouble();

  if ((value - rounded).abs() < 0.000001) {
    return '${rounded.toInt()} %';
  }

  return '${value.toStringAsFixed(1)} %';
}

String _recordWord(int count) {
  return count == 1 ? 'registro' : 'registros';
}

String _completedWord(int count) {
  return count == 1 ? 'está marcado' : 'están marcados';
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
