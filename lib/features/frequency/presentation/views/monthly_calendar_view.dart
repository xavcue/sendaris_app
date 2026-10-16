import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../data/repositories/composite_monthly_calendar_repository.dart';
import '../../domain/models/monthly_calendar_record.dart';
import '../viewmodels/monthly_calendar_view_model.dart';

class MonthlyCalendarView extends StatefulWidget {
  const MonthlyCalendarView({
    required this.repository,
    required this.anonymousId,
    super.key,
  });

  final MonthlyCalendarRepository repository;
  final String anonymousId;

  @override
  State<MonthlyCalendarView> createState() => _MonthlyCalendarViewState();
}

class _MonthlyCalendarViewState extends State<MonthlyCalendarView> {
  late MonthlyCalendarViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = _createViewModel();
    unawaited(_viewModel.load());
  }

  MonthlyCalendarViewModel _createViewModel() {
    return MonthlyCalendarViewModel(
      widget.repository,
      anonymousId: widget.anonymousId,
    );
  }

  @override
  void didUpdateWidget(covariant MonthlyCalendarView oldWidget) {
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
    return ChangeNotifierProvider<MonthlyCalendarViewModel>.value(
      value: _viewModel,
      child: const _MonthlyCalendarContent(),
    );
  }
}

class _MonthlyCalendarContent extends StatelessWidget {
  const _MonthlyCalendarContent();

  static const _months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static const _weekdays = <String>['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  String _monthLabel(DateTime date) {
    return '${_months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> _pickDate(
    BuildContext context,
    MonthlyCalendarViewModel viewModel, {
    required bool isStartDate,
  }) async {
    final firstDate = isStartDate
        ? DateTime(2000)
        : (viewModel.startDate ?? DateTime(2000));

    final lastDate = isStartDate
        ? (viewModel.endDate ?? DateTime(2100))
        : DateTime(2100);

    var initialDate = isStartDate
        ? (viewModel.startDate ?? viewModel.selectedDate)
        : (viewModel.endDate ?? viewModel.selectedDate);

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }

