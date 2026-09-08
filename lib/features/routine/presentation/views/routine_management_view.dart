import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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

class _RoutineManagementContent extends StatelessWidget {
  const _RoutineManagementContent();

  Future<void> _openCreate(BuildContext context) async {
    final changed = await context.push<bool>('/routines/new');

    if (changed == true && context.mounted) {
      await context.read<RoutineManagementViewModel>().reload();
    }
  }

  Future<void> _openEdit(BuildContext context, Routine routine) async {
    final changed = await context.push<bool>('/routines/edit', extra: routine);

    if (changed == true && context.mounted) {
      await context.read<RoutineManagementViewModel>().reload();
    }
  }

  Future<void> _confirmDeactivate(BuildContext context, Routine routine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.pause_circle_outline),
          title: const Text('Desactivar rutina'),
          content: Text(
            '“${routine.name}” dejará de mostrarse '
            'como rutina activa. Su información '
            'se conservará para que puedas '
            'consultarla más adelante.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('confirm-deactivate-routine'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Desactivar'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final viewModel = context.read<RoutineManagementViewModel>();

    final success = await viewModel.deactivateRoutine(routine);

    if (!context.mounted) {
      return;
    }

    if (success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Rutina desactivada correctamente.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RoutineManagementViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutinas'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            key: const Key('routine-refresh-button'),
            tooltip: 'Actualizar',
            onPressed: viewModel.isLoading ? null : viewModel.reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('routine-create-button'),
        onPressed: viewModel.isUpdating ? null : () => _openCreate(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva rutina'),
      ),
      body: SafeArea(
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
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (viewModel.errorMessage != null && !viewModel.hasRoutines) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _ErrorState(
            message: viewModel.errorMessage!,
            onRetry: viewModel.reload,
          ),
        ],
      );
    }

    if (!viewModel.hasRoutines) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          _RoutineIntroCard(),
          SizedBox(height: 24),
          _EmptyRoutineState(),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const _RoutineIntroCard(),

        const SizedBox(height: 20),

        _RoutineSummary(
          activeCount: viewModel.activeRoutines.length,
          inactiveCount: viewModel.inactiveRoutines.length,
        ),

        if (viewModel.errorMessage != null) ...[
          const SizedBox(height: 16),
          _InlineError(message: viewModel.errorMessage!),
        ],

        const SizedBox(height: 24),

        _SectionTitle(
          title: 'Rutinas activas',
          count: viewModel.activeRoutines.length,
        ),

        const SizedBox(height: 12),

        if (viewModel.activeRoutines.isEmpty)
          const _NoActiveRoutines()
        else
          ...viewModel.activeRoutines.map(
            (routine) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RoutineCard(
                key: Key('routine-card-${routine.routineId}'),
                routine: routine,
                isUpdating: viewModel.isUpdating,
                onEdit: () {
                  _openEdit(context, routine);
                },
                onDeactivate: () {
                  _confirmDeactivate(context, routine);
                },
              ),
            ),
          ),

        if (viewModel.inactiveRoutines.isNotEmpty) ...[
          const SizedBox(height: 16),

          Card(
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              key: const Key('inactive-routines-section'),
              shape: const RoundedRectangleBorder(),
              collapsedShape: const RoundedRectangleBorder(),
              leading: const Icon(Icons.history_rounded),
              title: Text(
                'Rutinas desactivadas '
                '(${viewModel.inactiveRoutines.length})',
              ),
              subtitle: const Text(
                'Puedes consultarlas '
                'más adelante.',
              ),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              children: [
                for (final routine in viewModel.inactiveRoutines)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _RoutineCard(
                      key: Key('routine-card-${routine.routineId}'),
                      routine: routine,
                      isUpdating: false,
                      onEdit: null,
                      onDeactivate: null,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _RoutineIntroCard extends StatelessWidget {
  const _RoutineIntroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('routine-management-intro'),
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
            child: Icon(Icons.checklist_rounded, color: colorScheme.onPrimary),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Organiza las rutinas',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Crea y organiza las '
                  'actividades habituales '
                  'del perfil activo.',
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

class _RoutineSummary extends StatelessWidget {
  const _RoutineSummary({
    required this.activeCount,
    required this.inactiveCount,
  });

  final int activeCount;
  final int inactiveCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            icon: Icons.check_circle_outline,
            label: 'Activas',
            value: activeCount,
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _SummaryCard(
            icon: Icons.history_rounded,
            label: 'Desactivadas',
            value: inactiveCount,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),

            const SizedBox(width: 10),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$value',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Container(
          key: const Key('routine-active-count'),
          constraints: const BoxConstraints(minWidth: 30),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '$count',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.isUpdating,
    required this.onEdit,
    required this.onDeactivate,
    super.key,
  });

  final Routine routine;
  final bool isUpdating;
  final VoidCallback? onEdit;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: routine.isActive
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    routine.isActive
                        ? Icons.event_repeat_rounded
                        : Icons.history_rounded,
                    color: routine.isActive
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        routine.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      _StatusChip(active: routine.isActive),
                    ],
                  ),
                ),

                if (routine.isActive)
                  PopupMenuButton<String>(
                    key: Key('routine-menu-${routine.routineId}'),
                    enabled: !isUpdating,
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          onEdit?.call();
                          break;
                        case 'deactivate':
                          onDeactivate?.call();
                          break;
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Editar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                      PopupMenuItem(
                        value: 'deactivate',
                        child: ListTile(
                          leading: Icon(Icons.pause_circle_outline),
                          title: Text('Desactivar'),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            if (routine.description != null) ...[
              const SizedBox(height: 14),

              Text(
                routine.description!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],

            if (routine.scheduledTime != null ||
                routine.recurrence != null) ...[
              const SizedBox(height: 14),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (routine.scheduledTime != null)
                    _InfoChip(
                      icon: Icons.schedule_outlined,
                      label: routine.scheduledTime!,
                    ),

                  if (routine.recurrence != null)
                    _InfoChip(
                      icon: Icons.repeat_rounded,
                      label: _recurrenceLabel(routine.recurrence!),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _recurrenceLabel(String value) {
    switch (value) {
      case 'diaria':
        return 'Diaria';
      case 'semanal':
        return 'Semanal';
      case 'mensual':
        return 'Mensual';
      default:
        return value;
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Activa' : 'Desactivada',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: active
              ? colorScheme.onPrimaryContainer
              : colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),

          const SizedBox(width: 6),

          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyRoutineState extends StatelessWidget {
  const _EmptyRoutineState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Icon(
              Icons.event_repeat_outlined,
              size: 54,
              color: colorScheme.primary,
            ),

            const SizedBox(height: 16),

            Text(
              'Aún no hay rutinas',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Crea la primera rutina '
              'para organizar las actividades '
              'habituales del perfil activo.',
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

class _NoActiveRoutines extends StatelessWidget {
  const _NoActiveRoutines();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Icon(Icons.info_outline),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                'No hay rutinas activas. '
                'Puedes crear una nueva rutina.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.onErrorContainer),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48),

            const SizedBox(height: 16),

            Text(
              'No fue posible cargar las rutinas',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(message, textAlign: TextAlign.center),

            const SizedBox(height: 18),

            FilledButton.icon(
              onPressed: () {
                onRetry();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
