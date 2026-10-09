import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../domain/models/behavior_record.dart';
import '../../domain/repositories/behavior_management_repository.dart';
import '../viewmodels/behavior_management_view_model.dart';

class BehaviorManagementView extends StatelessWidget {
  const BehaviorManagementView({
    required this.repository,
    required this.anonymousId,
    super.key,
  });

  final BehaviorManagementRepository repository;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          BehaviorManagementViewModel(repository, anonymousId: anonymousId)
            ..initialize(),
      child: const _BehaviorManagementContent(),
    );
  }
}

class _BehaviorManagementContent extends StatefulWidget {
  const _BehaviorManagementContent();

  @override
  State<_BehaviorManagementContent> createState() =>
      _BehaviorManagementContentState();
}

class _BehaviorManagementContentState
    extends State<_BehaviorManagementContent> {
  bool _isFilterExpanded = false;

  void _toggleFilter() {
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
    });
  }

  Future<void> _openNew(BehaviorManagementViewModel viewModel) async {
    final changed = await context.push<bool>(AppRoutes.behaviorNew);

    if (changed == true && mounted) {
      await viewModel.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BehaviorManagementViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('behavior-management-view'),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Conducta'),
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

  Widget _buildBody(
    BuildContext context,
    BehaviorManagementViewModel viewModel,
  ) {
    if (viewModel.isLoading && !viewModel.hasLoaded) {
      return ListView(
        key: const Key('behavior-management-loading'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          _BehaviorIntro(),
          SizedBox(height: 70),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (viewModel.errorMessage != null && !viewModel.hasRecords) {
      return ListView(
        key: const Key('behavior-management-error'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const _BehaviorIntro(),
          const SizedBox(height: 24),
          _BehaviorErrorState(
            message: viewModel.errorMessage!,
            onRetry: viewModel.reload,
          ),
        ],
      );
    }

    return ListView(
      key: const Key('behavior-management-list'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const _BehaviorIntro(),
        if (viewModel.errorMessage != null) ...[
          const SizedBox(height: 16),
          _InlineError(message: viewModel.errorMessage!),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('behavior-new-button'),
            onPressed: viewModel.isLoading
                ? null
                : () {
                    _openNew(viewModel);
                  },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nuevo registro'),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            key: const Key('behavior-filter-toggle-button'),
            onPressed: _toggleFilter,
            icon: const Icon(Icons.filter_alt_outlined, size: 19),
            label: Text(
              _isFilterExpanded
                  ? 'Ocultar filtro'
                  : viewModel.hasActiveDateFilter
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
          _BehaviorDateFilterCard(viewModel: viewModel),
        ],
        const SizedBox(height: 26),
        _ResultsHeader(
          visibleCount: viewModel.filteredRecordCount,
          totalCount: viewModel.records.length,
          hasFilter: viewModel.hasActiveDateFilter,
        ),
        const SizedBox(height: 12),
        if (viewModel.isEmpty)
          const _BehaviorEmptyState()
        else if (viewModel.hasNoFilterResults)
          _NoFilterResults(onClear: viewModel.clearDateFilter)
        else
          for (final record in viewModel.filteredRecords)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _BehaviorRecordCard(
                record: record,
                isDeleting: viewModel.isDeleting(record.recordId),
                onOpen: () async {
                  await context.push<void>(
                    AppRoutes.behaviorDetail,
                    extra: record,
                  );
                },
                onEdit: () async {
                  final changed = await context.push<bool>(
                    AppRoutes.behaviorEdit,
                    extra: record,
                  );

                  if (changed == true && context.mounted) {
                    await viewModel.reload();
                  }
                },
                onDelete: () async {
                  await _confirmDelete(context, viewModel, record);
                },
              ),
            ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    BehaviorManagementViewModel viewModel,
    BehaviorRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¿Eliminar conducta?'),
          content: const Text(
            'Este registro se eliminará '
            'definitivamente y dejará de formar '
            'parte de los indicadores y reportes '
            'calculados con estos datos. '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              key: const Key('cancel-delete-behavior'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirm-delete-behavior'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Eliminar definitivamente'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final success = await viewModel.deleteBehavior(record);

    if (!context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Conducta eliminada correctamente.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );

      return;
    }

    final message =
        viewModel.actionErrorMessage ?? 'No fue posible eliminar la conducta.';

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );

    viewModel.clearActionError();
  }
}

class _BehaviorIntro extends StatelessWidget {
  const _BehaviorIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestión de registros de conducta',
          key: const Key('behavior-management-title'),
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 7),
        Text(
          'Consulta y administra las conductas registradas.',
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

class _BehaviorDateFilterCard extends StatelessWidget {
  const _BehaviorDateFilterCard({required this.viewModel});

  final BehaviorManagementViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasFilter =
        viewModel.hasActiveDateFilter || viewModel.hasPendingDateFilter;

    return Card(
      key: const Key('behavior-date-filter-card'),
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
              'Filtra las conductas por la fecha registrada.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DateButton(
                    key: const Key('behavior-start-date-button'),
                    label: 'Desde',
                    value: viewModel.pendingStartDate,
                    onTap: () async {
                      final selected = await _pickDate(
                        context,
                        title: 'Fecha inicial',
                        initialDate:
                            viewModel.pendingStartDate ??
                            _oldestDate(viewModel.records),
                      );

                      if (selected != null) {
                        viewModel.setPendingStartDate(selected);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateButton(
                    key: const Key('behavior-end-date-button'),
                    label: 'Hasta',
                    value: viewModel.pendingEndDate,
                    onTap: () async {
                      final selected = await _pickDate(
                        context,
                        title: 'Fecha final',
                        initialDate:
                            viewModel.pendingEndDate ??
                            _newestDate(viewModel.records),
                      );

                      if (selected != null) {
                        viewModel.setPendingEndDate(selected);
                      }
                    },
                  ),
                ),
              ],
            ),
            if (viewModel.filterErrorMessage != null) ...[
              const SizedBox(height: 10),
              Row(
                key: const Key('behavior-date-filter-error'),
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
                      viewModel.filterErrorMessage!,
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
                if (hasFilter) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('behavior-clear-date-filter'),
                      onPressed: viewModel.clearDateFilter,
                      child: const Text('Quitar filtro'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    key: const Key('behavior-apply-date-filter'),
                    onPressed: viewModel.applyDateFilter,
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

class _DateButton extends StatelessWidget {
  const _DateButton({
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

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
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
                value == null ? 'Sin seleccionar' : _formatDate(value!),
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
            'Conductas',
            key: const Key('behavior-results-title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          key: const Key('behavior-record-count'),
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

class _BehaviorRecordCard extends StatelessWidget {
  const _BehaviorRecordCard({
    required this.record,
    required this.isDeleting,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final BehaviorRecord record;
  final bool isDeleting;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const accentColor = Color(0xFFE56F61);

    return Card(
      key: Key('behavior-record-${record.recordId}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('behavior-open-${record.recordId}'),
        onTap: isDeleting ? null : onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
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
                  Icons.psychology_alt_outlined,
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
                      record.category.label,
                      key: Key('behavior-record-title-${record.recordId}'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatRecordDate(record),
                      key: Key('behavior-record-date-${record.recordId}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (_summaryLines(record).isNotEmpty) ...[
                      const SizedBox(height: 10),
                      for (final line in _summaryLines(record))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            line,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              if (isDeleting)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<_BehaviorAction>(
                  key: Key('behavior-menu-${record.recordId}'),
                  tooltip: 'Opciones de conducta',
                  onSelected: (action) {
                    switch (action) {
                      case _BehaviorAction.edit:
                        onEdit();

                      case _BehaviorAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem(
                        value: _BehaviorAction.edit,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _BehaviorAction.delete,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.delete_outline_rounded),
                          title: Text('Eliminar'),
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

enum _BehaviorAction { edit, delete }

class _BehaviorEmptyState extends StatelessWidget {
  const _BehaviorEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: const Key('behavior-empty-state'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          children: [
            Icon(
              Icons.psychology_alt_outlined,
              size: 42,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'Aún no hay conductas',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Los nuevos registros de conducta aparecerán aquí.',
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
      key: const Key('behavior-no-filter-results'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'No hay conductas en este periodo',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
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

class _BehaviorErrorState extends StatelessWidget {
  const _BehaviorErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 24, 30),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: colorScheme.error,
            ),
            const SizedBox(height: 14),
            Text(
              'No pudimos cargar las conductas',
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
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('behavior-retry-button'),
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
        color: colorScheme.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onErrorContainer,
        ),
      ),
    );
  }
}

List<String> _summaryLines(BehaviorRecord record) {
  final lines = <String>[];

  final duration = record.durationMinutes;

  if (duration != null) {
    lines.add('Duración: $duration min');
  }

  final intensity = record.intensity;

  if (intensity != null) {
    lines.add('Intensidad: ${intensity.label}');
  }

  final context = record.context;

  if (context != null) {
    lines.add('Contexto: $context');
  }

  return lines;
}

String _formatRecordDate(BehaviorRecord record) {
  final date = _formatDate(record.date);

  final time = record.time;

  if (time == null) {
    return date;
  }

  return '$date · $time';
}

String _formatDate(DateTime value) {
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

DateTime _oldestDate(List<BehaviorRecord> records) {
  if (records.isEmpty) {
    return DateTime.now();
  }

  return records.last.date;
}

DateTime _newestDate(List<BehaviorRecord> records) {
  if (records.isEmpty) {
    return DateTime.now();
  }

  return records.first.date;
}

Future<DateTime?> _pickDate(
  BuildContext context, {
  required String title,
  required DateTime initialDate,
}) {
  final firstDate = DateTime(2000, 1, 1);

  final lastDate = DateTime(DateTime.now().year + 1, 12, 31);

  var normalized = DateTime(
    initialDate.year,
    initialDate.month,
    initialDate.day,
  );

  if (normalized.isBefore(firstDate)) {
    normalized = firstDate;
  }

  if (normalized.isAfter(lastDate)) {
    normalized = lastDate;
  }

  return showDatePicker(
    context: context,
    initialDate: normalized,
    firstDate: firstDate,
    lastDate: lastDate,
    helpText: title,
    cancelText: 'Cancelar',
    confirmText: 'Aceptar',
  );
}
