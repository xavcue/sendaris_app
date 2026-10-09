import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/models/dysregulation_record.dart';
import '../../domain/repositories/dysregulation_management_repository.dart';
import '../viewmodels/dysregulation_management_view_model.dart';

class DysregulationManagementView extends StatelessWidget {
  const DysregulationManagementView({
    required this.repository,
    required this.anonymousId,
    super.key,
  });

  final DysregulationManagementRepository repository;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          DysregulationManagementViewModel(repository, anonymousId: anonymousId)
            ..load(),
      child: const _DysregulationManagementContent(),
    );
  }
}

class _DysregulationManagementContent extends StatefulWidget {
  const _DysregulationManagementContent();

  @override
  State<_DysregulationManagementContent> createState() =>
      _DysregulationManagementContentState();
}

class _DysregulationManagementContentState
    extends State<_DysregulationManagementContent> {
  bool _isFilterExpanded = false;

  void _toggleFilter() {
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DysregulationManagementViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('dysregulation-management-view'),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Desregulación'),
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
    DysregulationManagementViewModel viewModel,
  ) {
    if (viewModel.isLoading && !viewModel.hasLoaded) {
      return ListView(
        key: const Key('dysregulation-management-loading'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          _DysregulationIntro(),
          SizedBox(height: 70),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (viewModel.loadError != null && !viewModel.hasRecords) {
      return ListView(
        key: const Key('dysregulation-management-error'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const _DysregulationIntro(),
          const SizedBox(height: 24),
          _DysregulationErrorState(
            message: viewModel.loadError!,
            onRetry: () async {
              await viewModel.reload();
            },
          ),
        ],
      );
    }

    return ListView(
      key: const Key('dysregulation-management-list'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const _DysregulationIntro(),
        const SizedBox(height: 18),
        _NewRecordButton(
          onPressed: () async {
            await context.push<void>('/events/dysregulation/new');

            if (!context.mounted) {
              return;
            }

            await viewModel.reload();
          },
        ),
        if (viewModel.loadError != null) ...[
          const SizedBox(height: 16),
          _InlineError(message: viewModel.loadError!),
        ],
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: KeyedSubtree(
            key: const Key('dysregulation-filter-toggle-button'),
            child: FilledButton.tonalIcon(
              key: const Key('dysregulation-filter-toggle'),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
        ),
        if (_isFilterExpanded) ...[
          const SizedBox(height: 14),
          _DysregulationDateFilterCard(viewModel: viewModel),
        ],
        const SizedBox(height: 26),
        _ResultsHeader(
          visibleCount: viewModel.recordCount,
          totalCount: viewModel.totalRecordCount,
          hasFilter: viewModel.hasAppliedDateFilter,
        ),
        const SizedBox(height: 12),
        if (viewModel.isEmpty)
          const _DysregulationEmptyState()
        else if (viewModel.hasNoFilterResults)
          _NoFilterResults(onClear: viewModel.clearDateFilter)
        else
          for (final record in viewModel.records)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DysregulationRecordCard(
                record: record,
                isDeleting: viewModel.isDeleting(record.recordId),
                onOpen: () async {
                  await context.push<void>(
                    '/events/dysregulation/detail',
                    extra: record,
                  );
                },
                onEdit: () async {
                  final changed = await context.push<bool>(
                    '/events/dysregulation/edit',
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
    DysregulationManagementViewModel viewModel,
    DysregulationRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¿Eliminar evento?'),
          content: const Text(
            'Este registro se eliminará definitivamente '
            'y dejará de formar parte de los indicadores '
            'calculados con estos datos. '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              key: const Key('cancel-delete-dysregulation'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirm-delete-dysregulation'),
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

    final success = await viewModel.deleteDysregulation(record);

    if (!context.mounted) {
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

    final message =
        viewModel.actionError ??
        'No fue posible eliminar el registro de desregulación. '
            'Inténtalo nuevamente.';

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

class _DysregulationIntro extends StatelessWidget {
  const _DysregulationIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestión de registros de desregulación',
          key: const Key('dysregulation-management-title'),
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 7),
        Text(
          'Consulta y administra los registros de desregulación.',
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

class _NewRecordButton extends StatelessWidget {
  const _NewRecordButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        key: const Key('dysregulation-new-record-button'),
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo registro'),
      ),
    );
  }
}

class _DysregulationDateFilterCard extends StatelessWidget {
  const _DysregulationDateFilterCard({required this.viewModel});

  final DysregulationManagementViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasFilter =
        viewModel.hasPendingDateFilter || viewModel.hasAppliedDateFilter;

    return Card(
      key: const Key('dysregulation-date-filter-card'),
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
              'Filtra los registros de desregulación '
              'por la fecha registrada.',
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
                    key: const Key('dysregulation-start-date-button'),
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
                    key: const Key('dysregulation-end-date-button'),
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
            if (viewModel.filterError != null) ...[
              const SizedBox(height: 10),
              Row(
                key: const Key('dysregulation-date-filter-error'),
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
                if (hasFilter) ...[
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('dysregulation-clear-date-filter'),
                      onPressed: viewModel.clearDateFilter,
                      child: const Text('Quitar filtro'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    key: const Key('dysregulation-apply-date-filter'),
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
            'Desregulación',
            key: const Key('dysregulation-results-title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          key: const Key('dysregulation-record-count'),
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

class _DysregulationRecordCard extends StatelessWidget {
  const _DysregulationRecordCard({
    required this.record,
    required this.isDeleting,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final DysregulationRecord record;
  final bool isDeleting;

  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: Key('dysregulation-record-${record.recordId}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('dysregulation-open-${record.recordId}'),
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
                  color: colorScheme.primary.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.20 : 0.12,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.sentiment_dissatisfied_outlined,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Episodio de desregulación',
                      key: Key('dysregulation-record-title-${record.recordId}'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _formatRecordDateTime(record),
                      key: Key('dysregulation-record-date-${record.recordId}'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (record.durationMinutes != null ||
                        record.intensity != null) ...[
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 7,
                        runSpacing: 6,
                        children: [
                          if (record.durationMinutes != null)
                            _RecordTag(
                              icon: Icons.timer_outlined,
                              label: '${record.durationMinutes} min',
                            ),
                          if (record.intensity != null)
                            _RecordTag(
                              icon: Icons.speed_outlined,
                              label: record.intensity!.label,
                            ),
                        ],
                      ),
                    ],
                    if (record.context != null) ...[
                      const SizedBox(height: 9),
                      Text(
                        'Contexto: ${record.context}',
                        key: Key(
                          'dysregulation-record-context-${record.recordId}',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (record.observation != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Observación: ${record.observation}',
                        key: Key(
                          'dysregulation-record-observation-${record.recordId}',
                        ),
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
                PopupMenuButton<_DysregulationAction>(
                  key: Key('dysregulation-menu-${record.recordId}'),
                  tooltip: 'Opciones de desregulación',
                  onSelected: (action) {
                    switch (action) {
                      case _DysregulationAction.edit:
                        onEdit();

                      case _DysregulationAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem(
                        value: _DysregulationAction.edit,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _DysregulationAction.delete,
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

class _RecordTag extends StatelessWidget {
  const _RecordTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DysregulationEmptyState extends StatelessWidget {
  const _DysregulationEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: const Key('dysregulation-empty-state'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
        child: Column(
          children: [
            Icon(
              Icons.event_note_outlined,
              size: 42,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 13),
            Text(
              'Aún no hay registros de desregulación',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Los registros que añadas aparecerán aquí.',
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
      key: const Key('dysregulation-no-filter-results'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          children: [
            Icon(
              Icons.filter_alt_off_outlined,
              size: 40,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No hay registros en este periodo',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Prueba con otro periodo o quita el filtro aplicado.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const Key('dysregulation-no-results-clear-filter'),
              onPressed: onClear,
              child: const Text('Quitar filtro'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DysregulationErrorState extends StatelessWidget {
  const _DysregulationErrorState({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: colorScheme.error,
            ),
            const SizedBox(height: 13),
            Text(
              'No fue posible cargar los registros',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
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
            const SizedBox(height: 17),
            FilledButton.tonalIcon(
              key: const Key('dysregulation-retry-button'),
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
        color: colorScheme.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 9),
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

enum _DysregulationAction { edit, delete }

Future<DateTime?> _pickDate(
  BuildContext context, {
  required String title,
  required DateTime initialDate,
}) {
  final now = DateTime.now();

  return showDatePicker(
    context: context,
    helpText: title,
    initialDate: initialDate,
    firstDate: DateTime(1900),
    lastDate: DateTime(now.year + 10, 12, 31),
    cancelText: 'Cancelar',
    confirmText: 'Seleccionar',
  );
}

DateTime _oldestDate(List<DysregulationRecord> records) {
  if (records.isEmpty) {
    return DateTime.now();
  }

  DateTime oldest = records.first.date;

  for (final record in records.skip(1)) {
    if (record.date.isBefore(oldest)) {
      oldest = record.date;
    }
  }

  return oldest;
}

DateTime _newestDate(List<DysregulationRecord> records) {
  if (records.isEmpty) {
    return DateTime.now();
  }

  DateTime newest = records.first.date;

  for (final record in records.skip(1)) {
    if (record.date.isAfter(newest)) {
      newest = record.date;
    }
  }

  return newest;
}

String _formatRecordDateTime(DysregulationRecord record) {
  final date = _formatDate(record.date);

  final time = record.time;

  if (time == null) {
    return '$date · Sin hora';
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
