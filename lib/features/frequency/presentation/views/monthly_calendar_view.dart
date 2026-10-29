import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../data/repositories/composite_monthly_calendar_repository.dart';
import '../../domain/models/monthly_calendar_record.dart';
import '../viewmodels/monthly_calendar_view_model.dart';
import '../widgets/month_year_picker.dart';
import '../widgets/monthly_coverage_summary.dart';
import '../widgets/records_timeline_panel.dart';

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

  bool _showTimeline = false;
  bool _timelineAscending = true;

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
      final previous = _viewModel;

      _viewModel = _createViewModel();
      _showTimeline = false;
      _timelineAscending = true;

      previous.dispose();
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
      child: _ExploreRecordsContent(
        showTimeline: _showTimeline,
        timelineAscending: _timelineAscending,
        onModeChanged: (showTimeline) {
          if (_showTimeline == showTimeline) {
            return;
          }

          setState(() {
            _showTimeline = showTimeline;
          });
        },
        onOrderChanged: (ascending) {
          if (_timelineAscending == ascending) {
            return;
          }

          setState(() {
            _timelineAscending = ascending;
          });
        },
      ),
    );
  }
}

class _ExploreRecordsContent extends StatelessWidget {
  const _ExploreRecordsContent({
    required this.showTimeline,
    required this.timelineAscending,
    required this.onModeChanged,
    required this.onOrderChanged,
  });

  final bool showTimeline;
  final bool timelineAscending;
  final ValueChanged<bool> onModeChanged;
  final ValueChanged<bool> onOrderChanged;

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

  Future<void> _pickMonth(
    BuildContext context,
    MonthlyCalendarViewModel viewModel,
  ) async {
    final selected = await showMonthYearPicker(
      context: context,
      initialMonth: viewModel.visibleMonth,
    );

    if (!context.mounted || viewModel.isDisposed || selected == null) {
      return;
    }

    final current = context.read<MonthlyCalendarViewModel>();

    if (!identical(current, viewModel)) {
      return;
    }

    viewModel.selectDate(DateTime(selected.year, selected.month));
  }

