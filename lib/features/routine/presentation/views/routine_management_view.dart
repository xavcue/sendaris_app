import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/router/app_routes.dart';
import '../../domain/models/routine.dart';
import '../../domain/repositories/routine_repository.dart';
import '../viewmodels/routine_management_view_model.dart';

class RoutineManagementView extends StatelessWidget {
  const RoutineManagementView({
    required this.repository,
    required this.anonymousId,
    super.key,
  });

  final RoutineRepository repository;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          RoutineManagementViewModel(repository, anonymousId: anonymousId)
            ..initialize(),
      child: const _RoutineManagementContent(),
    );
  }
}

class _RoutineManagementContent extends StatefulWidget {
  const _RoutineManagementContent();

  @override
  State<_RoutineManagementContent> createState() =>
      _RoutineManagementContentState();
}

class _RoutineManagementContentState extends State<_RoutineManagementContent> {
  final TextEditingController _searchController = TextEditingController();

  String? _deletingRoutineId;

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  Future<void> _openDetail(BuildContext context, Routine routine) async {
    await context.push<void>(AppRoutes.routineDetail, extra: routine);
  }

  Future<void> _openNew(
    BuildContext context,
    RoutineManagementViewModel viewModel,
  ) async {
    final changed = await context.push<bool>(AppRoutes.routineNew);

    if (changed == true && context.mounted) {
      await viewModel.reload();
    }
  }

  Future<void> _openEdit(
    BuildContext context,
    RoutineManagementViewModel viewModel,
    Routine routine,
  ) async {
    final changed = await context.push<bool>(
      AppRoutes.routineEdit,
      extra: routine,
    );

    if (changed == true && context.mounted) {
      await viewModel.reload();
    }
  }

  void _clearSearch(RoutineManagementViewModel viewModel) {
    _searchController.clear();

    viewModel.clearSearch();

    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    RoutineManagementViewModel viewModel,
    Routine routine,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¿Eliminar rutina?'),
          content: Text(
            'Se eliminará “${routine.name}” y todos los estados '
            'registrados para esta rutina. '
            'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              key: const Key('cancel-delete-routine'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirm-delete-routine'),
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

    setState(() {
      _deletingRoutineId = routine.routineId;
    });

    final success = await viewModel.deleteRoutine(routine);

    if (!context.mounted) {
      return;
    }

    setState(() {
      _deletingRoutineId = null;
    });

    final messenger = ScaffoldMessenger.of(context);

    messenger.hideCurrentSnackBar();

    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Rutina eliminada correctamente.'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 3),
        ),
      );

      return;
    }

    final message =
        viewModel.errorMessage ??
        'No fue posible eliminar la rutina. Inténtalo nuevamente.';

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );

    viewModel.clearError();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RoutineManagementViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('routine-management-view'),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Rutinas'),
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
    RoutineManagementViewModel viewModel,
  ) {
    if (viewModel.isLoading && !viewModel.hasRoutines) {
      return ListView(
        key: const Key('routine-management-loading'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          _RoutineIntro(),
          SizedBox(height: 72),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (viewModel.errorMessage != null && !viewModel.hasRoutines) {
      return ListView(
        key: const Key('routine-management-error'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const _RoutineIntro(),
          const SizedBox(height: 24),
          _RoutineErrorState(
            message: viewModel.errorMessage!,
            onRetry: viewModel.reload,
          ),
        ],
      );
    }

    return ListView(
      key: const Key('routine-management-list'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const _RoutineIntro(),
        if (viewModel.errorMessage != null) ...[
          const SizedBox(height: 16),
          _InlineError(message: viewModel.errorMessage!),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('routine-create-button'),
            onPressed: viewModel.isLoading || viewModel.isUpdating
                ? null
                : () {
                    _openNew(context, viewModel);
                  },
            icon: const Icon(Icons.add_rounded),
            label: const Text('Nueva rutina'),
          ),
        ),
        const SizedBox(height: 26),
        _ResultsHeader(
          visibleCount: viewModel.searchedRoutineCount,
          totalCount: viewModel.routines.length,
          hasSearch: viewModel.hasSearchQuery,
        ),
        if (viewModel.hasRoutines) ...[
          const SizedBox(height: 12),
          _RoutineSearchField(
            controller: _searchController,
            hasQuery: viewModel.hasSearchQuery,
            onChanged: viewModel.setSearchQuery,
            onClear: () {
              _clearSearch(viewModel);
            },
          ),
        ],
        const SizedBox(height: 16),
        if (!viewModel.hasRoutines)
          const _RoutineEmptyState()
        else if (viewModel.hasNoSearchResults)
          _NoRoutineSearchResults(
            query: viewModel.searchQuery,
            onClear: () {
              _clearSearch(viewModel);
            },
          )
        else
          for (final routine in viewModel.searchedRoutines)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RoutineCard(
                routine: routine,
                enabled: !viewModel.isUpdating,
                isDeleting: _deletingRoutineId == routine.routineId,
                onOpen: () {
                  _openDetail(context, routine);
                },
                onEdit: () {
                  _openEdit(context, viewModel, routine);
                },
                onDelete: () {
                  _confirmDelete(context, viewModel, routine);
                },
              ),
            ),
      ],
    );
  }
}

