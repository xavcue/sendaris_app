import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/sleep_record.dart';
import '../../domain/repositories/sleep_repository.dart';
import '../../domain/services/sleep_record_factory.dart';
import '../viewmodels/sleep_form_view_model.dart';

class SleepFormView extends StatelessWidget {
  const SleepFormView({
    required this.repository,
    required this.recordFactory,
    required this.anonymousId,
    this.initialRecord,
    super.key,
  });

  final SleepRepository repository;
  final SleepRecordFactory recordFactory;
  final String anonymousId;
  final SleepRecord? initialRecord;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SleepFormViewModel(
        repository,
        recordFactory,
        anonymousId: anonymousId,
        initialRecord: initialRecord,
      ),
      child: _SleepFormContent(
        initialObservation: initialRecord?.observation ?? '',
      ),
    );
  }
}

class _SleepFormContent extends StatefulWidget {
  const _SleepFormContent({required this.initialObservation});

  final String initialObservation;

  @override
  State<_SleepFormContent> createState() => _SleepFormContentState();
}

class _SleepFormContentState extends State<_SleepFormContent> {
  static const Duration _validationMessageDuration = Duration(seconds: 4);

  final GlobalKey _dateSectionKey = GlobalKey();

  final GlobalKey _scheduleSectionKey = GlobalKey();

  late final TextEditingController _observationController;

  Timer? _validationMessageTimer;

  bool _showValidationMessages = false;

  @override
  void initState() {
    super.initState();

    _observationController = TextEditingController(
      text: widget.initialObservation,
    );
  }

  @override
  void dispose() {
    _validationMessageTimer?.cancel();

    _observationController.dispose();

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

  Future<void> _pickDate(SleepFormViewModel viewModel) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: viewModel.selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      helpText: 'Seleccionar fecha',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (selected != null) {
      viewModel.setDate(selected);
    }
  }

  Future<void> _pickStartTime(SleepFormViewModel viewModel) async {
    final selected = await showTimePicker(
      context: context,
      initialTime:
          _timeOfDayFromString(viewModel.startTime) ??
          const TimeOfDay(hour: 22, minute: 0),
      helpText: 'Hora de inicio',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (selected != null) {
      viewModel.setStartTime(hour: selected.hour, minute: selected.minute);
    }
  }

  Future<void> _pickEndTime(SleepFormViewModel viewModel) async {
    final selected = await showTimePicker(
      context: context,
      initialTime:
          _timeOfDayFromString(viewModel.endTime) ??
          const TimeOfDay(hour: 6, minute: 0),
      helpText: 'Hora de finalización',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (selected != null) {
      viewModel.setEndTime(hour: selected.hour, minute: selected.minute);
    }
  }

  Future<void> _save(SleepFormViewModel viewModel) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final success = await viewModel.save(
      observation: _observationController.text,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      _showErrorsTemporarily();

      BuildContext? targetContext;

      if (viewModel.errorFor('date') != null) {
        targetContext = _dateSectionKey.currentContext;
      } else if (viewModel.errorFor('startTime') != null ||
          viewModel.errorFor('endTime') != null) {
        targetContext = _scheduleSectionKey.currentContext;
      }

      if (targetContext != null && targetContext.mounted) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          alignment: 0.15,
        );
      }

      return;
    }

    _validationMessageTimer?.cancel();

    if (!viewModel.isEditing) {
      _observationController.clear();
    }

    final messenger = ScaffoldMessenger.of(context);

    final successMessage =
        viewModel.successMessage ??
        (viewModel.isEditing
            ? 'Registro de sueño actualizado correctamente.'
            : 'Registro de sueño guardado correctamente.');

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(successMessage),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

