import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../routine/domain/models/routine.dart';
import '../../../routine/domain/repositories/routine_repository.dart';
import '../../domain/models/routine_status.dart';
import '../../domain/repositories/routine_status_repository.dart';
import '../../domain/services/routine_status_record_factory.dart';
import '../viewmodels/routine_status_form_view_model.dart';

class RoutineStatusFormView extends StatelessWidget {
  const RoutineStatusFormView({
    required this.routineRepository,
    required this.routineStatusRepository,
    required this.recordFactory,
    required this.anonymousId,
    super.key,
  });

  final RoutineRepository routineRepository;
  final RoutineStatusRepository routineStatusRepository;
  final RoutineStatusRecordFactory recordFactory;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RoutineStatusFormViewModel(
        routineRepository,
        routineStatusRepository,
        recordFactory,
        anonymousId: anonymousId,
      )..initialize(),
      child: const _RoutineStatusFormContent(),
    );
  }
}

class _RoutineStatusFormContent extends StatefulWidget {
  const _RoutineStatusFormContent();

  @override
  State<_RoutineStatusFormContent> createState() =>
      _RoutineStatusFormContentState();
}

class _RoutineStatusFormContentState extends State<_RoutineStatusFormContent> {
  final GlobalKey _generalErrorKey = GlobalKey();
  final GlobalKey _routineSectionKey = GlobalKey();
  final GlobalKey _statusSectionKey = GlobalKey();

  final TextEditingController _observationController = TextEditingController();

  @override
  void dispose() {
    _observationController.dispose();

    super.dispose();
  }

