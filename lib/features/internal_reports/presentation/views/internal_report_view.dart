import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../duration/domain/models/duration_metric_type.dart';
import '../../../duration/presentation/widgets/duration_observation_chart.dart';
import '../../../duration/presentation/widgets/duration_summary_cards.dart';
import '../../../frequency/domain/models/monthly_calendar_record.dart';
import '../../../routine_compliance/presentation/widgets/routine_status_distribution_bar.dart';
import '../../../tracking/presentation/viewmodels/tracking_view_model.dart';
import '../../domain/models/internal_report.dart';
import '../../domain/services/internal_report_service.dart';
import '../models/internal_report_routine_details.dart';
import '../services/internal_report_pdf_service.dart';
import '../viewmodels/internal_report_view_model.dart';
import '../widgets/internal_report_category_chart.dart';
import '../widgets/internal_report_event_card.dart';
import '../widgets/internal_report_pdf_open_button.dart';
import '../widgets/internal_report_routine_detail_card.dart';

enum _ReportSection {
  summary,
  distribution,
  coverage,
  events,
  compliance,
  routines,
  durations,
}

class InternalReportView extends StatefulWidget {
  const InternalReportView({
    required this.service,
    required this.anonymousId,
    this.clock,
    this.pdfScopeChanges,
    this.pdfIsAuthorized,
    super.key,
  });

  final InternalReportService service;
  final String anonymousId;
  final DateTime Function()? clock;
  final Listenable? pdfScopeChanges;
  final bool Function()? pdfIsAuthorized;

  @override
  State<InternalReportView> createState() => _InternalReportViewState();
}

class _InternalReportViewState extends State<InternalReportView> {
  late InternalReportViewModel _viewModel;

  Set<_ReportSection> _expandedSections = _ReportSection.values.toSet();

  @override
  void initState() {
    super.initState();
    _viewModel = _createViewModel();
  }

  InternalReportViewModel _createViewModel() {
    return InternalReportViewModel(
      widget.service,
      anonymousId: widget.anonymousId,
      clock: widget.clock,
    );
  }

  @override
  void didUpdateWidget(covariant InternalReportView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.anonymousId != widget.anonymousId ||
        oldWidget.service != widget.service) {
      final previous = _viewModel;
      _viewModel = _createViewModel();

      _expandedSections = _ReportSection.values.toSet();

      previous.dispose();
    }
  }

  void _toggleSection(_ReportSection section) {
    setState(() {
      final updated = Set<_ReportSection>.of(_expandedSections);

      if (!updated.add(section)) {
        updated.remove(section);
      }

      _expandedSections = updated;
    });
  }

  void _expandAll() {
    setState(() {
      _expandedSections = _ReportSection.values.toSet();
    });
  }

  void _collapseAll() {
    setState(() {
      _expandedSections = <_ReportSection>{};
    });
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<InternalReportViewModel>.value(
      value: _viewModel,
      child: _InternalReportContent(
        clock: widget.clock,
        pdfScopeChanges: widget.pdfScopeChanges,
        pdfIsAuthorized: widget.pdfIsAuthorized,
        expandedSections: _expandedSections,
        onToggleSection: _toggleSection,
        onExpandAll: _expandAll,
        onCollapseAll: _collapseAll,
      ),
    );
  }
}

class _ReportSectionHeader extends StatelessWidget {
  const _ReportSectionHeader({
    required this.section,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.expanded,
    required this.onTap,
    this.titleKey,
  });

