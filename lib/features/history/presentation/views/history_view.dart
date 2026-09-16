import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/history_record.dart';
import '../../domain/models/history_record_type.dart';
import '../../domain/repositories/history_repository.dart';
import '../viewmodels/history_view_model.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({
    required this.repository,
    required this.anonymousId,
    super.key,
  });

  final HistoryRepository repository;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          HistoryViewModel(repository, anonymousId: anonymousId)..initialize(),
      child: const _HistoryContent(),
    );
  }
}

class _HistoryContent extends StatefulWidget {
  const _HistoryContent();

  @override
  State<_HistoryContent> createState() => _HistoryContentState();
}

class _HistoryContentState extends State<_HistoryContent> {
  bool _filtersExpanded = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HistoryViewModel>();

    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            key: const Key('history-refresh-button'),
            tooltip: 'Actualizar',
            onPressed: viewModel.isLoading ? null : viewModel.reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await viewModel.reload();
          },
          child: _buildBody(context, viewModel),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HistoryViewModel viewModel) {
    if (viewModel.isLoading && !viewModel.hasLoaded) {
      return ListView(
        key: const Key('history-loading-state'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (viewModel.errorMessage != null && !viewModel.hasRecords) {
      return ListView(
        key: const Key('history-error-state'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _HistoryErrorState(
            message: viewModel.errorMessage!,
            onRetry: viewModel.reload,
          ),
        ],
      );
    }

    if (viewModel.isEmpty) {
      return ListView(
        key: const Key('history-empty-state'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          _HistoryIntroCard(),
          SizedBox(height: 24),
          _HistoryEmptyState(),
        ],
      );
    }

    return ListView(
      key: const Key('history-records-list'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const _HistoryIntroCard(),

        if (viewModel.errorMessage != null) ...[
          const SizedBox(height: 16),

          _HistoryInlineError(message: viewModel.errorMessage!),
        ],

        const SizedBox(height: 20),

        _HistoryFilterCard(
          expanded: _filtersExpanded,
          viewModel: viewModel,
          onToggleExpanded: () {
            setState(() {
              _filtersExpanded = !_filtersExpanded;
            });
          },
          onApplied: () {
            if (!mounted) {
              return;
            }

            setState(() {
              _filtersExpanded = false;
            });
          },
        ),

        const SizedBox(height: 24),

        _HistorySectionHeader(
          visibleCount: viewModel.filteredRecordCount,
          totalCount: viewModel.records.length,
          hasActiveFilters: viewModel.hasActiveFilters,
        ),

        const SizedBox(height: 12),

        if (viewModel.hasNoFilterResults)
          _HistoryNoFilterResults(onClearFilters: viewModel.clearFilters)
        else
          for (final record in viewModel.filteredRecords)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _HistoryRecordCard(
                key: Key('history-record-${record.recordId}'),
                record: record,
              ),
            ),
      ],
    );
  }
}

class _HistoryIntroCard extends StatelessWidget {
  const _HistoryIntroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('history-intro-card'),
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
            child: Icon(Icons.history_rounded, color: colorScheme.onPrimary),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consulta tus registros',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Revisa la información registrada '
                  'para el perfil activo, ordenada '
                  'desde la más reciente.',
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

class _HistoryFilterCard extends StatelessWidget {
  const _HistoryFilterCard({
    required this.expanded,
    required this.viewModel,
    required this.onToggleExpanded,
    required this.onApplied,
  });

  final bool expanded;
  final HistoryViewModel viewModel;
  final VoidCallback onToggleExpanded;
  final VoidCallback onApplied;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final hasPendingSelection =
        viewModel.pendingStartDate != null ||
        viewModel.pendingEndDate != null ||
        viewModel.pendingSelectedTypes.isNotEmpty;

    return Card(
      key: const Key('history-filter-card'),
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            key: const Key('history-filter-toggle-button'),
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(22),
              bottom: Radius.circular(expanded ? 0 : 22),
            ),
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.65,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.tune_rounded, color: colorScheme.primary),
                  ),

                  const SizedBox(width: 13),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Filtros',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            if (viewModel.hasActiveFilters) ...[
                              const SizedBox(width: 8),

                              Container(
                                key: const Key(
                                  'history-active-filters-indicator',
                                ),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 4),

                        Text(
                          viewModel.hasActiveFilters
                              ? '${viewModel.filteredRecordCount} de ${viewModel.records.length} registros visibles'
                              : 'Filtra por periodo y tipo de registro.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (expanded) ...[
            Divider(height: 1, color: colorScheme.outlineVariant),

            Padding(
              key: const Key('history-filter-panel'),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        child: _HistoryDateButton(
                          key: const Key('history-start-date-button'),
                          label: 'Desde',
                          value: viewModel.pendingStartDate,
                          onTap: () async {
                            final selected = await _selectDate(
                              context: context,
                              title: 'Fecha inicial',
                              initialDate:
                                  viewModel.pendingStartDate ??
                                  _oldestRecordDate(viewModel.records),
                            );

                            if (selected != null) {
                              viewModel.setPendingStartDate(selected);
                            }
                          },
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: _HistoryDateButton(
                          key: const Key('history-end-date-button'),
                          label: 'Hasta',
                          value: viewModel.pendingEndDate,
                          onTap: () async {
                            final selected = await _selectDate(
                              context: context,
                              title: 'Fecha final',
                              initialDate:
                                  viewModel.pendingEndDate ??
                                  _newestRecordDate(viewModel.records),
                            );

                            if (selected != null) {
                              viewModel.setPendingEndDate(selected);
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  if (viewModel.filterErrorFor('period') != null) ...[
                    const SizedBox(height: 10),

                    Container(
                      key: const Key('history-filter-period-error'),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withValues(
                          alpha: 0.70,
                        ),
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
                              viewModel.filterErrorFor('period')!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  Text(
                    'Tipos de registro',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 5),

                  Text(
                    'Puedes seleccionar uno o varios tipos.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final type in HistoryRecordType.values)
                        FilterChip(
                          key: Key('history-filter-type-${type.code}'),
                          label: Text(type.label),
                          avatar: Icon(_iconFor(type), size: 18),
                          showCheckmark: false,
                          selected: viewModel.isPendingTypeSelected(type),
                          onSelected: (_) {
                            viewModel.togglePendingType(type);
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const Key('history-clear-filters-button'),
                          onPressed:
                              viewModel.hasActiveFilters || hasPendingSelection
                              ? () {
                                  viewModel.clearFilters();
                                }
                              : null,
                          child: const Text('Quitar filtros'),
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: FilledButton.icon(
                          key: const Key('history-apply-filters-button'),
                          onPressed: () {
                            final success = viewModel.applyFilters();

                            if (success) {
                              onApplied();
                            }
                          },
                          icon: const Icon(Icons.filter_alt_outlined),
                          label: const Text('Aplicar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryDateButton extends StatelessWidget {
  const _HistoryDateButton({
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
                  value == null ? 'Sin seleccionar' : _formatEventDate(value!),
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

class _HistorySectionHeader extends StatelessWidget {
  const _HistorySectionHeader({
    required this.visibleCount,
    required this.totalCount,
    required this.hasActiveFilters,
  });

  final int visibleCount;
  final int totalCount;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Registros',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_downward_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),

              const SizedBox(width: 5),

              Text(
                hasActiveFilters
                    ? '$visibleCount de $totalCount'
                    : 'Más reciente',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryRecordCard extends StatelessWidget {
  const _HistoryRecordCard({required this.record, super.key});

  final HistoryRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final accentColor = _accentColorFor(record.type);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accentColor.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.20 : 0.14,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                _iconFor(record.type),
                color: theme.brightness == Brightness.dark
                    ? Color.lerp(accentColor, Colors.white, 0.25)
                    : accentColor,
                size: 25,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.type.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),

                      const SizedBox(width: 6),

                      Expanded(
                        child: Text(
                          _formatEventDate(record.eventDate),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
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

class _HistoryNoFilterResults extends StatelessWidget {
  const _HistoryNoFilterResults({required this.onClearFilters});

  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Card(
      key: const Key('history-no-filter-results'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.filter_alt_off_outlined,
                size: 30,
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'No hay registros que coincidan',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              'Prueba con otro periodo o selecciona otros tipos de registro.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 18),

            TextButton.icon(
              key: const Key('history-no-results-clear-button'),
              onPressed: onClearFilters,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Quitar filtros'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                size: 32,
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'Aún no hay registros',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              'Cuando registres información '
              'para el perfil activo, '
              'aparecerá aquí.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
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

class _HistoryErrorState extends StatelessWidget {
  const _HistoryErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: colorScheme.onErrorContainer,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'No pudimos cargar el historial',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              key: const Key('history-retry-button'),
              onPressed: () {
                onRetry();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Intentar nuevamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryInlineError extends StatelessWidget {
  const _HistoryInlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Container(
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

DateTime _oldestRecordDate(List<HistoryRecord> records) {
  if (records.isEmpty) {
    return DateTime.now();
  }

  return records.last.eventDate.toLocal();
}

DateTime _newestRecordDate(List<HistoryRecord> records) {
  if (records.isEmpty) {
    return DateTime.now();
  }

  return records.first.eventDate.toLocal();
}

IconData _iconFor(HistoryRecordType type) {
  switch (type) {
    case HistoryRecordType.behavior:
      return Icons.psychology_alt_outlined;

    case HistoryRecordType.sleep:
      return Icons.bedtime_outlined;

    case HistoryRecordType.feeding:
      return Icons.restaurant_outlined;

    case HistoryRecordType.socialInteraction:
      return Icons.groups_outlined;

    case HistoryRecordType.dysregulation:
      return Icons.sentiment_dissatisfied_outlined;

    case HistoryRecordType.atypicalSituation:
      return Icons.event_note_outlined;

    case HistoryRecordType.routineStatus:
      return Icons.event_available_outlined;
  }
}

Color _accentColorFor(HistoryRecordType type) {
  switch (type) {
    case HistoryRecordType.behavior:
      return const Color(0xFFE56F61);

    case HistoryRecordType.sleep:
      return const Color(0xFF78AFC1);

    case HistoryRecordType.feeding:
      return const Color(0xFFC9A353);

    case HistoryRecordType.socialInteraction:
      return const Color(0xFF69AA98);

    case HistoryRecordType.dysregulation:
      return const Color(0xFF8173AE);

    case HistoryRecordType.atypicalSituation:
      return const Color(0xFF9B8564);

    case HistoryRecordType.routineStatus:
      return const Color(0xFF5DAE98);
  }
}

String _formatEventDate(DateTime value) {
  final local = value.toLocal();

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

  return '${local.day.toString().padLeft(2, '0')} '
      '${months[local.month - 1]} '
      '${local.year}';
}