  Future<void> _pickDate(RoutineStatusFormViewModel viewModel) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: viewModel.selectedDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'Seleccionar fecha',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (selected != null) {
      viewModel.selectDate(selected);
    }
  }

  void _scrollToSection(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final sectionContext = key.currentContext;

      if (sectionContext == null || !sectionContext.mounted) {
        return;
      }

      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        alignment: 0.10,
      );
    });
  }

  Future<void> _save(RoutineStatusFormViewModel viewModel) async {
    FocusManager.instance.primaryFocus?.unfocus();

    viewModel.setObservation(_observationController.text);

    final success = await viewModel.save();

    if (!mounted) {
      return;
    }

    if (!success) {
      if (viewModel.routineError != null) {
        _scrollToSection(_routineSectionKey);
      } else if (viewModel.statusError != null) {
        _scrollToSection(_statusSectionKey);
      } else if (viewModel.errorMessage != null) {
        _scrollToSection(_generalErrorKey);
      }

      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Estado de rutina guardado correctamente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

    if (context.canPop()) {
      context.pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RoutineStatusFormViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar estado de rutina'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: viewModel.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  _IntroCard(colorScheme: colorScheme),

                  const SizedBox(height: 20),

                  if (viewModel.errorMessage != null) ...[
                    KeyedSubtree(
                      key: _generalErrorKey,
                      child: _GeneralErrorCard(
                        message: viewModel.errorMessage!,
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],

                  KeyedSubtree(
                    key: _routineSectionKey,
                    child: _SectionCard(
                      title: 'Seleccionar rutina',
                      subtitle:
                          'Elige una rutina activa para registrar su estado.',
                      requiredField: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!viewModel.hasActiveRoutines)
                            const _NoRoutinesCard()
                          else
                            for (final routine in viewModel.activeRoutines)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _RoutineOption(
                                  routine: routine,
                                  selected:
                                      viewModel.selectedRoutineId ==
                                      routine.routineId,
                                  enabled: !viewModel.isSaving,
                                  onTap: () {
                                    viewModel.selectRoutine(routine.routineId);
                                  },
                                ),
                              ),

                          if (viewModel.routineError != null) ...[
                            const SizedBox(height: 8),
                            _FieldError(message: viewModel.routineError!),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _SectionCard(
                    title: 'Fecha del registro',
                    subtitle: 'Indica la fecha a la que corresponde el estado.',
                    requiredField: true,
                    child: _PickerButton(
                      key: const Key('routine-status-date-picker'),
                      icon: Icons.calendar_today_outlined,
                      label: 'Fecha',
                      value: _formatDate(viewModel.selectedDate),
                      onPressed: viewModel.isSaving
                          ? null
                          : () {
                              _pickDate(viewModel);
                            },
                    ),
                  ),

                  const SizedBox(height: 16),

                  KeyedSubtree(
                    key: _statusSectionKey,
                    child: _SectionCard(
                      title: 'Estado de la rutina',
                      subtitle: 'Selecciona el estado descriptivo observado.',
                      requiredField: true,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final status in RoutineStatus.values)
                                ChoiceChip(
                                  key: Key('routine-status-${status.code}'),
                                  selected: viewModel.selectedStatus == status,
                                  showCheckmark: false,
                                  onSelected: viewModel.isSaving
                                      ? null
                                      : (_) {
                                          viewModel.selectStatus(status);
                                        },
                                  label: Text(status.label),
                                ),
                            ],
                          ),

                          if (viewModel.statusError != null) ...[
                            const SizedBox(height: 8),
                            _FieldError(message: viewModel.statusError!),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _SectionCard(
                    title: 'Observación',
                    subtitle:
                        'Añade información descriptiva solo si es necesaria.',
                    child: TextField(
                      key: const Key('routine-status-observation-field'),
                      controller: _observationController,
                      enabled: !viewModel.isSaving,
                      minLines: 3,
                      maxLines: 5,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: 'Observación (opcional)',
                        hintText: 'Ej. La actividad cambió de horario.',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.description_outlined),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _PrivacyCard(colorScheme: colorScheme),

                  const SizedBox(height: 24),

                  FilledButton.icon(
                    key: const Key('routine-status-save-button'),
                    onPressed:
                        viewModel.isSaving || !viewModel.hasActiveRoutines
                        ? null
                        : () {
                            _save(viewModel);
                          },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: viewModel.isSaving
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      viewModel.isSaving ? 'Guardando...' : 'Guardar estado',
                    ),
                  ),

                  const SizedBox(height: 12),

                  Text(
                    'Los campos marcados con * '
                    'son obligatorios.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  static String _formatDate(DateTime date) {
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

    return '${date.day.toString().padLeft(2, '0')} '
        '${months[date.month - 1]} '
        '${date.year}';
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.event_available_outlined,
                  color: colorScheme.onPrimary,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  'Estado de una rutina',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            'Registra de forma descriptiva '
            'qué ocurrió con una rutina en '
            'una fecha determinada.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoRoutinesCard extends StatelessWidget {
  const _NoRoutinesCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('routine-status-no-routines'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colorScheme.primary),

          const SizedBox(width: 10),

          const Expanded(
            child: Text(
              'No hay rutinas activas disponibles. '
              'Crea una nueva rutina antes de '
              'registrar su estado.',
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutineOption extends StatelessWidget {
  const _RoutineOption({
    required this.routine,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Routine routine;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.55)
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: Key('routine-status-routine-${routine.routineId}'),
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.checklist_rounded,
                  color: colorScheme.primary,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    if (routine.scheduledTime != null) ...[
                      const SizedBox(height: 4),

                      Text(
                        routine.scheduledTime!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: selected ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerButton extends StatelessWidget {
  const _PickerButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.primary),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
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

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      key: const Key('routine-status-profile-message'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: colorScheme.primary),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'La información se guardará '
              'en el perfil activo.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.requiredField = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool requiredField;

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
            Text(
              requiredField ? '$title *' : title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 16),

            child,
          ],
        ),
      ),
    );
  }
}

class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 18, color: colorScheme.error),

        const SizedBox(width: 6),

        Expanded(
          child: Text(message, style: TextStyle(color: colorScheme.error)),
        ),
      ],
    );
  }
}

class _GeneralErrorCard extends StatelessWidget {
  const _GeneralErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
