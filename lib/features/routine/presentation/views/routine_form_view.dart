import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../domain/models/routine.dart';
import '../../domain/repositories/routine_repository.dart';
import '../../domain/services/routine_factory.dart';
import '../viewmodels/routine_form_view_model.dart';

class RoutineFormView extends StatelessWidget {
  const RoutineFormView({
    required this.repository,
    required this.routineFactory,
    required this.anonymousId,
    this.initialRoutine,
    super.key,
  });

  final RoutineRepository repository;
  final RoutineFactory routineFactory;
  final String anonymousId;
  final Routine? initialRoutine;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RoutineFormViewModel(
        repository,
        routineFactory,
        anonymousId: anonymousId,
        initialRoutine: initialRoutine,
      ),
      child: _RoutineFormContent(initialRoutine: initialRoutine),
    );
  }
}

class _RoutineFormContent extends StatefulWidget {
  const _RoutineFormContent({required this.initialRoutine});

  final Routine? initialRoutine;

  @override
  State<_RoutineFormContent> createState() => _RoutineFormContentState();
}

class _RoutineFormContentState extends State<_RoutineFormContent> {
  final _nameController = TextEditingController();

  final _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _nameController.text = widget.initialRoutine?.name ?? '';

    _descriptionController.text = widget.initialRoutine?.description ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  Future<void> _pickTime(RoutineFormViewModel viewModel) async {
    final current = _timeFromString(viewModel.selectedTime);

    final selected = await showTimePicker(
      context: context,
      initialTime: current ?? TimeOfDay.now(),
      helpText: 'Seleccionar hora',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (selected != null) {
      viewModel.setTime(hour: selected.hour, minute: selected.minute);
    }
  }

  Future<void> _save(RoutineFormViewModel viewModel) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final result = await viewModel.save(
      name: _nameController.text,
      description: _descriptionController.text,
    );

    if (!mounted || result == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            viewModel.isEditing
                ? 'Rutina actualizada correctamente.'
                : 'Rutina creada correctamente.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

    context.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RoutineFormViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(viewModel.isEditing ? 'Editar rutina' : 'Nueva rutina'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _IntroCard(editing: viewModel.isEditing),

            const SizedBox(height: 20),

            _SectionCard(
              title: 'Información de la rutina',
              subtitle:
                  'Registra una actividad habitual para el perfil activo.',
              child: Column(
                children: [
                  TextField(
                    key: const Key('routine-name-field'),
                    controller: _nameController,
                    enabled: !viewModel.isSaving,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Nombre *',
                      hintText: 'Ej. Preparar mochila',
                      prefixIcon: const Icon(Icons.checklist_outlined),
                      errorText: viewModel.errorFor('name'),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    key: const Key('routine-description-field'),
                    controller: _descriptionController,
                    enabled: !viewModel.isSaving,
                    minLines: 3,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                      hintText: 'Añade una descripción breve si es necesaria.',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            _SectionCard(
              title: 'Programación',
              subtitle: 'La hora y la frecuencia son opcionales.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TimePickerCard(
                    value: viewModel.selectedTime,
                    enabled: !viewModel.isSaving,
                    onPressed: () {
                      _pickTime(viewModel);
                    },
                    onClear: viewModel.selectedTime == null
                        ? null
                        : viewModel.clearTime,
                  ),

                  if (viewModel.errorFor('scheduledTime') != null) ...[
                    const SizedBox(height: 8),
                    _FieldError(message: viewModel.errorFor('scheduledTime')!),
                  ],

                  const SizedBox(height: 22),

                  Text(
                    'Frecuencia',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Selecciona una frecuencia solo cuando aplique.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 12),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        key: const Key('routine-recurrence-none'),
                        selected: viewModel.selectedRecurrence == null,
                        showCheckmark: false,
                        onSelected: viewModel.isSaving
                            ? null
                            : (_) {
                                viewModel.setRecurrence(null);
                              },
                        label: const Text('Sin recurrencia'),
                      ),
                      ChoiceChip(
                        key: const Key('routine-recurrence-daily'),
                        selected: viewModel.selectedRecurrence == 'diaria',
                        showCheckmark: false,
                        onSelected: viewModel.isSaving
                            ? null
                            : (_) {
                                viewModel.setRecurrence('diaria');
                              },
                        label: const Text('Diaria'),
                      ),
                      ChoiceChip(
                        key: const Key('routine-recurrence-weekly'),
                        selected: viewModel.selectedRecurrence == 'semanal',
                        showCheckmark: false,
                        onSelected: viewModel.isSaving
                            ? null
                            : (_) {
                                viewModel.setRecurrence('semanal');
                              },
                        label: const Text('Semanal'),
                      ),
                      ChoiceChip(
                        key: const Key('routine-recurrence-monthly'),
                        selected: viewModel.selectedRecurrence == 'mensual',
                        showCheckmark: false,
                        onSelected: viewModel.isSaving
                            ? null
                            : (_) {
                                viewModel.setRecurrence('mensual');
                              },
                        label: const Text('Mensual'),
                      ),
                    ],
                  ),

                  if (viewModel.errorFor('recurrence') != null) ...[
                    const SizedBox(height: 8),
                    _FieldError(message: viewModel.errorFor('recurrence')!),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            const _PrivacyCard(),

            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),
              _GeneralErrorCard(message: viewModel.errorMessage!),
            ],

            const SizedBox(height: 24),

            FilledButton.icon(
              key: const Key('routine-save-button'),
              onPressed: viewModel.isSaving ? null : () => _save(viewModel),
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
                  : Icon(
                      viewModel.isEditing
                          ? Icons.save_outlined
                          : Icons.add_task_rounded,
                    ),
              label: Text(
                viewModel.isSaving
                    ? 'Guardando...'
                    : viewModel.isEditing
                    ? 'Guardar cambios'
                    : 'Crear rutina',
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Los campos marcados con * son obligatorios.',
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

  static TimeOfDay? _timeFromString(String? value) {
    if (value == null) {
      return null;
    }

    final parts = value.split(':');

    if (parts.length != 2) {
      return null;
    }

    final hour = int.tryParse(parts[0]);

    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return null;
    }

    return TimeOfDay(hour: hour, minute: minute);
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.editing});

  final bool editing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
                  editing ? Icons.edit_rounded : Icons.add_task_rounded,
                  color: colorScheme.onPrimary,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  editing ? 'Actualizar rutina' : 'Crear rutina',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            editing
                ? 'Actualiza los datos de la rutina '
                      'que necesites cambiar.'
                : 'Define una actividad cotidiana '
                      'para organizar la rutina del perfil activo.',
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

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

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
              title,
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

            const SizedBox(height: 18),

            child,
          ],
        ),
      ),
    );
  }
}

class _TimePickerCard extends StatelessWidget {
  const _TimePickerCard({
    required this.value,
    required this.enabled,
    required this.onPressed,
    required this.onClear,
  });

  final String? value;
  final bool enabled;
  final VoidCallback onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_outlined, color: colorScheme.primary),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hora programada', style: theme.textTheme.labelLarge),

                const SizedBox(height: 3),

                Text(
                  value ?? 'Sin hora definida',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: value == null
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),

          if (onClear != null)
            IconButton(
              tooltip: 'Quitar hora',
              onPressed: enabled ? onClear : null,
              icon: const Icon(Icons.close_rounded),
            ),

          TextButton(
            key: const Key('routine-time-picker'),
            onPressed: enabled ? onPressed : null,
            child: Text(value == null ? 'Añadir' : 'Cambiar'),
          ),
        ],
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('routine-profile-message'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: colorScheme.primary),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'La rutina se guardará en el perfil activo.',
              style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
            ),
          ),
        ],
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
        Icon(Icons.error_outline, size: 17, color: colorScheme.error),

        const SizedBox(width: 6),

        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: colorScheme.error),
          ),
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
