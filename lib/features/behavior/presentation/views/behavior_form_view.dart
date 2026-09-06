import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/behavior_category.dart';
import '../../domain/models/behavior_intensity.dart';
import '../../domain/repositories/behavior_repository.dart';
import '../../domain/services/behavior_record_factory.dart';
import '../viewmodels/behavior_form_view_model.dart';

class BehaviorFormView extends StatelessWidget {
  const BehaviorFormView({
    required this.repository,
    required this.recordFactory,
    required this.anonymousId,
    super.key,
  });

  final BehaviorRepository repository;
  final BehaviorRecordFactory recordFactory;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BehaviorFormViewModel(
        repository,
        recordFactory,
        anonymousId: anonymousId,
      ),
      child: const _BehaviorFormContent(),
    );
  }
}

class _BehaviorFormContent extends StatefulWidget {
  const _BehaviorFormContent();

  @override
  State<_BehaviorFormContent> createState() => _BehaviorFormContentState();
}

class _BehaviorFormContentState extends State<_BehaviorFormContent> {
  final GlobalKey _categorySectionKey = GlobalKey();

  final TextEditingController _durationController = TextEditingController();

  final TextEditingController _contextController = TextEditingController();

  final TextEditingController _observationController = TextEditingController();

  @override
  void dispose() {
    _durationController.dispose();
    _contextController.dispose();
    _observationController.dispose();

    super.dispose();
  }

  Future<void> _pickDate(BehaviorFormViewModel viewModel) async {
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
      viewModel.setDate(selected);
    }
  }

  Future<void> _pickTime(BehaviorFormViewModel viewModel) async {
    final currentTime = _timeOfDayFromString(viewModel.selectedTime);

    final selected = await showTimePicker(
      context: context,
      initialTime: currentTime ?? TimeOfDay.now(),
      helpText: 'Seleccionar hora',
      cancelText: 'Cancelar',
      confirmText: 'Seleccionar',
    );

    if (selected != null) {
      viewModel.setTime(hour: selected.hour, minute: selected.minute);
    }
  }

  Future<void> _save(BehaviorFormViewModel viewModel) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final success = await viewModel.save(
      durationText: _durationController.text,
      context: _contextController.text,
      observation: _observationController.text,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      if (viewModel.errorFor('category') != null) {
        final categoryContext = _categorySectionKey.currentContext;

        if (categoryContext != null && categoryContext.mounted) {
          await Scrollable.ensureVisible(
            categoryContext,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
            alignment: 0.15,
          );
        }
      }

      return;
    }

    _durationController.clear();
    _contextController.clear();
    _observationController.clear();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Conducta guardada correctamente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<BehaviorFormViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar conducta'),
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
            _IntroCard(colorScheme: colorScheme),

            const SizedBox(height: 20),

            _SectionCard(
              title: 'Cuándo ocurrió',
              subtitle:
                  'Registra la fecha y, si la '
                  'conoces, también la hora.',
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _PickerButton(
                          key: const Key('behavior-date-picker'),
                          icon: Icons.calendar_today_outlined,
                          label: 'Fecha',
                          value: _formatDate(viewModel.selectedDate),
                          onPressed: viewModel.isSaving
                              ? null
                              : () => _pickDate(viewModel),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: _PickerButton(
                          key: const Key('behavior-time-picker'),
                          icon: Icons.schedule_outlined,
                          label: 'Hora',
                          value: viewModel.selectedTime ?? 'Opcional',
                          onPressed: viewModel.isSaving
                              ? null
                              : () => _pickTime(viewModel),
                        ),
                      ),
                    ],
                  ),

                  if (viewModel.selectedTime != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: viewModel.isSaving
                            ? null
                            : viewModel.clearTime,
                        icon: const Icon(Icons.close, size: 18),
                        label: const Text('Quitar hora'),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            KeyedSubtree(
              key: _categorySectionKey,
              child: _SectionCard(
                title: 'Qué observaste',
                subtitle:
                    'Selecciona la categoría que '
                    'mejor describe el registro.',
                requiredField: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in BehaviorCategory.values)
                          ChoiceChip(
                            key: Key(
                              'behavior-category-'
                              '${category.code}',
                            ),
                            selected: viewModel.selectedCategory == category,
                            onSelected: viewModel.isSaving
                                ? null
                                : (_) {
                                    viewModel.setCategory(category);
                                  },
                            label: Text(category.label),
                          ),
                      ],
                    ),

                    if (viewModel.errorFor('category') != null) ...[
                      const SizedBox(height: 8),

                      _FieldError(message: viewModel.errorFor('category')!),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            _SectionCard(
              title: 'Detalles del registro',
              subtitle:
                  'Completa solo la información '
                  'que aplique al acontecimiento.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    key: const Key('behavior-duration-field'),
                    controller: _durationController,
                    enabled: !viewModel.isSaving,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Duración (opcional)',
                      hintText: 'Ej. 12',
                      suffixText: 'min',
                      prefixIcon: const Icon(Icons.timer_outlined),
                      errorText: viewModel.errorFor('durationMinutes'),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Intensidad descriptiva '
                    '(opcional)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Describe la intensidad '
                    'observada; no corresponde '
                    'a una valoración clínica.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final intensity in BehaviorIntensity.values)
                        FilterChip(
                          key: Key(
                            'behavior-intensity-'
                            '${intensity.code}',
                          ),
                          selected: viewModel.selectedIntensity == intensity,
                          onSelected: viewModel.isSaving
                              ? null
                              : (_) {
                                  viewModel.setIntensity(intensity);
                                },
                          label: Text(intensity.label),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: ExpansionTile(
                key: const Key('behavior-optional-details'),

                // Evita las líneas superior e inferior
                // que Material 3 agrega al expandir.
                shape: const RoundedRectangleBorder(),
                collapsedShape: const RoundedRectangleBorder(),

                leading: const Icon(Icons.notes_outlined),
                title: const Text('Detalles opcionales'),
                subtitle: const Text('Contexto y observaciones'),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                children: [
                  TextField(
                    key: const Key('behavior-context-field'),
                    controller: _contextController,
                    enabled: !viewModel.isSaving,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Contexto',
                      hintText:
                          'Ej. Durante una '
                          'actividad cotidiana',
                      prefixIcon: Icon(Icons.place_outlined),
                    ),
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    key: const Key('behavior-observation-field'),
                    controller: _observationController,
                    enabled: !viewModel.isSaving,
                    minLines: 3,
                    maxLines: 5,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: 'Observación',
                      hintText:
                          'Añade información '
                          'descriptiva si es '
                          'necesario.',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                  ),
                ],
              ),
            ),

            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),

              _GeneralErrorCard(message: viewModel.errorMessage!),
            ],

            const SizedBox(height: 24),

            FilledButton.icon(
              key: const Key('behavior-save-button'),
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
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                viewModel.isSaving ? 'Guardando...' : 'Guardar conducta',
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
                  Icons.edit_note_rounded,
                  color: colorScheme.onPrimary,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  'Nuevo registro',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            'Añade información descriptiva '
            'sobre la conducta observada. '
            'Puedes omitir los detalles que '
            'no apliquen.',
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
                  'El registro se asociará al '
                  'seguimiento anónimo activo.',
                  style: theme.textTheme.bodySmall,
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
                    requiredField ? '$title *' : title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
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

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),

            const SizedBox(height: 10),

            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 2),

            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
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
          child: Text(
            message,
            style: TextStyle(color: colorScheme.error, fontSize: 12),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(14),
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
