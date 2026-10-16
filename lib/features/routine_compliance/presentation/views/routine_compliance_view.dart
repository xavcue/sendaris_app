import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../routine_status/domain/models/routine_status.dart';
import '../../domain/repositories/routine_compliance_repository.dart';
import '../../domain/services/routine_overview_service.dart';
import '../viewmodels/routine_overview_view_model.dart';

class RoutineComplianceView extends StatefulWidget {
  const RoutineComplianceView({
    required this.repository,
    required this.anonymousId,
    super.key,
  });

  final RoutineComplianceRepository repository;
  final String anonymousId;

  @override
  State<RoutineComplianceView> createState() => _RoutineComplianceViewState();
}

class _RoutineComplianceViewState extends State<RoutineComplianceView> {
  late RoutineOverviewViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = _createViewModel();
    unawaited(_viewModel.load());
  }

  RoutineOverviewViewModel _createViewModel() {
    return RoutineOverviewViewModel(
      widget.repository,
      anonymousId: widget.anonymousId,
    );
  }

  @override
  void didUpdateWidget(covariant RoutineComplianceView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.anonymousId != widget.anonymousId ||
        oldWidget.repository != widget.repository) {
      final previousViewModel = _viewModel;

      _viewModel = _createViewModel();

      previousViewModel.dispose();

      unawaited(_viewModel.load());
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RoutineOverviewViewModel>.value(
      value: _viewModel,
      child: const _RoutineComplianceContent(),
    );
  }
}

class _RoutineComplianceContent extends StatelessWidget {
  const _RoutineComplianceContent();

  Future<void> _pickDate(
    BuildContext context,
    RoutineOverviewViewModel viewModel, {
    required bool isStartDate,
  }) async {
    final now = DateTime.now();

    final firstDate = DateTime(2000);
    final lastDate = DateTime(now.year + 1, 12, 31);

    var initialDate = isStartDate ? viewModel.startDate : viewModel.endDate;

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }

    if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final selectedDate = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
      helpText: isStartDate ? 'Fecha inicial' : 'Fecha final',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (!context.mounted || selectedDate == null || viewModel.isDisposed) {
      return;
    }

    final activeViewModel = context.read<RoutineOverviewViewModel>();

    if (!identical(activeViewModel, viewModel)) {
      return;
    }