class _RoutineIntro extends StatelessWidget {
  const _RoutineIntro();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gestión de rutinas',
          key: const Key('routine-management-title'),
          style: theme.textTheme.headlineMedium,
        ),
        const SizedBox(height: 7),
        Text(
          'Consulta y administra las rutinas registradas.',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Puedes crear, consultar, editar o eliminar '
          'las rutinas del seguimiento actual.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _ResultsHeader extends StatelessWidget {
  const _ResultsHeader({
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
            'Rutinas',
            key: const Key('routine-results-title'),
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          key: const Key('routine-count'),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.62),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            hasSearch ? '$visibleCount de $totalCount' : '$totalCount',
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
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
      key: const Key('routine-search-field'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      autocorrect: false,
      decoration: InputDecoration(
        hintText: 'Buscar rutina por nombre',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: hasQuery
            ? IconButton(
                key: const Key('routine-clear-search'),
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
      key: const Key('routine-no-search-results'),
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
                fontWeight: FontWeight.w700,
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
              key: const Key('routine-clear-empty-search'),
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

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.enabled,
    required this.isDeleting,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final Routine routine;
  final bool enabled;
  final bool isDeleting;

  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const accentColor = Color(0xFF5CB9AA);

    final metadata = <Widget>[];

    final scheduledTime = routine.scheduledTime;

    if (scheduledTime != null) {
      metadata.add(
        _RoutineInfoChip(icon: Icons.schedule_outlined, label: scheduledTime),
      );
    }

    final recurrence = routine.recurrence;

    if (recurrence != null) {
      metadata.add(
        _RoutineInfoChip(
          icon: Icons.repeat_rounded,
          label: _formatRecurrence(recurrence),
        ),
      );
    }

    return Card(
      key: Key('routine-card-${routine.routineId}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('routine-open-${routine.routineId}'),
        onTap: enabled ? onOpen : null,
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
                  Icons.event_repeat_outlined,
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
                      routine.name,
                      key: Key('routine-name-${routine.routineId}'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (routine.description != null) ...[
                      const SizedBox(height: 7),
                      Text(
                        routine.description!,
                        key: Key('routine-description-${routine.routineId}'),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (metadata.isNotEmpty) ...[
                      const SizedBox(height: 11),
                      Wrap(spacing: 8, runSpacing: 7, children: metadata),
                    ],
                  ],
                ),
              ),
              if (isDeleting)
                const Padding(
                  key: Key('routine-delete-progress'),
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                PopupMenuButton<_RoutineAction>(
                  key: Key('routine-menu-${routine.routineId}'),
                  enabled: enabled,
                  tooltip: 'Opciones de rutina',
                  onSelected: (action) {
                    switch (action) {
                      case _RoutineAction.edit:
                        onEdit();

                      case _RoutineAction.delete:
                        onDelete();
                    }
                  },
                  itemBuilder: (context) {
                    return const [
                      PopupMenuItem(
                        value: _RoutineAction.edit,
                        child: ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                        ),
                      ),
                      PopupMenuItem(
                        value: _RoutineAction.delete,
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

enum _RoutineAction { edit, delete }

class _RoutineInfoChip extends StatelessWidget {
  const _RoutineInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineEmptyState extends StatelessWidget {
  const _RoutineEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      key: const Key('routine-empty-state'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
        child: Column(
          children: [
            Icon(
              Icons.event_repeat_outlined,
              size: 42,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              'Aún no hay rutinas',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              'Las nuevas rutinas aparecerán aquí.',
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

class _RoutineErrorState extends StatelessWidget {
  const _RoutineErrorState({required this.message, required this.onRetry});

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
              'No pudimos cargar las rutinas',
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
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('routine-retry-button'),
              onPressed: () async {
                await onRetry();
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

String _formatRecurrence(String value) {
  return switch (value) {
    'diaria' => 'Diaria',
    'semanal' => 'Semanal',
    'mensual' => 'Mensual',
    _ => value,
  };
}
