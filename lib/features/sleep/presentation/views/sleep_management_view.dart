import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../domain/models/sleep_record.dart';
import '../../domain/repositories/sleep_management_repository.dart';
import '../viewmodels/sleep_management_view_model.dart';

class SleepManagementView extends StatelessWidget {
  const SleepManagementView({
    required this.repository,
    required this.anonymousId,
    super.key,
  });

  final SleepManagementRepository repository;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          SleepManagementViewModel(repository, anonymousId: anonymousId)
            ..load(),
      child: const _SleepManagementContent(),
    );
  }
}

class _SleepManagementContent extends StatefulWidget {
  const _SleepManagementContent();

  @override
  State<_SleepManagementContent> createState() =>
      _SleepManagementContentState();
}

class _SleepManagementContentState extends State<_SleepManagementContent> {
  bool? _wasTickerEnabled;
  bool _automaticRefreshScheduled = false;

  bool _isFilterExpanded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final tickerEnabled = TickerMode.valuesOf(context).enabled;
    final wasTickerEnabled = _wasTickerEnabled;

    _wasTickerEnabled = tickerEnabled;

    if (wasTickerEnabled != false ||
        !tickerEnabled ||
        _automaticRefreshScheduled) {
      return;
    }

    _automaticRefreshScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      try {
        await context.read<SleepManagementViewModel>().reload();
      } finally {
        if (mounted) {
          _automaticRefreshScheduled = false;
        }
      }
    });
  }

  void _toggleFilter() {
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
    });
  }

  Future<void> _pickStartDate(SleepManagementViewModel viewModel) async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate:
          viewModel.pendingStartDate ?? viewModel.appliedStartDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      helpText: 'Seleccionar fecha inicial',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (selected != null) {
      viewModel.setPendingStartDate(selected);
    }
  }

  Future<void> _pickEndDate(SleepManagementViewModel viewModel) async {
    final now = DateTime.now();

    final selected = await showDatePicker(
      context: context,
      initialDate: viewModel.pendingEndDate ?? viewModel.appliedEndDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      helpText: 'Seleccionar fecha final',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (selected != null) {
      viewModel.setPendingEndDate(selected);
    }
  }

  Future<void> _openNew() async {
    await context.push<bool>(AppRoutes.sleepNew);
  }

  Future<void> _openDetail(SleepRecord record) async {
    await context.push<void>(AppRoutes.sleepDetail, extra: record);
  }

  Future<void> _openEdit(SleepRecord record) async {
    await context.push<bool>(AppRoutes.sleepEdit, extra: record);
  }

  Future<void> _deleteSleep(SleepRecord record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¿Eliminar evento?'),
          content: const Text(
            'Este registro se eliminará definitivamente '
            'y dejará de formar parte de los indicadores '
            'calculados con estos datos. Esta acción no '
            'se puede deshacer.',
          ),
          actions: [
            TextButton(
              key: const Key('cancel-delete-sleep'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirm-delete-sleep'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Eliminar definitivamente'),
            ),
          ],
        );
      },
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final viewModel = context.read<SleepManagementViewModel>();

    final success = await viewModel.deleteSleep(record);

    if (!mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Evento eliminado correctamente.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );

      return;
    }

    final message = viewModel.actionError;

    if (message != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SleepManagementViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('sleep-management-view'),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Sueño'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
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

  Widget _buildBody(BuildContext context, SleepManagementViewModel viewModel) {
    if (viewModel.isLoading && !viewModel.hasLoaded) {
      return ListView(
        key: const Key('sleep-management-loading'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: const [
          _SleepIntro(),
          SizedBox(height: 72),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (viewModel.loadError != null && !viewModel.hasLoaded) {
      return ListView(
        key: const Key('sleep-management-error'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        children: [
          const _SleepIntro(),
          const SizedBox(height: 24),
          _LoadErrorCard(
            message: viewModel.loadError!,
            onRetry: () {
              viewModel.reload();
            },
          ),
        ],
      );
    }

    return ListView(
      key: const Key('sleep-management-list'),
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      children: [
        const _SleepIntro(),
        if (viewModel.loadError != null) ...[
          const SizedBox(height: 16),
          _InlineError(message: viewModel.loadError!),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('sleep-new-button'),
            onPressed: viewModel.isLoading ? null : _openNew,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo registro'),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            key: const Key('sleep-filter-toggle-button'),
            onPressed: _toggleFilter,
            icon: const Icon(Icons.filter_alt_outlined, size: 19),
            label: Text(
              _isFilterExpanded
                  ? 'Ocultar filtro'
                  : viewModel.hasAppliedDateFilter
                  ? 'Filtro activo'
                  : 'Filtrar',
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
        if (_isFilterExpanded) ...[
          const SizedBox(height: 14),
          _DateFilterCard(
            viewModel: viewModel,
            onPickStartDate: () {
              _pickStartDate(viewModel);
            },
            onPickEndDate: () {
              _pickEndDate(viewModel);
            },
          ),
        ],
        const SizedBox(height: 26),
        _ResultsHeader(
          visibleCount: viewModel.recordCount,
          totalCount: viewModel.totalRecordCount,
          hasFilter: viewModel.hasAppliedDateFilter,
        ),
        const SizedBox(height: 12),
        if (viewModel.records.isEmpty)
          viewModel.hasAppliedDateFilter
              ? _NoFilterResults(onClear: viewModel.clearDateFilter)
              : const _EmptyState()
        else ...[
          for (final record in viewModel.records) ...[
            _SleepRecordCard(
              record: record,
              deleting: viewModel.isDeleting(record.recordId),
              onOpen: () {
                _openDetail(record);
              },
              onEdit: () {
                _openEdit(record);
              },
              onDelete: () {
                _deleteSleep(record);
              },
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _SleepIntro extends StatelessWidget {
  const _SleepIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      key: const Key('sleep-management-title'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestión de registros de sueño',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          'Consulta y administra los registros de sueño.',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Puedes crear, consultar, editar o eliminar '
          'los registros del seguimiento actual.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _DateFilterCard extends StatelessWidget {
  const _DateFilterCard({
    required this.viewModel,
    required this.onPickStartDate,
    required this.onPickEndDate,
  });

  final SleepManagementViewModel viewModel;

  final VoidCallback onPickStartDate;
  final VoidCallback onPickEndDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: const Key('sleep-date-filter-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.date_range_outlined,
                  size: 21,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 9),
                Text(
                  'Periodo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              'Filtra los registros por la fecha '
              'en que inició el periodo de sueño.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DateFilterButton(
                    key: const Key('sleep-start-date-button'),
                    label: 'Desde',
                    value: viewModel.pendingStartDate == null
                        ? 'Sin seleccionar'
                        : _formatDate(viewModel.pendingStartDate!),
                    onPressed: viewModel.isLoading ? null : onPickStartDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateFilterButton(
                    key: const Key('sleep-end-date-button'),
                    label: 'Hasta',
                    value: viewModel.pendingEndDate == null
                        ? 'Sin seleccionar'
                        : _formatDate(viewModel.pendingEndDate!),
                    onPressed: viewModel.isLoading ? null : onPickEndDate,
                  ),
                ),
              ],
            ),
            if (viewModel.filterError != null) ...[
              const SizedBox(height: 10),
              Row(
                key: const Key('sleep-date-filter-error'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.error_outline_rounded,
                    size: 18,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      viewModel.filterError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (viewModel.hasPendingDateFilter ||
                    viewModel.hasAppliedDateFilter) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('sleep-clear-date-filter'),
                      onPressed: viewModel.clearDateFilter,
                      child: const Text('Quitar filtro'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    key: const Key('sleep-apply-date-filter'),
                    onPressed: () {
                      viewModel.applyDateFilter();
                    },
                    child: const Text('Aplicar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({
    required this.label,
    required this.value,
    required this.onPressed,
    super.key,
  });

  final String label;
  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
    required this.visibleCount,
    required this.totalCount,
    required this.hasFilter,
  });

  final int visibleCount;
  final int totalCount;
  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Sueño',
            key: const Key('sleep-results-title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          key: const Key('sleep-record-count'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            hasFilter ? '$visibleCount de $totalCount' : '$totalCount',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SleepRecordCard extends StatelessWidget {
  const _SleepRecordCard({
    required this.record,
    required this.deleting,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final SleepRecord record;
  final bool deleting;

  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const accentColor = Color(0xFF78AFC1);

    return Card(
      key: Key('sleep-record-${record.recordId}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('sleep-open-${record.recordId}'),
        onTap: deleting ? null : onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accentColor.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.20 : 0.14,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.bedtime_outlined,
                  color: theme.brightness == Brightness.dark
                      ? Color.lerp(accentColor, Colors.white, 0.25)
                      : accentColor,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${record.startTime} – ${record.endTime}',
                      key: Key('sleep-record-title-${record.recordId}'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatSleepDatePeriod(record),
                      key: Key('sleep-record-date-${record.recordId}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 15,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _formatDuration(record.durationMinutes),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    if (record.observation != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        record.observation!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (deleting)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<_SleepRecordAction>(
                  key: Key('sleep-menu-${record.recordId}'),
                  tooltip: 'Opciones',
                  onSelected: (action) {
                    switch (action) {
                      case _SleepRecordAction.edit:
                        onEdit();

                      case _SleepRecordAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) {
                    final menuTheme = Theme.of(context);

                    return [
                      const PopupMenuItem(
                        value: _SleepRecordAction.edit,
                        child: Row(
                          children: [
                            Icon(Icons.edit_outlined, size: 20),
                            SizedBox(width: 10),
                            Text('Editar'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: _SleepRecordAction.delete,
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              size: 20,
                              color: menuTheme.colorScheme.error,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Eliminar',
                              style: TextStyle(
                                color: menuTheme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ];
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _SleepRecordAction { edit, delete }

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: const Key('sleep-empty-state'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.bedtime_outlined,
              size: 38,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Aún no hay registros de sueño',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Los nuevos registros de sueño aparecerán aquí.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoFilterResults extends StatelessWidget {
  const _NoFilterResults({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: const Key('sleep-no-filter-results'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 36,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            Text(
              'No hay registros en este periodo',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Prueba con otro periodo o quita el filtro.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              key: const Key('sleep-clear-empty-filter'),
              onPressed: onClear,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Quitar filtro'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadErrorCard extends StatelessWidget {
  const _LoadErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 36,
              color: colorScheme.error,
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              key: const Key('sleep-retry-button'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.68),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 9),
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

String _formatSleepDatePeriod(SleepRecord record) {
  final startDate = record.date;
  final endDateTime = record.endDateTime;

  final endDate = DateTime(
    endDateTime.year,
    endDateTime.month,
    endDateTime.day,
  );

  final isSameDate =
      startDate.year == endDate.year &&
      startDate.month == endDate.month &&
      startDate.day == endDate.day;

  final formattedStart = _formatDate(startDate);

  if (isSameDate) {
    return formattedStart;
  }

  return '$formattedStart – ${_formatDate(endDate)}';
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

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;

  if (hours == 0) {
    return '$remainingMinutes min';
  }

  if (remainingMinutes == 0) {
    return '$hours h';
  }

  return '$hours h $remainingMinutes min';
}
