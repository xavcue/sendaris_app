import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../../routine/domain/repositories/routine_repository.dart';
import '../../domain/models/routine_status.dart';
import '../../domain/models/routine_status_record.dart';
import '../../domain/repositories/routine_status_management_repository.dart';
import '../viewmodels/routine_status_management_view_model.dart';

class RoutineStatusManagementView extends StatelessWidget {
  const RoutineStatusManagementView({
    required this.repository,
    required this.routineRepository,
    required this.anonymousId,
    super.key,
  });

  final RoutineStatusManagementRepository repository;
  final RoutineRepository routineRepository;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RoutineStatusManagementViewModel(
        repository,
        routineRepository,
        anonymousId: anonymousId,
      )..initialize(),
      child: const _RoutineStatusManagementContent(),
    );
  }
}

class _RoutineStatusManagementContent extends StatefulWidget {
  const _RoutineStatusManagementContent();

  @override
  State<_RoutineStatusManagementContent> createState() =>
      _RoutineStatusManagementContentState();
}

class _RoutineStatusManagementContentState
    extends State<_RoutineStatusManagementContent> {
  final TextEditingController _routineSearchController =
      TextEditingController();

  bool _isFilterExpanded = false;

  @override
  void dispose() {
    _routineSearchController.dispose();

    super.dispose();
  }

  void _toggleFilter() {
    setState(() {
      _isFilterExpanded = !_isFilterExpanded;
    });
  }

  void _selectRoutine(
    RoutineStatusManagementViewModel viewModel,
    String routineId,
  ) {
    viewModel.selectRoutineGroup(routineId);

    if (_isFilterExpanded) {
      setState(() {
        _isFilterExpanded = false;
      });
    }
  }

  void _backToRoutineGroups(RoutineStatusManagementViewModel viewModel) {
    viewModel.clearSelectedRoutine();

    if (_isFilterExpanded) {
      setState(() {
        _isFilterExpanded = false;
      });
    }
  }

  void _clearRoutineSearch(RoutineStatusManagementViewModel viewModel) {
    _routineSearchController.clear();

    viewModel.clearRoutineSearch();

    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _openNew(RoutineStatusManagementViewModel viewModel) async {
    await context.push<void>(AppRoutes.routineStatusNew);

    if (mounted) {
      await viewModel.reload();
    }
  }

  Future<void> _openDetail(RoutineStatusManagementItem item) async {
    await context.push<void>(AppRoutes.routineStatusDetail, extra: item.record);
  }

  Future<void> _openEdit(
    RoutineStatusManagementViewModel viewModel,
    RoutineStatusManagementItem item,
  ) async {
    await context.push<void>(AppRoutes.routineStatusEdit, extra: item.record);

    if (mounted) {
      await viewModel.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RoutineStatusManagementViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopScope<void>(
      canPop: !viewModel.hasSelectedRoutine,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || !viewModel.hasSelectedRoutine) {
          return;
        }

        _backToRoutineGroups(viewModel);
      },
      child: Scaffold(
        key: const Key('routine-status-management-view'),
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Estado de rutina'),
          leading: viewModel.hasSelectedRoutine
              ? IconButton(
                  key: const Key('routine-status-context-back-button'),
                  tooltip: 'Volver a rutinas con estados',
                  onPressed: () {
                    _backToRoutineGroups(viewModel);
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                )
              : null,
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
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    RoutineStatusManagementViewModel viewModel,
  ) {
    if (viewModel.isLoading && !viewModel.hasLoaded) {
      return ListView(
        key: const Key('routine-status-management-loading'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          _RoutineStatusIntro(),
          SizedBox(height: 70),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (viewModel.errorMessage != null && !viewModel.hasRecords) {
      return ListView(
        key: const Key('routine-status-management-error'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const _RoutineStatusIntro(),
          const SizedBox(height: 24),
          _RoutineStatusErrorState(
            message: viewModel.errorMessage!,
            onRetry: viewModel.reload,
          ),
        ],
      );
    }

    if (viewModel.hasSelectedRoutine) {
      return _buildSelectedRoutine(context, viewModel);
    }

    return _buildRoutineGroups(context, viewModel);
  }

  Widget _buildRoutineGroups(
    BuildContext context,
    RoutineStatusManagementViewModel viewModel,
  ) {
    return ListView(
      key: const Key('routine-status-management-list'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const _RoutineStatusIntro(),
        if (viewModel.errorMessage != null) ...[
          const SizedBox(height: 16),
          _InlineError(message: viewModel.errorMessage!),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('routine-status-new-button'),
            onPressed: viewModel.isLoading
                ? null
                : () {
                    _openNew(viewModel);
                  },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Registrar estado de rutina'),
          ),
        ),
        const SizedBox(height: 28),
        _RoutineGroupsHeader(
          visibleCount: viewModel.searchedRoutineGroupCount,
          totalCount: viewModel.routineGroupCount,
          hasSearch: viewModel.hasRoutineSearchQuery,
        ),
        const SizedBox(height: 8),
        const _RoutineGroupsExplanation(),
        if (!viewModel.isEmpty) ...[
          const SizedBox(height: 16),
          _RoutineSearchField(
            controller: _routineSearchController,
            hasQuery: viewModel.hasRoutineSearchQuery,
            onChanged: viewModel.setRoutineSearchQuery,
            onClear: () {
              _clearRoutineSearch(viewModel);
            },
          ),
        ],
        const SizedBox(height: 16),
        if (viewModel.isEmpty)
          const _RoutineStatusEmptyState()
        else if (viewModel.hasNoRoutineSearchResults)
          _NoRoutineSearchResults(
            query: viewModel.routineSearchQuery,
            onClear: () {
              _clearRoutineSearch(viewModel);
            },
          )
        else
          for (final group in viewModel.searchedRoutineGroups)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RoutineGroupCard(
                group: group,
                onTap: () {
                  _selectRoutine(viewModel, group.routineId);
                },
              ),
            ),
      ],
    );
  }

  Widget _buildSelectedRoutine(
    BuildContext context,
    RoutineStatusManagementViewModel viewModel,
  ) {
    final group = viewModel.selectedRoutineGroup;

    if (group == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        viewModel.clearSelectedRoutine();
      });

      return const SizedBox.shrink();
    }

    return ListView(
      key: const Key('routine-status-selected-routine-list'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _SelectedRoutineHeader(group: group),
        if (viewModel.errorMessage != null) ...[
          const SizedBox(height: 16),
          _InlineError(message: viewModel.errorMessage!),
        ],
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            key: const Key('routine-status-filter-toggle-button'),
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
          _RoutineStatusDateFilterCard(
            viewModel: viewModel,
            records: group.items
                .map((item) => item.record)
                .toList(growable: false),
          ),
        ],
        const SizedBox(height: 26),
        _ResultsHeader(
          visibleCount: viewModel.filteredSelectedRoutineRecordCount,
          totalCount: group.recordCount,
          hasFilter: viewModel.hasActiveDateFilter,
        ),
        const SizedBox(height: 12),
        if (viewModel.hasNoSelectedRoutineFilterResults)
          _NoFilterResults(onClear: viewModel.clearDateFilter)
        else
          for (final item in viewModel.filteredSelectedRoutineItems)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RoutineStatusRecordCard(
                item: item,
                isDeleting: viewModel.isDeleting(item.record.recordId),
                onOpen: () {
                  _openDetail(item);
                },
                onEdit: () {
                  _openEdit(viewModel, item);
                },
                onDelete: () async {
                  await _confirmDelete(context, viewModel, item.record);
                },
              ),
            ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RoutineStatusManagementViewModel viewModel,
    RoutineStatusRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¿Eliminar estado de rutina?'),
          content: const Text(
            'Este estado se eliminará definitivamente y dejará de formar '
            'parte de las métricas de rutinas calculadas con estos datos. '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              key: const Key('cancel-delete-routine-status'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirm-delete-routine-status'),
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

    final success = await viewModel.deleteRoutineStatus(record);

    if (!context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Estado de rutina eliminado correctamente.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );

      return;
    }

    final message =
        viewModel.actionErrorMessage ??
        'No fue posible eliminar el estado de la rutina. '
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

class _RoutineStatusIntro extends StatelessWidget {
  const _RoutineStatusIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestión de estados de rutina',
          key: const Key('routine-status-management-title'),
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 7),
        Text(
          'Consulta los estados registrados organizados por rutina.',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Selecciona una rutina para revisar sus registros, '
          'consultarlos, editarlos o eliminarlos.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _RoutineGroupsHeader extends StatelessWidget {
  const _RoutineGroupsHeader({
    required this.visibleCount,
    required this.totalCount,
    required this.hasSearch,
  });

  final int visibleCount;
  final int totalCount;
  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Rutinas con estados',
            key: const Key('routine-status-routines-title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          key: const Key('routine-status-routine-count'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            hasSearch ? '$visibleCount de $totalCount' : '$totalCount',
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

class _RoutineGroupsExplanation extends StatelessWidget {
  const _RoutineGroupsExplanation();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Text(
      'Cada tarjeta reúne todos los estados registrados para una misma rutina.',
      style: theme.textTheme.bodySmall?.copyWith(
        color: colorScheme.onSurfaceVariant,
        height: 1.35,
      ),
    );
  }
}

class _RoutineSearchField extends StatelessWidget {
  const _RoutineSearchField({
    required this.controller,
    required this.hasQuery,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool hasQuery;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return TextField(
      key: const Key('routine-status-routine-search-field'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      decoration: InputDecoration(
        hintText: 'Buscar rutina por nombre',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: hasQuery
            ? IconButton(
                key: const Key('routine-status-clear-routine-search'),
                tooltip: 'Limpiar búsqueda',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              )
            : null,
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _NoRoutineSearchResults extends StatelessWidget {
  const _NoRoutineSearchResults({required this.query, required this.onClear});

  final String query;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final normalizedQuery = query.trim();

    return Card(
      key: const Key('routine-status-no-routine-search-results'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
        child: Column(
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 42,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'No se encontraron rutinas',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'No hay rutinas que coincidan con '
              '“$normalizedQuery”.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            TextButton.icon(
              key: const Key('routine-status-clear-empty-search'),
              onPressed: onClear,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text('Limpiar búsqueda'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineGroupCard extends StatelessWidget {
  const _RoutineGroupCard({required this.group, required this.onTap});

  final RoutineStatusRoutineGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final latest = group.latestRecord;

    final recordLabel = group.recordCount == 1
        ? '1 estado registrado'
        : '${group.recordCount} estados registrados';

    return Card(
      key: Key(
        'routine-status-routine-group-'
        '${group.routineId}',
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key(
          'routine-status-open-routine-'
          '${group.routineId}',
        ),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(
                  Icons.view_timeline_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.routineName,
                      key: Key(
                        'routine-status-routine-name-'
                        '${group.routineId}',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recordLabel,
                      key: Key(
                        'routine-status-routine-record-count-'
                        '${group.routineId}',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Flexible(child: _StatusBadge(status: latest.status)),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            'Último: '
                            '${_formatDate(latest.date)}',
                            key: Key(
                              'routine-status-routine-latest-'
                              '${group.routineId}',
                            ),
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedRoutineHeader extends StatelessWidget {
  const _SelectedRoutineHeader({required this.group});

  final RoutineStatusRoutineGroup group;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final recordLabel = group.recordCount == 1
        ? '1 estado registrado'
        : '${group.recordCount} estados registrados';

    return Container(
      key: const Key('routine-status-selected-routine'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.fact_check_outlined,
              color: colorScheme.onPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estados de la rutina',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  group.routineName,
                  key: const Key('routine-status-selected-routine-name'),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  recordLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
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

class _RoutineStatusDateFilterCard extends StatelessWidget {
  const _RoutineStatusDateFilterCard({
    required this.viewModel,
    required this.records,
  });

  final RoutineStatusManagementViewModel viewModel;

  final List<RoutineStatusRecord> records;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasFilter =
        viewModel.hasActiveDateFilter || viewModel.hasPendingDateFilter;

    return Card(
      key: const Key('routine-status-date-filter-card'),
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
              'Filtra los estados de esta rutina por la fecha registrada.',
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
                    key: const Key('routine-status-start-date-button'),
                    label: 'Desde',
                    value: viewModel.pendingStartDate,
                    onTap: () async {
                      final selected = await _pickDate(
                        context,
                        title: 'Fecha inicial',
                        initialDate:
                            viewModel.pendingStartDate ?? _oldestDate(records),
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
                    key: const Key('routine-status-end-date-button'),
                    label: 'Hasta',
                    value: viewModel.pendingEndDate,
                    onTap: () async {
                      final selected = await _pickDate(
                        context,
                        title: 'Fecha final',
                        initialDate:
                            viewModel.pendingEndDate ?? _newestDate(records),
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
                key: const Key('routine-status-date-filter-error'),
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
                      key: const Key('routine-status-clear-date-filter'),
                      onPressed: viewModel.clearDateFilter,
                      child: const Text('Quitar filtro'),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: FilledButton(
                    key: const Key('routine-status-apply-date-filter'),
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
            'Estados registrados',
            key: const Key('routine-status-results-title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Container(
          key: const Key('routine-status-record-count'),
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

class _RoutineStatusRecordCard extends StatelessWidget {
  const _RoutineStatusRecordCard({
    required this.item,
    required this.isDeleting,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final RoutineStatusManagementItem item;
  final bool isDeleting;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final record = item.record;

    final observation = _normalizedObservation(record.observation);

    return Card(
      key: Key(
        'routine-status-record-'
        '${record.recordId}',
      ),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key(
          'routine-status-open-'
          '${record.recordId}',
        ),
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
                  color: colorScheme.primaryContainer.withValues(alpha: 0.62),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.event_available_outlined,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(record.date),
                      key: Key(
                        'routine-status-record-date-'
                        '${record.recordId}',
                      ),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 9),
                    _StatusBadge(status: record.status),
                    if (observation != null) ...[
                      const SizedBox(height: 9),
                      Text(
                        'Observación: '
                        '$observation',
                        key: Key(
                          'routine-status-record-observation-'
                          '${record.recordId}',
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
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
                PopupMenuButton<_RoutineStatusAction>(
                  key: Key(
                    'routine-status-menu-'
                    '${record.recordId}',
                  ),
                  tooltip: 'Opciones del estado de rutina',
                  onSelected: (action) {
                    switch (action) {
                      case _RoutineStatusAction.edit:
                        onEdit();

                      case _RoutineStatusAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem(
                        value: _RoutineStatusAction.edit,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _RoutineStatusAction.delete,
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final RoutineStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status.label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

enum _RoutineStatusAction { edit, delete }

class _RoutineStatusEmptyState extends StatelessWidget {
  const _RoutineStatusEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: const Key('routine-status-empty-state'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          children: [
            Icon(
              Icons.view_timeline_outlined,
              size: 42,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'Aún no hay estados de rutina',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Cuando registres estados, las rutinas aparecerán agrupadas aquí.',
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
      key: const Key('routine-status-no-filter-results'),
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
              'No hay estados de esta rutina en este periodo',
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

class _RoutineStatusErrorState extends StatelessWidget {
  const _RoutineStatusErrorState({
    required this.message,
    required this.onRetry,
  });

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
              'No pudimos cargar los estados de rutina',
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
              key: const Key('routine-status-retry-button'),
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

String? _normalizedObservation(String? value) {
  final normalized = value?.trim();

  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
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

DateTime _oldestDate(List<RoutineStatusRecord> records) {
  if (records.isEmpty) {
    return DateTime.now();
  }

  var oldest = records.first.date;

  for (final record in records.skip(1)) {
    if (record.date.isBefore(oldest)) {
      oldest = record.date;
    }
  }

  return oldest;
}

DateTime _newestDate(List<RoutineStatusRecord> records) {
  if (records.isEmpty) {
    return DateTime.now();
  }

  var newest = records.first.date;

  for (final record in records.skip(1)) {
    if (record.date.isAfter(newest)) {
      newest = record.date;
    }
  }

  return newest;
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
    confirmText: 'Seleccionar',
  );
}
