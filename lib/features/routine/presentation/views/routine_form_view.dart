import 'dart:async';

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
  static const Duration _validationMessageDuration = Duration(seconds: 4);

  final GlobalKey _nameSectionKey = GlobalKey();

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;

  Timer? _validationMessageTimer;

  bool _showValidationMessages = false;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(
      text: widget.initialRoutine?.name ?? '',
    );

    _descriptionController = TextEditingController(
      text: widget.initialRoutine?.description ?? '',
    );
  }

  @override
  void dispose() {
    _validationMessageTimer?.cancel();

    _nameController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  void _showErrorsTemporarily() {
    _validationMessageTimer?.cancel();

    if (!_showValidationMessages) {
      setState(() {
        _showValidationMessages = true;
      });
    }

    _validationMessageTimer = Timer(_validationMessageDuration, () {
      if (!mounted) {
        return;
      }

      setState(() {
        _showValidationMessages = false;
      });
    });
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

    if (selected == null) {
      return;
    }

    viewModel.setTime(hour: selected.hour, minute: selected.minute);
  }

  Future<void> _save(RoutineFormViewModel viewModel) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final isEditing = viewModel.isEditing;

    final result = await viewModel.save(
      name: _nameController.text,
      description: _descriptionController.text,
    );

    if (!mounted) {
      return;
    }

    if (result == null) {
      _showErrorsTemporarily();

      if (viewModel.errorFor('name') != null) {
        final targetContext = _nameSectionKey.currentContext;

        if (targetContext != null && targetContext.mounted) {
          await Scrollable.ensureVisible(
            targetContext,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            alignment: 0.15,
          );
        }
      }

      return;
    }

    _validationMessageTimer?.cancel();

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Rutina actualizada correctamente.'
                : 'Rutina creada correctamente.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
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
      key: const Key('routine-form-view'),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          viewModel.isEditing
              ? 'Editar registro de rutina'
              : 'Registrar rutina',
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          key: const Key('routine-form-scroll'),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _IntroCard(isEditing: viewModel.isEditing),
              const SizedBox(height: 20),
              KeyedSubtree(
                key: _nameSectionKey,
                child: _SectionCard(
                  title: 'Nombre de la rutina',
                  subtitle:
                      'Escribe un nombre breve que permita '
                      'identificar la rutina fácilmente.',
                  requiredField: true,
                  child: TextField(
                    key: const Key('routine-name-field'),
                    controller: _nameController,
                    enabled: !viewModel.isSaving,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Ej. Preparar mochila',
                      prefixIcon: const Icon(Icons.checklist_rounded),
                      errorText: _showValidationMessages
                          ? viewModel.errorFor('name')
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Descripción (opcional)',
                subtitle:
                    'Añade información descriptiva '
                    'solo si es necesaria.',
                child: TextField(
                  key: const Key('routine-description-field'),
                  controller: _descriptionController,
                  enabled: !viewModel.isSaving,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Escribe una descripción breve',
                    hintMaxLines: 2,
                    prefixIcon: Icon(Icons.description_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Programación (opcional)',
                subtitle:
                    'Puedes añadir una hora y una '
                    'frecuencia si aplican a esta rutina.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TimePickerButton(
                      key: const Key('routine-time-picker'),
                      value: viewModel.selectedTime,
                      onPressed: viewModel.isSaving
                          ? null
                          : () {
                              _pickTime(viewModel);
                            },
                    ),
                    if (viewModel.selectedTime != null) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          key: const Key('routine-clear-time'),
                          onPressed: viewModel.isSaving
                              ? null
                              : viewModel.clearTime,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Quitar hora'),
                        ),
                      ),
                    ],
                    if (_showValidationMessages &&
                        viewModel.errorFor('scheduledTime') != null) ...[
                      const SizedBox(height: 8),
                      _FieldError(
                        message: viewModel.errorFor('scheduledTime')!,
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'Frecuencia (opcional)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Selecciona una frecuencia '
                      'solo si aplica. Toca de nuevo '
                      'la opción seleccionada para quitarla.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ChoiceChip(
                          key: const Key('routine-recurrence-daily'),
                          selected: viewModel.selectedRecurrence == 'diaria',
                          showCheckmark: false,
                          onSelected: viewModel.isSaving
                              ? null
                              : (selected) {
                                  viewModel.setRecurrence(
                                    selected ? 'diaria' : null,
                                  );
                                },
                          label: const Text('Diaria'),
                        ),
                        ChoiceChip(
                          key: const Key('routine-recurrence-weekly'),
                          selected: viewModel.selectedRecurrence == 'semanal',
                          showCheckmark: false,
                          onSelected: viewModel.isSaving
                              ? null
                              : (selected) {
                                  viewModel.setRecurrence(
                                    selected ? 'semanal' : null,
                                  );
                                },
                          label: const Text('Semanal'),
                        ),
                        ChoiceChip(
                          key: const Key('routine-recurrence-monthly'),
                          selected: viewModel.selectedRecurrence == 'mensual',
                          showCheckmark: false,
                          onSelected: viewModel.isSaving
                              ? null
                              : (selected) {
                                  viewModel.setRecurrence(
                                    selected ? 'mensual' : null,
                                  );
                                },
                          label: const Text('Mensual'),
                        ),
                      ],
                    ),
                    if (_showValidationMessages &&
                        viewModel.errorFor('recurrence') != null) ...[
                      const SizedBox(height: 10),
                      _FieldError(message: viewModel.errorFor('recurrence')!),
                    ],
                  ],
                ),
              ),
              if (_showValidationMessages &&
                  viewModel.errorMessage != null) ...[
                const SizedBox(height: 16),
                _GeneralErrorCard(message: viewModel.errorMessage!),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('routine-save-button'),
                onPressed: viewModel.isSaving
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
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(
                  viewModel.isSaving
                      ? viewModel.isEditing
                            ? 'Guardando cambios...'
                            : 'Guardando...'
                      : viewModel.isEditing
                      ? 'Guardar cambios'
                      : 'Guardar rutina',
                ),
              ),
            ],
          ),
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
  const _IntroCard({required this.isEditing});

  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('routine-intro-card'),
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
                  Icons.event_repeat_outlined,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isEditing
                      ? 'Actualizar registro de rutina'
                      : 'Registro de rutina',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            isEditing
                ? 'Revisa y modifica únicamente '
                      'la información necesaria de la rutina.'
                : 'Define una actividad habitual '
                      'para organizar las rutinas '
                      'del seguimiento actual.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isEditing
                      ? 'Los cambios se aplicarán a la '
                            'rutina del seguimiento actual.'
                      : 'La rutina se guardará en el '
                            'seguimiento actual.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (requiredField)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Obligatorio',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
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

class _TimePickerButton extends StatelessWidget {
  const _TimePickerButton({
    required this.value,
    required this.onPressed,
    super.key,
  });

  final String? value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerLow.withValues(alpha: 0.72),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 78),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.62),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.schedule_outlined,
                size: 22,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hora programada',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value ?? 'Sin hora',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: value == null
                            ? colorScheme.onSurfaceVariant
                            : colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
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