    if (viewModel.isEditing) {
      Navigator.of(context).pop(true);

      return;
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SleepFormViewModel>();

    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final isEditing = viewModel.isEditing;

    return Scaffold(
      key: Key(isEditing ? 'sleep-edit-view' : 'sleep-create-view'),
      appBar: AppBar(
        title: Text(isEditing ? 'Editar registro de sueño' : 'Registrar sueño'),
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
            _IntroCard(colorScheme: colorScheme, isEditing: isEditing),
            const SizedBox(height: 20),
            KeyedSubtree(
              key: _dateSectionKey,
              child: _SectionCard(
                title: 'Cuándo ocurrió',
                subtitle:
                    'Selecciona la fecha correspondiente '
                    'al inicio del periodo de sueño.',
                requiredField: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PickerButton(
                      key: const Key('sleep-date-picker'),
                      icon: Icons.calendar_today_outlined,
                      label: 'Fecha',
                      value: viewModel.selectedDate == null
                          ? 'Sin seleccionar'
                          : _formatDate(viewModel.selectedDate!),
                      onPressed: viewModel.isSaving
                          ? null
                          : () {
                              _pickDate(viewModel);
                            },
                    ),
                    if (_showValidationMessages &&
                        viewModel.errorFor('date') != null) ...[
                      const SizedBox(height: 8),
                      _FieldError(message: viewModel.errorFor('date')!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            KeyedSubtree(
              key: _scheduleSectionKey,
              child: _SectionCard(
                title: 'Horario',
                subtitle:
                    'Selecciona la hora de inicio '
                    'y la hora de finalización.',
                requiredField: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _PickerButton(
                            key: const Key('sleep-start-time-picker'),
                            icon: Icons.nightlight_outlined,
                            label: 'Hora de inicio',
                            value: viewModel.startTime ?? 'Sin seleccionar',
                            onPressed: viewModel.isSaving
                                ? null
                                : () {
                                    _pickStartTime(viewModel);
                                  },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PickerButton(
                            key: const Key('sleep-end-time-picker'),
                            icon: Icons.wb_twilight_outlined,
                            label: 'Hora final',
                            value: viewModel.endTime ?? 'Sin seleccionar',
                            onPressed: viewModel.isSaving
                                ? null
                                : () {
                                    _pickEndTime(viewModel);
                                  },
                          ),
                        ),
                      ],
                    ),
                    if (_showValidationMessages &&
                        viewModel.errorFor('startTime') != null) ...[
                      const SizedBox(height: 8),
                      _FieldError(message: viewModel.errorFor('startTime')!),
                    ],
                    if (_showValidationMessages &&
                        viewModel.errorFor('endTime') != null) ...[
                      const SizedBox(height: 8),
                      _FieldError(message: viewModel.errorFor('endTime')!),
                    ],
                    const SizedBox(height: 16),
                    _DurationSummary(
                      duration: viewModel.formattedDuration,
                      hasStartTime: viewModel.startTime != null,
                      hasEndTime: viewModel.endTime != null,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Si la hora de finalización '
                            'es anterior a la hora de inicio, '
                            'se considera que el periodo '
                            'terminó al día siguiente.',
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
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Observación (opcional)',
              subtitle:
                  'Añade información descriptiva '
                  'solo si es necesaria.',
              child: TextField(
                key: const Key('sleep-observation-field'),
                controller: _observationController,
                enabled: !viewModel.isSaving,
                minLines: 3,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Escribe una observación descriptiva',
                  hintMaxLines: 2,
                  prefixIcon: Icon(Icons.description_outlined),
                ),
              ),
            ),
            if (_showValidationMessages && viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),
              _GeneralErrorCard(message: viewModel.errorMessage!),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('sleep-save-button'),
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
                    ? isEditing
                          ? 'Guardando cambios...'
                          : 'Guardando...'
                    : isEditing
                    ? 'Guardar cambios'
                    : 'Guardar sueño',
              ),
            ),
          ],
        ),
      ),
    );
  }

  static TimeOfDay? _timeOfDayFromString(String? value) {
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
  const _IntroCard({required this.colorScheme, required this.isEditing});

  final ColorScheme colorScheme;
  final bool isEditing;

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
                  Icons.bedtime_outlined,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isEditing
                      ? 'Actualizar registro de sueño'
                      : 'Registro de sueño',
                  key: Key(
                    isEditing
                        ? 'sleep-edit-intro-title'
                        : 'sleep-create-intro-title',
                  ),
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
                ? 'Revisa y modifica únicamente la '
                      'información necesaria del registro.'
                : 'Registra la fecha y el horario '
                      'correspondiente al periodo de sueño.',
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
                  'Sendaris calcula únicamente '
                  'la duración del periodo registrado; '
                  'no realiza valoraciones clínicas.',
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
              Icon(icon, size: 22, color: colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
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
                    const SizedBox(height: 3),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationSummary extends StatelessWidget {
  const _DurationSummary({
    required this.duration,
    required this.hasStartTime,
    required this.hasEndTime,
  });

  final String? duration;
  final bool hasStartTime;
  final bool hasEndTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final hasCompleteSchedule = hasStartTime && hasEndTime;

    final calculated = duration != null;

    final value = calculated
        ? duration!
        : hasCompleteSchedule
        ? 'Revisa el horario'
        : 'Pendiente';

    final description = calculated
        ? 'Calculada automáticamente'
        : hasCompleteSchedule
        ? 'Las horas seleccionadas deben ser distintas.'
        : 'Selecciona ambas horas para calcularla.';

    return Container(
      key: const Key('sleep-duration-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: calculated
            ? colorScheme.primaryContainer.withValues(alpha: 0.36)
            : colorScheme.surfaceContainerLow.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: calculated
              ? colorScheme.primary.withValues(alpha: 0.12)
              : colorScheme.outlineVariant.withValues(alpha: 0.52),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: calculated
                  ? colorScheme.primary
                  : colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.timelapse_rounded,
              size: 22,
              color: calculated
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
                  'Duración calculada',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: calculated
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
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

class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 18, color: colorScheme.error),
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
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 10),
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