    await viewModel.setDate(isStartDate: isStartDate, date: selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RoutineOverviewViewModel>();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      key: const Key('routine-compliance-screen'),
      appBar: AppBar(title: const Text('Resumen de rutinas')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: viewModel.load,
          child: ListView(
            key: const Key('routine-compliance-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              Text(
                'Resumen de rutinas',
                key: const Key('routine-overview-title'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Consulta el cumplimiento y los estados '
                'registrados de las rutinas del seguimiento actual.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              _RoutinePeriodCard(
                viewModel: viewModel,
                onSelectDate: (isStartDate) {
                  return _pickDate(
                    context,
                    viewModel,
                    isStartDate: isStartDate,
                  );
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      viewModel.isLoading
                          ? 'Actualizando rutinas…'
                          : 'Cumplimiento descriptivo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('routine-overview-refresh'),
                    tooltip: 'Actualizar resumen',
                    onPressed: viewModel.isLoading
                        ? null
                        : () {
                            unawaited(viewModel.load());
                          },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (viewModel.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: CircularProgressIndicator(
                      key: Key('routine-overview-loading'),
                    ),
                  ),
                )
              else if (viewModel.errorMessage != null)
                Card(
                  key: const Key('routine-compliance-general-error'),
                  margin: EdgeInsets.zero,
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
              else if (viewModel.overview != null)
                _RoutineOverviewResults(overview: viewModel.overview!),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutinePeriodCard extends StatelessWidget {
  const _RoutinePeriodCard({
    required this.viewModel,
    required this.onSelectDate,
  });

  final RoutineOverviewViewModel viewModel;
  final Future<void> Function(bool isStartDate) onSelectDate;

  Widget _periodChip({
    required String label,
    required Key key,
    required RoutineOverviewPeriod period,
  }) {
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: viewModel.selectedPeriod == period,
      onSelected: (_) {
        unawaited(viewModel.selectPeriod(period));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      key: const Key('routine-overview-period-filters'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Periodo de consulta',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Selecciona el intervalo para consultar '
              'los estados registrados.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _periodChip(
                  key: const Key('routine-overview-seven-days'),
                  label: 'Últimos 7 días',
                  period: RoutineOverviewPeriod.sevenDays,
                ),
                _periodChip(
                  key: const Key('routine-overview-this-month'),
                  label: 'Este mes',
                  period: RoutineOverviewPeriod.thisMonth,
                ),
                _periodChip(
                  key: const Key('routine-overview-thirty-days'),
                  label: 'Últimos 30 días',
                  period: RoutineOverviewPeriod.thirtyDays,
                ),
                _periodChip(
                  key: const Key('routine-overview-custom'),
                  label: 'Personalizado',
                  period: RoutineOverviewPeriod.custom,
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              '${_formatDate(viewModel.startDate)} – '
              '${_formatDate(viewModel.endDate)}',
              key: const Key('routine-overview-selected-period'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (viewModel.selectedPeriod == RoutineOverviewPeriod.custom) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('routine-compliance-start-date-button'),
                      onPressed: () {
                        unawaited(onSelectDate(true));
                      },
                      icon: const Icon(Icons.calendar_today_outlined, size: 18),
                      label: Text(
                        'Desde: ${_formatDate(viewModel.startDate)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('routine-compliance-end-date-button'),
                      onPressed: () {
                        unawaited(onSelectDate(false));
                      },
                      icon: const Icon(Icons.event_outlined, size: 18),
                      label: Text(
                        'Hasta: ${_formatDate(viewModel.endDate)}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
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

class _RoutineOverviewResults extends StatelessWidget {
  const _RoutineOverviewResults({required this.overview});

  final RoutineOverview overview;

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
          '${_formatDate(overview.startDate)} – '
          '${_formatDate(overview.endDate)}',
          key: const Key('routine-overview-result-period'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        _RoutinePercentageCard(overview: overview),
        const SizedBox(height: 20),
        Text(
          'Distribución de estados',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Cantidad de estados registrados '
          'durante el periodo seleccionado.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          key: const Key('routine-overview-status-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 104,
          ),
          itemCount: RoutineStatus.values.length,
          itemBuilder: (context, index) {
            final status = RoutineStatus.values[index];

            return _RoutineStatusCountCard(
              status: status,
              count: overview.countForStatus(status),
            );
          },
        ),
        const SizedBox(height: 22),
        Text(
          'Resumen por rutina',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Consulta los estados y el porcentaje '
          'descriptivo de cada rutina.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (overview.routines.isEmpty)
          Card(
            key: const Key('routine-overview-no-routines'),
            margin: EdgeInsets.zero,
            child: const Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'No existen estados de rutina '
                'registrados en este periodo.',
              ),
            ),
          )
        else
          for (var i = 0; i < overview.routines.length; i++) ...[
            _RoutineBreakdownCard(
              key: Key('routine-overview-item-$i'),
              item: overview.routines[i],
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 12),
        Row(
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
                'Los resultados son descriptivos y '
                'no representan una evaluación clínica.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RoutinePercentageCard extends StatelessWidget {
  const _RoutinePercentageCard({required this.overview});

  final RoutineOverview overview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final percentage = overview.compliancePercentage;
    final hasRecords = overview.hasRecords;

    return Card(
      key: const Key('routine-overview-percentage-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(Icons.fact_check_outlined, color: colors.primary),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Cumplimiento registrado',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        percentage == null
                            ? 'Sin datos'
                            : _formatPercentage(percentage),
                        key: const Key('routine-overview-percentage-value'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: hasRecords
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (percentage != null)
              LinearProgressIndicator(
                key: const Key('routine-overview-progress'),
                value: (percentage / 100).clamp(0.0, 1.0),
                minHeight: 9,
                borderRadius: BorderRadius.circular(9),
              ),
            if (percentage == null)
              Text(
                'El porcentaje no se calcula porque '
                'no existen estados registrados.',
                key: const Key('routine-compliance-no-percentage-message'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              '${overview.completedCount} completadas de '
              '${overview.totalRecords} estados registrados',
              key: const Key('routine-overview-count-summary'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Solo el estado «Completada» cuenta como '
              'cumplido. Los otros tres estados se incluyen '
              'en el total registrado.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineStatusCountCard extends StatelessWidget {
  const _RoutineStatusCountCard({required this.status, required this.count});

  final RoutineStatus status;
  final int count;

  IconData get _icon {
    return switch (status) {
      RoutineStatus.completed => Icons.check_circle_outline_rounded,
      RoutineStatus.modified => Icons.edit_calendar_outlined,
      RoutineStatus.interrupted => Icons.pause_circle_outline_rounded,
      RoutineStatus.notCompleted => Icons.event_busy_outlined,
    };
  }

  Color get _accentColor {
    return switch (status) {
      RoutineStatus.completed => const Color(0xFF5CB9AA),
      RoutineStatus.modified => const Color(0xFF78AFC1),
      RoutineStatus.interrupted => const Color(0xFFC9A353),
      RoutineStatus.notCompleted => const Color(0xFFE56F61),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final iconColor = isDark
        ? Color.lerp(_accentColor, Colors.white, 0.20)!
        : _accentColor;

    return Card(
      key: Key('routine-overview-status-${status.name}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: isDark ? 0.16 : 0.12),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(_icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 10),
                Text(
                  '$count',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              status.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineBreakdownCard extends StatelessWidget {
  const _RoutineBreakdownCard({required this.item, super.key});

  final RoutineOverviewItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        key: const Key('routine-overview-routine-expansion'),
        leading: Icon(Icons.checklist_rounded, color: colors.primary),
        title: Text(
          item.routineName,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          '${item.totalRecords} '
          '${item.totalRecords == 1 ? 'estado registrado' : 'estados registrados'}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Cumplimiento descriptivo',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                item.compliancePercentage == null
                    ? 'Sin datos'
                    : _formatPercentage(item.compliancePercentage!),
                key: const Key('routine-overview-routine-percentage'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final status in RoutineStatus.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      status.label,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${item.countForStatus(status)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
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

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');

  return '$day/$month/${date.year}';
}

String _formatPercentage(double value) {
  final rounded = value.roundToDouble();

  if ((value - rounded).abs() < 0.000001) {
    return '${rounded.toInt()} %';
  }

  return '${value.toStringAsFixed(1)} %';
}
