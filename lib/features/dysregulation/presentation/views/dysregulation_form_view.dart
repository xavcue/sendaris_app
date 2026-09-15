import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/dysregulation_intensity.dart';
import '../../domain/repositories/dysregulation_repository.dart';
import '../../domain/services/dysregulation_record_factory.dart';
import '../viewmodels/dysregulation_form_view_model.dart';

class DysregulationFormView extends StatelessWidget {
  const DysregulationFormView({
    required this.repository,
    required this.recordFactory,
    required this.anonymousId,
    super.key,
  });

  final DysregulationRepository repository;
  final DysregulationRecordFactory recordFactory;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DysregulationFormViewModel(
        repository,
        recordFactory,
        anonymousId: anonymousId,
      ),
      child: const _DysregulationFormContent(),
    );
  }
}

class _DysregulationFormContent extends StatefulWidget {
  const _DysregulationFormContent();

  @override
  State<_DysregulationFormContent> createState() =>
      _DysregulationFormContentState();
}

class _DysregulationFormContentState extends State<_DysregulationFormContent> {
  final ScrollController _scrollController = ScrollController();

  final GlobalKey _durationFieldAnchorKey = GlobalKey();

  final FocusNode _durationFocusNode = FocusNode();

  final TextEditingController _durationController = TextEditingController();

  final TextEditingController _contextController = TextEditingController();

  final TextEditingController _observationController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _durationFocusNode.dispose();

    _durationController.dispose();
    _contextController.dispose();
    _observationController.dispose();

    super.dispose();
  }

  Future<void> _pickDate(DysregulationFormViewModel viewModel) async {
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

  Future<void> _pickTime(DysregulationFormViewModel viewModel) async {
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

  Future<void> _save(DysregulationFormViewModel viewModel) async {
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
      await _showFirstValidationError(viewModel);

      return;
    }

    _durationController.clear();
    _contextController.clear();
    _observationController.clear();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Episodio de desregulación guardado correctamente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _showFirstValidationError(
    DysregulationFormViewModel viewModel,
  ) async {
    if (viewModel.errorFor('durationMinutes') != null) {
      await _bringDurationErrorIntoView();
    }
  }

  Future<void> _bringDurationErrorIntoView() async {
    if (_durationFieldAnchorKey.currentContext == null &&
        _scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.minScrollExtent);

      await WidgetsBinding.instance.endOfFrame;
    }

    if (!mounted) {
      return;
    }

    var fieldContext = _durationFieldAnchorKey.currentContext;

    if (fieldContext != null && fieldContext.mounted) {
      await Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.22,
      );
    }

    if (!mounted) {
      return;
    }

    _durationFocusNode.requestFocus();

    await WidgetsBinding.instance.endOfFrame;

    if (!mounted) {
      return;
    }

    fieldContext = _durationFieldAnchorKey.currentContext;

    if (fieldContext != null && fieldContext.mounted) {
      await Scrollable.ensureVisible(
        fieldContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: 0.18,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DysregulationFormViewModel>();

    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar desregulación'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _IntroCard(colorScheme: colorScheme),

            const SizedBox(height: 20),

            _SectionCard(
              title: 'Cuándo ocurrió',
              subtitle:
                  'Selecciona la fecha y, si la conoces, '
                  'también la hora.',
              requiredField: true,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _PickerButton(
                          key: const Key('dysregulation-date-picker'),
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
                          key: const Key('dysregulation-time-picker'),
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
                        key: const Key('dysregulation-clear-time-button'),
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

            _SectionCard(
              title: 'Detalles del episodio',
              subtitle:
                  'Completa solo la información '
                  'descriptiva que corresponda.',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyedSubtree(
                    key: _durationFieldAnchorKey,
                    child: TextField(
                      key: const Key('dysregulation-duration-field'),
                      focusNode: _durationFocusNode,
                      controller: _durationController,
                      enabled: !viewModel.isSaving,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: viewModel.validateDurationCorrection,
                      decoration: InputDecoration(
                        labelText: 'Duración (opcional)',
                        hintText: 'Ej. 12',
                        suffixText: 'min',
                        prefixIcon: const Icon(Icons.timer_outlined),
                        errorText: viewModel.errorFor('durationMinutes'),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    'Intensidad descriptiva '
                    '(opcional)',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Describe únicamente la intensidad '
                    'observada. No corresponde a una '
                    'valoración clínica.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final intensity in DysregulationIntensity.values)
                        FilterChip(
                          key: Key(
                            'dysregulation-intensity-'
                            '${intensity.code}',
                          ),
                          selected: viewModel.selectedIntensity == intensity,
                          showCheckmark: false,
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

            _SectionCard(
              title: 'Contexto general',
              subtitle:
                  'Describe brevemente dónde o bajo '
                  'qué situación ocurrió, solo si es '
                  'necesario.',
              child: TextField(
                key: const Key('dysregulation-context-field'),
                controller: _contextController,
                enabled: !viewModel.isSaving,
                minLines: 2,
                maxLines: 3,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  hintText: 'Ej. Durante una actividad cotidiana',
                  hintMaxLines: 2,
                  prefixIcon: Icon(Icons.place_outlined),
                ),
              ),
            ),

            const SizedBox(height: 16),

            _SectionCard(
              title: 'Observación',
              subtitle:
                  'Añade información descriptiva '
                  'complementaria solo si es '
                  'necesaria.',
              child: TextField(
                key: const Key('dysregulation-observation-field'),
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

            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),

              _GeneralErrorCard(message: viewModel.errorMessage!),
            ],

            const SizedBox(height: 24),

            FilledButton.icon(
              key: const Key('dysregulation-save-button'),
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
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(
                viewModel.isSaving ? 'Guardando...' : 'Guardar episodio',
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'La fecha es obligatoria. Los demás '
              'datos se completan solo cuando '
              'corresponda.',
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
                  Icons.sentiment_dissatisfied_outlined,
                  color: colorScheme.onPrimary,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  'Registro de desregulación',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            'Registra un episodio de forma clara '
            'y descriptiva utilizando únicamente '
            'la información observada.',
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
                  'Sendaris no determina causas, '
                  'diagnósticos ni recomendaciones. '
                  'La intensidad registrada es '
                  'únicamente descriptiva.',
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

class _GeneralErrorCard extends StatelessWidget {
  const _GeneralErrorCard({required this.message});

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
