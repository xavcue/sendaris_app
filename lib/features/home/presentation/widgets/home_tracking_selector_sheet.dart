import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../tracking/domain/models/anonymous_tracking_profile.dart';
import '../../../tracking/presentation/viewmodels/tracking_view_model.dart';

class HomeTrackingSelectorSheet extends StatefulWidget {
  const HomeTrackingSelectorSheet({super.key});

  @override
  State<HomeTrackingSelectorSheet> createState() =>
      _HomeTrackingSelectorSheetState();
}

class _HomeTrackingSelectorSheetState extends State<HomeTrackingSelectorSheet> {
  bool _isManaging = false;

  final Set<String> _selectedIds = <String>{};

  void _startManaging() {
    setState(() {
      _isManaging = true;
      _selectedIds.clear();
    });
  }

  void _cancelManaging() {
    setState(() {
      _isManaging = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String anonymousId) {
    setState(() {
      if (!_selectedIds.add(anonymousId)) {
        _selectedIds.remove(anonymousId);
      }
    });
  }

  void _toggleSelectAll(List<AnonymousTrackingProfile> profiles) {
    setState(() {
      if (_selectedIds.length == profiles.length) {
        _selectedIds.clear();

        return;
      }

      _selectedIds
        ..clear()
        ..addAll(profiles.map((profile) => profile.anonymousId));
    });
  }

  Future<void> _confirmDeletion(TrackingViewModel viewModel) async {
    if (_selectedIds.isEmpty || viewModel.isLoading) {
      return;
    }

    final selectedCount = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colorScheme = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: const Text('¿Eliminar definitivamente?'),
          content: Text(
            selectedCount == 1
                ? 'Se eliminarán este seguimiento y toda la información '
                      'asociada, incluidos registros y rutinas. '
                      'Esta acción no se puede deshacer.'
                : 'Se eliminarán los seguimientos seleccionados y toda la '
                      'información asociada, incluidos registros y rutinas. '
                      'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('tracking-confirm-delete-button'),
              style: FilledButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Eliminar definitivamente'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final idsToDelete = Set<String>.unmodifiable(_selectedIds);

    final success = await viewModel.deleteProfiles(idsToDelete);

    if (!mounted) {
      return;
    }

    if (success) {
      final message =
          viewModel.successMessage ?? 'Seguimiento eliminado definitivamente.';

      Navigator.of(context).pop(message);

      return;
    }

    final remainingIds = viewModel.profiles
        .map((profile) => profile.anonymousId)
        .toSet();

    setState(() {
      _selectedIds.removeWhere((id) => !remainingIds.contains(id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TrackingViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final profiles = _isManaging
        ? viewModel.orderedProfiles
        : viewModel.activeProfiles;

    final allSelected =
        profiles.isNotEmpty && _selectedIds.length == profiles.length;

    return PopScope(
      canPop: !_isManaging,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        if (_isManaging && !viewModel.isLoading) {
          _cancelManaging();
        }
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isManaging ? 'Administrar seguimientos' : 'Tus seguimientos',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isManaging
                    ? 'Selecciona uno o varios seguimientos '
                          'para eliminarlos definitivamente.'
                    : 'La información de cada seguimiento '
                          'se mantiene separada.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                key: const Key('tracking-privacy-message'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _isManaging
                          ? Icons.warning_amber_rounded
                          : Icons.shield_outlined,
                      size: 19,
                      color: _isManaging
                          ? colorScheme.error
                          : colorScheme.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _isManaging
                            ? 'La eliminación es permanente y '
                                  'también borra los registros '
                                  'y rutinas asociados.'
                            : 'Cada seguimiento es anónimo. '
                                  'No se solicitan nombres '
                                  'ni datos personales.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (viewModel.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  key: const Key('tracking-selector-error'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    viewModel.errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              if (_isManaging && profiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedIds.length} '
                        '${_selectedIds.length == 1 ? 'seleccionado' : 'seleccionados'}',
                        key: const Key('tracking-selected-count'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('tracking-select-all-button'),
                      onPressed: viewModel.isLoading
                          ? null
                          : () {
                              _toggleSelectAll(profiles);
                            },
                      child: Text(
                        allSelected ? 'Quitar selección' : 'Seleccionar todos',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: profiles.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            'Aún no tienes seguimientos.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        key: const Key('tracking-selector-list'),
                        shrinkWrap: true,
                        itemCount: profiles.length,
                        separatorBuilder: (_, _) {
                          return const SizedBox(height: 10);
                        },
                        itemBuilder: (context, index) {
                          final profile = profiles[index];

                          final number =
                              viewModel.trackingNumberFor(profile) ?? index + 1;

                          final label = viewModel.trackingLabelFor(profile);

                          final isCurrent =
                              viewModel.activeAnonymousId ==
                              profile.anonymousId;

                          final isMarked = _selectedIds.contains(
                            profile.anonymousId,
                          );

                          return _TrackingOptionCard(
                            key: Key('tracking-option-$number'),
                            profile: profile,
                            label: label,
                            isCurrent: isCurrent,
                            isManaging: _isManaging,
                            isMarked: isMarked,
                            isLoading: viewModel.isLoading,
                            onSelected: () {
                              if (_isManaging) {
                                _toggleSelection(profile.anonymousId);

                                return;
                              }

                              final success = viewModel.selectProfile(profile);

                              if (!success) {
                                return;
                              }

                              Navigator.of(context).pop('$label seleccionado.');
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 18),
              if (_isManaging) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('tracking-delete-selected-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                    onPressed: _selectedIds.isEmpty || viewModel.isLoading
                        ? null
                        : () {
                            _confirmDeletion(viewModel);
                          },
                    icon: viewModel.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                    label: Text(
                      viewModel.isLoading
                          ? 'Eliminando...'
                          : 'Eliminar definitivamente',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    key: const Key('tracking-management-cancel-button'),
                    onPressed: viewModel.isLoading ? null : _cancelManaging,
                    child: const Text('Cancelar'),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('tracking-create-button'),
                    onPressed: viewModel.isLoading
                        ? null
                        : () async {
                            final success = await viewModel
                                .createAndPersistProfile();

                            if (!context.mounted || !success) {
                              return;
                            }

                            final label = viewModel.activeTrackingLabel;

                            if (label == null) {
                              return;
                            }

                            Navigator.of(context)
                                .pop('$label creado y seleccionado.');
                          },
                    icon: viewModel.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: Text(
                      viewModel.isLoading ? 'Creando...' : 'Nuevo seguimiento',
                    ),
                  ),
                ),
                if (profiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('tracking-manage-button'),
                      onPressed: viewModel.isLoading ? null : _startManaging,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Administrar'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingOptionCard extends StatelessWidget {
  const _TrackingOptionCard({
    required this.profile,
    required this.label,
    required this.isCurrent,
    required this.isManaging,
    required this.isMarked,
    required this.isLoading,
    required this.onSelected,
    super.key,
  });

  final AnonymousTrackingProfile profile;

  final String label;

  final bool isCurrent;

  final bool isManaging;

  final bool isMarked;

  final bool isLoading;

  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final canSelect = profile.isActive && !isLoading;

    final canManage = !isLoading;

    final highlighted = isManaging ? isMarked : isCurrent;

    return Material(
      color: highlighted
          ? colorScheme.primaryContainer.withValues(alpha: 0.55)
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: (isManaging ? canManage : canSelect) ? onSelected : null,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: highlighted
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.layers_outlined,
                  color: highlighted
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Creado el '
                      '${_formatTrackingDate(profile.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (isManaging)
                Checkbox(
                  value: isMarked,
                  onChanged: canManage
                      ? (_) {
                          onSelected();
                        }
                      : null,
                )
              else if (isCurrent)
                Icon(Icons.check_circle_rounded, color: colorScheme.primary)
              else
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

String _formatTrackingDate(DateTime value) {
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

  final localValue = value.toLocal();

  return '${localValue.day.toString().padLeft(2, '0')} '
      '${months[localValue.month - 1]} '
      '${localValue.year}';
}