  final _ReportSection section;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool expanded;
  final VoidCallback onTap;
  final Key? titleKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      key: Key('internal-report-section-${section.name}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        key: Key('internal-report-toggle-${section.name}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
        leading: Icon(icon, color: colors.primary, size: 23),
        title: Text(
          title,
          key: titleKey,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
        trailing: Icon(
          expanded
              ? Icons.keyboard_arrow_up_rounded
              : Icons.keyboard_arrow_down_rounded,
          color: colors.primary,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _InternalReportContent extends StatelessWidget {
  const _InternalReportContent({
    this.clock,
    required this.pdfScopeChanges,
    required this.pdfIsAuthorized,
    required this.expandedSections,
    required this.onToggleSection,
    required this.onExpandAll,
    required this.onCollapseAll,
  });

  final DateTime Function()? clock;
  final Listenable? pdfScopeChanges;
  final bool Function()? pdfIsAuthorized;
  final Set<_ReportSection> expandedSections;
  final void Function(_ReportSection) onToggleSection;
  final VoidCallback onExpandAll;
  final VoidCallback onCollapseAll;

  Future<void> _pickDate(
    BuildContext context,
    InternalReportViewModel viewModel, {
    required bool isStartDate,
  }) async {
    final today = DateUtils.dateOnly((clock ?? DateTime.now)());
    final firstDate = DateTime(2000);

    final current = isStartDate
        ? viewModel.period.startDate
        : viewModel.period.endDate;

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
          ? 'Fecha inicial del reporte'
          : 'Fecha final del reporte',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (!context.mounted || selected == null || viewModel.isDisposed) {
      return;
    }

    final currentViewModel = context.read<InternalReportViewModel>();

    if (!identical(currentViewModel, viewModel)) {
      return;
    }

    viewModel.setDate(isStartDate: isStartDate, date: selected);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<InternalReportViewModel>();
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final loadedReport = viewModel.report;

    final InternalReport? report =
        !viewModel.isDisposed &&
            !viewModel.isLoading &&
            viewModel.errorMessage == null &&
            loadedReport != null &&
            loadedReport.anonymousId == viewModel.anonymousId
        ? loadedReport
        : null;

    TrackingViewModel? trackingViewModel;

    try {
      trackingViewModel = context.watch<TrackingViewModel>();
    } on ProviderNotFoundException {
      trackingViewModel = null;
    }

    final profile = trackingViewModel?.activeProfile;

    final resolvedNumber =
        trackingViewModel != null &&
            profile != null &&
            profile.anonymousId == viewModel.anonymousId &&
            trackingViewModel.hasActiveProfile
        ? trackingViewModel.trackingNumberFor(profile)
        : null;

    final trackingNumber = resolvedNumber != null && resolvedNumber > 0
        ? resolvedNumber
        : null;

    final events = report == null
        ? <MonthlyCalendarRecord>[]
        : report.records
              .where(
                (record) =>
                    record.anonymousId == report.anonymousId &&
                    record.type != CalendarRecordType.routineStatus,
              )
              .toList(growable: false);

    final routineDetails = report == null
        ? null
        : InternalReportRoutineDetails.fromReport(report);

    bool isExpanded(_ReportSection section) {
      return expandedSections.contains(section);
    }

    return Scaffold(
      key: const Key('internal-report-screen'),
      appBar: AppBar(title: const Text('Reportes internos')),
      body: SafeArea(
        child: CustomScrollView(
          key: const Key('internal-report-scroll'),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reporte del seguimiento',
                      key: const Key('internal-report-title'),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (trackingNumber != null) ...[
                      Text(
                        'Seguimiento $trackingNumber',
                        key: const Key('internal-report-tracking-label'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      'Consulta los registros e indicadores '
                      'descriptivos del seguimiento actual '
                      'en un periodo seleccionado.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Card(
                      key: const Key('internal-report-period-card'),
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Periodo del reporte',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${DurationSummaryCards.formatDate(viewModel.period.startDate)}'
                              ' – '
                              '${DurationSummaryCards.formatDate(viewModel.period.endDate)}',
                              key: const Key('internal-report-selected-dates'),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  key: const Key('internal-report-start-date'),
                                  onPressed: () {
                                    unawaited(
                                      _pickDate(
                                        context,
                                        viewModel,
                                        isStartDate: true,
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 17,
                                  ),
                                  label: const Text('Desde'),
                                ),
                                OutlinedButton.icon(
                                  key: const Key('internal-report-end-date'),
                                  onPressed: () {
                                    unawaited(
                                      _pickDate(
                                        context,
                                        viewModel,
                                        isStartDate: false,
                                      ),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.event_outlined,
                                    size: 17,
                                  ),
                                  label: const Text('Hasta'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('internal-report-generate-button'),
                        onPressed: viewModel.isLoading
                            ? null
                            : () {
                                unawaited(viewModel.load());
                              },
                        icon: const Icon(Icons.description_outlined),
                        label: const Text('Generar reporte'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (viewModel.isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                            key: Key('internal-report-loading'),
                          ),
                        ),
                      )
                    else if (viewModel.errorMessage != null)
                      Card(
                        key: const Key('internal-report-error'),
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline_rounded,
                                color: colors.error,
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Text(viewModel.errorMessage!)),
                            ],
                          ),
                        ),
                      )
                    else if (report != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (pdfScopeChanges != null &&
                              pdfIsAuthorized != null) ...[
                            InternalReportPdfOpenButton(
                              trackingNumber: trackingNumber,
                              scopeChanges: Listenable.merge([
                                viewModel,
                                pdfScopeChanges!,
                              ]),
                              isAuthorized: () {
                                if (viewModel.isDisposed ||
                                    viewModel.isLoading ||
                                    !identical(viewModel.report, report) ||
                                    viewModel.anonymousId !=
                                        report.anonymousId) {
                                  return false;
                                }

                                if (trackingViewModel != null) {
                                  final active =
                                      trackingViewModel.activeProfile;

                                  if (active == null ||
                                      !trackingViewModel.hasActiveProfile ||
                                      active.anonymousId !=
                                          report.anonymousId ||
                                      trackingNumber == null ||
                                      trackingViewModel.trackingNumberFor(
                                            active,
                                          ) !=
                                          trackingNumber) {
                                    return false;
                                  }
                                }

                                try {
                                  return pdfIsAuthorized!();
                                } catch (_) {
                                  return false;
                                }
                              },
                              generatePdf: () =>
                                  const InternalReportPdfService().generate(
                                    report,
                                    trackingNumber: trackingNumber,
                                  ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          _InternalReportResults(
                            report: report,
                            eventsCount: events.length,
                            trackingNumber: trackingNumber,
                            expandedSections: expandedSections,
                            onToggleSection: onToggleSection,
                            onExpandAll: onExpandAll,
                            onCollapseAll: onCollapseAll,
                          ),
                        ],
                      )
                    else
                      Card(
                        key: const Key('internal-report-prompt'),
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Selecciona las fechas y pulsa '
                                  '«Generar reporte» para consultar '
                                  'la información del periodo.',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            if (report != null &&
                events.isNotEmpty &&
                isExpanded(_ReportSection.events))
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: events.length,
                  itemBuilder: (context, index) {
                    return InternalReportEventCard(
                      record: events[index],
                      anonymousId: report.anonymousId,
                    );
                  },
                ),
              ),

            if (report != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _InternalReportRoutineSection(
                    report: report,
                    detailsCount: routineDetails?.total ?? 0,
                    complianceExpanded: isExpanded(_ReportSection.compliance),
                    routinesExpanded: isExpanded(_ReportSection.routines),
                    onToggleSection: onToggleSection,
                  ),
                ),
              ),

            if (report != null &&
                routineDetails != null &&
                !routineDetails.isEmpty &&
                isExpanded(_ReportSection.routines))
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList.builder(
                  itemCount: routineDetails.entries.length,
                  itemBuilder: (context, index) {
                    return InternalReportRoutineDetailCard(
                      report: report,
                      entry: routineDetails.entries[index],
                    );
                  },
                ),
              ),

            if (report != null)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _InternalReportDurationsSection(
                    report: report,
                    expanded: isExpanded(_ReportSection.durations),
                    onToggle: () {
                      onToggleSection(_ReportSection.durations);
                    },
                  ),
                ),
              ),

            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }
}

class _InternalReportResults extends StatelessWidget {
  const _InternalReportResults({
    required this.report,
    required this.eventsCount,
    required this.trackingNumber,
    required this.expandedSections,
    required this.onToggleSection,
    required this.onExpandAll,
    required this.onCollapseAll,
  });

  final InternalReport report;
  final int eventsCount;
  final int? trackingNumber;
  final Set<_ReportSection> expandedSections;
  final void Function(_ReportSection) onToggleSection;
  final VoidCallback onExpandAll;
  final VoidCallback onCollapseAll;

  bool _isExpanded(_ReportSection section) {
    return expandedSections.contains(section);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final categoryCount = CalendarRecordType.values
        .where((type) => report.countFor(type) > 0)
        .length;

    return Column(
      key: const Key('internal-report-results'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.summarize_outlined, color: colors.primary, size: 27),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Reporte generado',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (trackingNumber != null) ...[
          Text(
            'Seguimiento $trackingNumber',
            key: const Key('internal-report-result-tracking-label'),
            style: theme.textTheme.titleMedium?.copyWith(
              color: colors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          '${DurationSummaryCards.formatDate(report.period.startDate)}'
          ' – '
          '${DurationSummaryCards.formatDate(report.period.endDate)}',
          key: const Key('internal-report-result-period'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colors.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              key: const Key('internal-report-expand-all'),
              onPressed: onExpandAll,
              icon: const Icon(Icons.unfold_more_rounded, size: 19),
              label: const Text('Expandir todo'),
            ),
            TextButton.icon(
              key: const Key('internal-report-collapse-all'),
              onPressed: onCollapseAll,
              icon: const Icon(Icons.unfold_less_rounded, size: 19),
              label: const Text('Contraer todo'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (!report.hasAnyInformation) ...[
          const Card(
            key: Key('internal-report-no-data'),
            margin: EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No existen registros ni indicadores disponibles '
                'en el periodo seleccionado. El reporte '
                'no presenta valores estimados.',
              ),
            ),
          ),
        ],
        _ReportSectionHeader(
          section: _ReportSection.summary,
          title: 'Resumen de registros',
          subtitle: '${report.totalRecords} registros del periodo',
          icon: Icons.format_list_numbered_rounded,
          expanded: _isExpanded(_ReportSection.summary),
          onTap: () => onToggleSection(_ReportSection.summary),
        ),
        if (_isExpanded(_ReportSection.summary)) ...[
          _InternalReportRecordsSummary(report: report),
          const SizedBox(height: 12),
        ],
        _ReportSectionHeader(
          section: _ReportSection.distribution,
          title: 'Distribución de registros',
          subtitle: '$categoryCount categorías con registros',
          icon: Icons.bar_chart_rounded,
          expanded: _isExpanded(_ReportSection.distribution),
          onTap: () => onToggleSection(_ReportSection.distribution),
        ),
        if (_isExpanded(_ReportSection.distribution)) ...[
          InternalReportCategoryChart(report: report),
          const SizedBox(height: 12),
        ],
        _ReportSectionHeader(
          section: _ReportSection.coverage,
          title: 'Cobertura de registros',
          subtitle:
              '${_formatPercentage(report.coveragePercentage)} · '
              '${report.daysWithRecords} de ${report.totalDays} días',
          icon: Icons.calendar_month_outlined,
          expanded: _isExpanded(_ReportSection.coverage),
          onTap: () => onToggleSection(_ReportSection.coverage),
        ),
        if (_isExpanded(_ReportSection.coverage)) ...[
          _InternalReportCoverageCard(report: report),
          const SizedBox(height: 12),
        ],
        if (eventsCount > 0) ...[
          _ReportSectionHeader(
            section: _ReportSection.events,
            title: 'Detalle de eventos registrados',
            subtitle:
                '$eventsCount '
                '${eventsCount == 1 ? 'evento' : 'eventos'} en el periodo',
            icon: Icons.event_note_outlined,
            expanded: _isExpanded(_ReportSection.events),
            titleKey: const Key('internal-report-records-title'),
            onTap: () => onToggleSection(_ReportSection.events),
          ),
          if (_isExpanded(_ReportSection.events)) ...[
            Text(
              '$eventsCount '
              '${eventsCount == 1 ? 'evento' : 'eventos'} '
              'en el periodo',
              key: const Key('internal-report-events-count'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Acontecimientos ordenados desde el más reciente. '
              'Los estados de rutina se presentan por separado.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _InternalReportRoutineSection extends StatelessWidget {
  const _InternalReportRoutineSection({
    required this.report,
    required this.detailsCount,
    required this.complianceExpanded,
    required this.routinesExpanded,
    required this.onToggleSection,
  });

  final InternalReport report;
  final int detailsCount;
  final bool complianceExpanded;
  final bool routinesExpanded;
  final void Function(_ReportSection) onToggleSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportSectionHeader(
          section: _ReportSection.compliance,
          title: 'Cumplimiento de rutinas',
          subtitle:
              '${_formatPercentage(report.routineCompliancePercentage)} '
              '· ${report.completedRoutineCount} de '
              '${report.routineStatusCount} completadas',
          icon: Icons.fact_check_outlined,
          expanded: complianceExpanded,
          onTap: () => onToggleSection(_ReportSection.compliance),
        ),
        if (complianceExpanded) ...[
          _InternalReportRoutineCard(report: report),
          const SizedBox(height: 12),
          RoutineStatusDistributionBar(overview: report.routines),
          const SizedBox(height: 14),
        ],
        if (detailsCount > 0) ...[
          _ReportSectionHeader(
            section: _ReportSection.routines,
            title: 'Rutinas registradas en el periodo',
            subtitle:
                '$detailsCount '
                '${detailsCount == 1 ? 'estado' : 'estados'} registrados',
            icon: Icons.event_repeat_outlined,
            expanded: routinesExpanded,
            titleKey: const Key('internal-report-routines-detail-title'),
            onTap: () => onToggleSection(_ReportSection.routines),
          ),
          if (routinesExpanded) ...[
            Text(
              '$detailsCount '
              '${detailsCount == 1 ? 'estado registrado' : 'estados registrados'}',
              key: const Key('internal-report-routines-detail-count'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Cada tarjeta identifica la rutina, su fecha, estado '
              'y observación disponible. Una misma rutina puede '
              'aparecer en diferentes fechas.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _InternalReportDurationsSection extends StatelessWidget {
  const _InternalReportDurationsSection({
    required this.report,
    required this.expanded,
    required this.onToggle,
  });

  final InternalReport report;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ReportSectionHeader(
          section: _ReportSection.durations,
          title: 'Resumen de duraciones',
          subtitle: 'Sueño, conducta y desregulación emocional',
          icon: Icons.timelapse_outlined,
          expanded: expanded,
          onTap: onToggle,
        ),
        if (expanded) ...[
          Text(
            'Promedios calculados únicamente con duraciones válidas.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          for (final type in DurationMetricType.values) ...[
            _InternalReportDurationCard(report: report, type: type),
            const SizedBox(height: 10),
            DurationObservationChart(
              type: type,
              result: report.durations.resultFor(type),
            ),
            const SizedBox(height: 12),
          ],
        ],
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              color: colors.onSurfaceVariant,
              size: 19,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Este reporte es exclusivamente de consulta interna. '
                'No se almacena como un nuevo documento ni incluye '
                'funciones de envío o divulgación. '
                'Los indicadores son descriptivos y '
                'no constituyen una evaluación clínica.',
                key: const Key('internal-report-disclaimer'),
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

class _InternalReportRecordsSummary extends StatelessWidget {
  const _InternalReportRecordsSummary({required this.report});

  final InternalReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      key: const Key('internal-report-records-summary'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen de registros',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${report.totalRecords}',
              key: const Key('internal-report-total-count'),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
            Text(
              report.totalRecords == 1
                  ? 'registro en el periodo'
                  : 'registros en el periodo',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            if (report.records.isNotEmpty) ...[
              const SizedBox(height: 14),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 13),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in CalendarRecordType.values)
                    if (report.countFor(type) > 0)
                      Chip(
                        key: Key('internal-report-count-${type.name}'),
                        label: Text('${type.label}: ${report.countFor(type)}'),
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

class _InternalReportCoverageCard extends StatelessWidget {
  const _InternalReportCoverageCard({required this.report});

  final InternalReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final percentage = report.coveragePercentage;

    return Card(
      key: const Key('internal-report-coverage-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.calendar_month_outlined,
                  color: colors.primary,
                  size: 23,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Cobertura de registros',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _formatPercentage(percentage),
              key: const Key('internal-report-coverage-percentage'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              key: const Key('internal-report-coverage-progress'),
              value: percentage / 100,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: colors.surfaceContainerHighest,
            ),
            const SizedBox(height: 9),
            Text(
              '${report.daysWithRecords} de '
              '${report.totalDays} días con registros',
              key: const Key('internal-report-coverage-days'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Cada día con uno o más registros se cuenta '
              'una sola vez para calcular la cobertura.',
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

class _InternalReportDurationCard extends StatelessWidget {
  const _InternalReportDurationCard({required this.report, required this.type});

  final InternalReport report;
  final DurationMetricType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final average = report.averageMinutesFor(type);
    final count = report.validDurationsFor(type);

    final value = average == null
        ? 'Sin datos'
        : DurationSummaryCards.formatDuration(type, average);

    return Card(
      key: Key('internal-report-duration-${type.name}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Duración promedio: ${type.label}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              key: Key('internal-report-duration-value-${type.name}'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: average == null ? colors.onSurface : colors.primary,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '$count '
              '${count == 1 ? 'registro válido' : 'registros válidos'} '
              'para el promedio. '
              '${type == DurationMetricType.sleep ? 'Unidad: horas y minutos.' : 'Unidad: minutos.'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InternalReportRoutineCard extends StatelessWidget {
  const _InternalReportRoutineCard({required this.report});

  final InternalReport report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final percentage = report.routineCompliancePercentage;

    return Card(
      key: const Key('internal-report-routine-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cumplimiento de rutinas',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _formatPercentage(percentage),
              key: const Key('internal-report-routine-percentage'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: percentage == null ? colors.onSurface : colors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              report.routineStatusCount == 0
                  ? 'Sin estados registrados'
                  : '${report.completedRoutineCount} completadas de '
                        '${report.routineStatusCount} registradas',
              key: const Key('internal-report-routine-count'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'El porcentaje corresponde a los estados completados '
              'respecto del total de estados de rutina registrados.',
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