  Future<void> _pickDate(
    BuildContext context,
    MonthlyCalendarViewModel viewModel, {
    required bool isStartDate,
  }) async {
    final maximumDate = DateTime(DateTime.now().year, 12, 31);

    final minimumDate = DateTime(2000);

    var firstDate = isStartDate
        ? minimumDate
        : (viewModel.startDate ?? minimumDate);

    var lastDate = isStartDate
        ? (viewModel.endDate ?? maximumDate)
        : maximumDate;

    if (firstDate.isAfter(maximumDate)) {
      firstDate = maximumDate;
    }

    if (lastDate.isAfter(maximumDate)) {
      lastDate = maximumDate;
    }

    if (firstDate.isBefore(minimumDate)) {
      firstDate = minimumDate;
    }

    if (lastDate.isBefore(firstDate)) {
      lastDate = firstDate;
    }

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

    final current = context.read<MonthlyCalendarViewModel>();

    if (!identical(current, viewModel)) {
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
    final source = record.sourceRecord;
    final expectedId = viewModel.anonymousId.trim();

    if (source == null ||
        viewModel.isDisposed ||
        record.anonymousId != expectedId) {
      return;
    }

    await context.push<void>(_detailRoute(record.type), extra: source);

    if (!context.mounted || viewModel.isDisposed) {
      return;
    }

    final current = context.read<MonthlyCalendarViewModel>();

    if (!identical(current, viewModel) ||
        current.anonymousId.trim() != expectedId) {
      return;
    }

    await viewModel.load();
  }

  List<MonthlyCalendarRecord> _timelineRecords(
    MonthlyCalendarViewModel viewModel,
  ) {
    final index = viewModel.index;

    if (index == null) {
      return const <MonthlyCalendarRecord>[];
    }

    final month = viewModel.visibleMonth;

    final monthStart = DateTime(month.year, month.month);
    final monthEnd = DateTime(month.year, month.month + 1, 0);

    final filteredStart = viewModel.startDate;
    final filteredEnd = viewModel.endDate;

    // Ambas vistas consultan el mes visible y respetan
    // los mismos límites opcionales de fecha.
    final start = filteredStart != null && filteredStart.isAfter(monthStart)
        ? filteredStart
        : monthStart;

    final end = filteredEnd != null && filteredEnd.isBefore(monthEnd)
        ? filteredEnd
        : monthEnd;

    if (end.isBefore(start)) {
      return const <MonthlyCalendarRecord>[];
    }

    return index.recordsInPeriod(
      startDate: start,
      endDate: end,
      selectedTypes: viewModel.selectedTypes,
    );
  }

  Widget _monthSelector(
    BuildContext context,
    MonthlyCalendarViewModel viewModel, {
    bool withCalendarGrid = false,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.fromLTRB(10, 12, 10, withCalendarGrid ? 16 : 12),
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
                  child: TextButton(
                    key: const Key('monthly-calendar-open-month-picker'),
                    onPressed: () {
                      unawaited(_pickMonth(context, viewModel));
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            _monthLabel(viewModel.visibleMonth),
                            key: const Key('monthly-calendar-month'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_drop_down_rounded, size: 21),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('monthly-calendar-next'),
                  tooltip: 'Mes siguiente',
                  onPressed: viewModel.canGoToNextMonth
                      ? () => viewModel.changeMonth(1)
                      : null,
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            if (withCalendarGrid) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final day in _weekdays)
                    Expanded(
                      child: Text(
                        day,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              _buildCalendarGrid(context, viewModel),
            ] else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Registros de ${_monthLabel(viewModel.visibleMonth)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _calendarContent(
    BuildContext context,
    MonthlyCalendarViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final records = viewModel.selectedDayRecords;
    final monthCount = viewModel.monthCount;

    return [
      Text(
        'Consulta los registros por fecha',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Selecciona una fecha para consultar los '
        'registros del seguimiento actual. '
        'Toca el mes para cambiar de mes o año.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 16),
      MonthlyCoverageSummary(
        index: viewModel.index,
        visibleMonth: viewModel.visibleMonth,
        startDate: viewModel.startDate,
        endDate: viewModel.endDate,
        isLoading: viewModel.isLoading,
        hasError: viewModel.errorMessage != null,
      ),
      const SizedBox(height: 12),
      _monthSelector(context, viewModel, withCalendarGrid: true),
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
                : () => unawaited(viewModel.load()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
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
              leading: Icon(_recordIcon(record.type), color: colors.primary),
              title: Text(record.type.label),
              subtitle: Text(record.description),
              trailing: record.sourceRecord == null
                  ? null
                  : const Icon(Icons.chevron_right_rounded),
              onTap: record.sourceRecord == null
                  ? null
                  : () => unawaited(_openRecord(context, viewModel, record)),
            ),
          ),
        ),
      const SizedBox(height: 12),
      ..._filterWidgets(context, viewModel),
    ];
  }

  List<Widget> _timelineContent(
    BuildContext context,
    MonthlyCalendarViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return [
      Text(
        'Secuencia de acontecimientos',
        style: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Recorre los registros del mes en orden cronológico. '
        'Las fechas agrupan los acontecimientos de cada día.',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 14),
      _monthSelector(context, viewModel),
      const SizedBox(height: 12),
      ..._filterWidgets(context, viewModel),
      const SizedBox(height: 16),
      if (viewModel.isLoading)
        const Center(child: CircularProgressIndicator())
      else if (viewModel.errorMessage != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            viewModel.errorMessage!,
            key: const Key('records-timeline-load-error'),
          ),
        )
      else
        RecordsTimelinePanel(
          records: _timelineRecords(viewModel),
          ascending: timelineAscending,
          onOrderChanged: onOrderChanged,
          onRecordTap: (record) =>
              unawaited(_openRecord(context, viewModel, record)),
        ),
    ];
  }

  List<Widget> _filterWidgets(
    BuildContext context,
    MonthlyCalendarViewModel viewModel,
  ) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return [
      OutlinedButton.icon(
        key: const Key('monthly-calendar-filter-toggle'),
        onPressed: viewModel.toggleFilters,
        icon: const Icon(Icons.filter_list_rounded),
        label: Text(
          viewModel.filtersExpanded ? 'Ocultar filtros' : 'Filtrar registros',
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
                onPressed: () =>
                    unawaited(_pickDate(context, viewModel, isStartDate: true)),
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
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
                onPressed: () => unawaited(
                  _pickDate(context, viewModel, isStartDate: false),
                ),
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
    ];
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

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 3.0;

        final cellWidth = (constraints.maxWidth - spacing * 6) / 7;
        final cellHeight = (cellWidth / 0.90).clamp(48.0, 62.0).toDouble();

        return GridView.builder(
          key: const Key('monthly-calendar-grid'),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            mainAxisExtent: cellHeight,
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
                onTap: () => viewModel.selectDate(date),
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
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      if (count > 0)
                        Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 12,
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
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<MonthlyCalendarViewModel>();

    return Scaffold(
      key: const Key('monthly-calendar-screen'),
      appBar: AppBar(title: const Text('Explorar registros')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: viewModel.load,
          child: ListView(
            key: const Key('monthly-calendar-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<bool>(
                  key: const Key('records-view-switch'),
                  segments: const [
                    ButtonSegment<bool>(
                      value: false,
                      icon: Icon(Icons.calendar_month_outlined),
                      label: Text(
                        'Calendario',
                        key: Key('records-view-calendar'),
                      ),
                    ),
                    ButtonSegment<bool>(
                      value: true,
                      icon: Icon(Icons.timeline_rounded),
                      label: Text(
                        'Línea temporal',
                        key: Key('records-view-timeline'),
                      ),
                    ),
                  ],
                  selected: {showTimeline},
                  onSelectionChanged: (selection) {
                    onModeChanged(selection.single);
                  },
                  showSelectedIcon: false,
                ),
              ),
              const SizedBox(height: 20),
              if (showTimeline)
                ..._timelineContent(context, viewModel)
              else
                ..._calendarContent(context, viewModel),
            ],
          ),
        ),
      ),
    );
  }
}