    if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isStartDate
          ? 'Seleccionar fecha inicial'
          : 'Seleccionar fecha final',
    );

    if (!context.mounted || selected == null || viewModel.isDisposed) {
      return;
    }

    final activeViewModel = context.read<MonthlyCalendarViewModel>();

    if (!identical(activeViewModel, viewModel)) {
      return;
    }

    if (isStartDate) {
      viewModel.selectStartDate(selected);
    } else {
      viewModel.selectEndDate(selected);
    }
  }

  String _detailRoute(CalendarRecordType type) {
    return switch (type) {
      CalendarRecordType.behavior => AppRoutes.behaviorDetail,
      CalendarRecordType.sleep => AppRoutes.sleepDetail,
      CalendarRecordType.feeding => AppRoutes.feedingDetail,
      CalendarRecordType.socialInteraction => AppRoutes.socialInteractionDetail,
      CalendarRecordType.dysregulation => AppRoutes.dysregulationDetail,
      CalendarRecordType.atypicalSituation => AppRoutes.atypicalSituationDetail,
      CalendarRecordType.routineStatus => AppRoutes.routineStatusDetail,
    };
  }

  IconData _recordIcon(CalendarRecordType type) {
    return switch (type) {
      CalendarRecordType.behavior => Icons.psychology_outlined,
      CalendarRecordType.sleep => Icons.bedtime_outlined,
      CalendarRecordType.feeding => Icons.restaurant_outlined,
      CalendarRecordType.socialInteraction => Icons.people_outline_rounded,
      CalendarRecordType.dysregulation => Icons.self_improvement_rounded,
      CalendarRecordType.atypicalSituation => Icons.event_note_outlined,
      CalendarRecordType.routineStatus => Icons.event_available_outlined,
    };
  }

  Future<void> _openRecord(
    BuildContext context,
    MonthlyCalendarViewModel viewModel,
    MonthlyCalendarRecord record,
  ) async {
    final sourceRecord = record.sourceRecord;

    if (sourceRecord == null || viewModel.isDisposed) {
      return;
    }

    final expectedId = viewModel.anonymousId.trim();

    if (record.anonymousId != expectedId) {
      return;
    }

    await context.push<void>(_detailRoute(record.type), extra: sourceRecord);

    if (!context.mounted || viewModel.isDisposed) {
      return;
    }

    final activeViewModel = context.read<MonthlyCalendarViewModel>();

    if (!identical(activeViewModel, viewModel) ||
        activeViewModel.anonymousId.trim() != expectedId) {
      return;
    }

    await viewModel.load();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MonthlyCalendarViewModel>();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final records = viewModel.selectedDayRecords;
    final monthCount = viewModel.monthCount;

    return Scaffold(
      key: const Key('monthly-calendar-screen'),
      appBar: AppBar(title: const Text('Calendario de registros')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: viewModel.load,
          child: ListView(
            key: const Key('monthly-calendar-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(
                'Consulta los registros por fecha',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Selecciona una fecha para consultar los '
                'registros del seguimiento actual.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            key: const Key('monthly-calendar-previous'),
                            tooltip: 'Mes anterior',
                            onPressed: () {
                              viewModel.changeMonth(-1);
                            },
                            icon: const Icon(Icons.chevron_left_rounded),
                          ),
                          Expanded(
                            child: Text(
                              _monthLabel(viewModel.visibleMonth),
                              key: const Key('monthly-calendar-month'),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            key: const Key('monthly-calendar-next'),
                            tooltip: 'Mes siguiente',
                            onPressed: () {
                              viewModel.changeMonth(1);
                            },
                            icon: const Icon(Icons.chevron_right_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          for (final day in _weekdays)
                            Expanded(
                              child: Text(
                                day,
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      _buildCalendarGrid(context, viewModel),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      viewModel.isLoading
                          ? 'Actualizando registros…'
                          : viewModel.errorMessage != null
                          ? 'Registros no disponibles'
                          : '$monthCount '
                                '${monthCount == 1 ? 'registro' : 'registros'} '
                                'en ${_monthLabel(viewModel.visibleMonth)}',
                      key: const Key('monthly-calendar-month-total'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('monthly-calendar-refresh'),
                    tooltip: 'Actualizar registros',
                    onPressed: viewModel.isLoading
                        ? null
                        : () {
                            unawaited(viewModel.load());
                          },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              OutlinedButton.icon(
                key: const Key('monthly-calendar-filter-toggle'),
                onPressed: viewModel.toggleFilters,
                icon: const Icon(Icons.filter_list_rounded),
                label: Text(
                  viewModel.filtersExpanded
                      ? 'Ocultar filtros'
                      : 'Filtrar registros',
                ),
              ),
              if (viewModel.hasDateFilter) ...[
                const SizedBox(height: 8),
                Text(
                  'Intervalo: '
                  '${viewModel.startDate == null ? 'Sin inicio' : _formatDate(viewModel.startDate!)}'
                  ' — '
                  '${viewModel.endDate == null ? 'Sin fin' : _formatDate(viewModel.endDate!)}',
                  key: const Key('monthly-calendar-range-summary'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
              if (viewModel.filtersExpanded) ...[
                const SizedBox(height: 14),
                Text(
                  'Periodo',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('monthly-calendar-start-date-button'),
                        onPressed: () {
                          unawaited(
                            _pickDate(context, viewModel, isStartDate: true),
                          );
                        },
                        icon: const Icon(
                          Icons.calendar_today_outlined,
                          size: 18,
                        ),
                        label: Text(
                          viewModel.startDate == null
                              ? 'Desde'
                              : _formatDate(viewModel.startDate!),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('monthly-calendar-end-date-button'),
                        onPressed: () {
                          unawaited(
                            _pickDate(context, viewModel, isStartDate: false),
                          );
                        },
                        icon: const Icon(Icons.event_outlined, size: 18),
                        label: Text(
                          viewModel.endDate == null
                              ? 'Hasta'
                              : _formatDate(viewModel.endDate!),
                        ),
                      ),
                    ),
                  ],
                ),
                if (viewModel.hasDateFilter)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const Key('monthly-calendar-clear-dates'),
                      onPressed: viewModel.clearDateFilters,
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Limpiar fechas'),
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tipos de registro',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('monthly-calendar-select-all-types'),
                      onPressed: viewModel.selectAllTypes,
                      child: const Text('Todos'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    for (final type in CalendarRecordType.values)
                      FilterChip(
                        key: Key('monthly-calendar-type-${type.name}'),
                        label: Text(type.label),
                        selected: viewModel.selectedTypes.contains(type),
                        onSelected: (selected) {
                          viewModel.setTypeSelected(type, selected: selected);
                        },
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'Registros del '
                '${viewModel.selectedDate.day} de '
                '${_months[viewModel.selectedDate.month - 1]}',
                key: const Key('monthly-calendar-selected-day'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (viewModel.isLoading)
                const Center(child: CircularProgressIndicator())
              else if (viewModel.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    viewModel.errorMessage!,
                    key: const Key('monthly-calendar-error'),
                  ),
                )
              else if (records.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    viewModel.hasDateFilter
                        ? 'Sin registros para esta fecha '
                              'dentro del periodo seleccionado.'
                        : 'Sin registros en esta fecha.',
                    key: const Key('monthly-calendar-empty'),
                  ),
                )
              else
                ...records.map(
                  (record) => Card(
                    key: Key(
                      'monthly-calendar-record-'
                      '${record.type.name}-${record.id}',
                    ),
                    margin: const EdgeInsets.only(bottom: 7),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      leading: Icon(
                        _recordIcon(record.type),
                        color: colors.primary,
                      ),
                      title: Text(record.type.label),
                      subtitle: Text(record.description),
                      trailing: record.sourceRecord == null
                          ? null
                          : const Icon(Icons.chevron_right_rounded),
                      onTap: record.sourceRecord == null
                          ? null
                          : () {
                              unawaited(
                                _openRecord(context, viewModel, record),
                              );
                            },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarGrid(
    BuildContext context,
    MonthlyCalendarViewModel viewModel,
  ) {
    final colors = Theme.of(context).colorScheme;

    final month = viewModel.visibleMonth;

    final first = DateTime(month.year, month.month);

    final leading = first.weekday - 1;

    final days = DateTime(month.year, month.month + 1, 0).day;

    final total = ((leading + days + 6) ~/ 7) * 7;

    final now = DateTime.now();

    return GridView.builder(
      key: const Key('monthly-calendar-grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        childAspectRatio: 0.72,
      ),
      itemCount: total,
      itemBuilder: (context, cell) {
        final day = cell - leading + 1;

        if (day < 1 || day > days) {
          return const SizedBox.shrink();
        }

        final date = DateTime(month.year, month.month, day);

        final count = viewModel.countForDay(date);

        final selected = date == viewModel.selectedDate;

        final isToday =
            date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;

        return Semantics(
          button: true,
          label:
              '$day de ${_months[date.month - 1]}, '
              '$count registros',
          child: InkWell(
            key: Key('monthly-calendar-day-$day'),
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              viewModel.selectDate(date);
            },
            child: Container(
              decoration: BoxDecoration(
                color: selected ? colors.primaryContainer : null,
                border: isToday ? Border.all(color: colors.primary) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  if (count > 0)
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: colors.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
