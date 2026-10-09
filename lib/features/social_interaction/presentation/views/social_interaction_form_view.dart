import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/social_interaction_category.dart';
import '../../domain/models/social_interaction_record.dart';
import '../../domain/repositories/social_interaction_repository.dart';
import '../../domain/services/social_interaction_record_factory.dart';
import '../viewmodels/social_interaction_form_view_model.dart';

class SocialInteractionFormView extends StatelessWidget {
  const SocialInteractionFormView({
    required this.repository,
    required this.recordFactory,
    required this.anonymousId,
    this.initialRecord,
    super.key,
  });

  final SocialInteractionRepository repository;

  final SocialInteractionRecordFactory recordFactory;

  final String anonymousId;

  final SocialInteractionRecord? initialRecord;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SocialInteractionFormViewModel(
        repository,
        recordFactory,
        anonymousId: anonymousId,
        initialRecord: initialRecord,
      ),
      child: const _SocialInteractionFormContent(),
    );
  }
}

class _SocialInteractionFormContent extends StatefulWidget {
  const _SocialInteractionFormContent();

  @override
  State<_SocialInteractionFormContent> createState() =>
      _SocialInteractionFormContentState();
}

class _SocialInteractionFormContentState
    extends State<_SocialInteractionFormContent> {
  static const Duration _validationMessageDuration = Duration(seconds: 4);

  final GlobalKey _dateSectionKey = GlobalKey();

  final GlobalKey _categorySectionKey = GlobalKey();

  final TextEditingController _contextController = TextEditingController();

  final TextEditingController _observationController = TextEditingController();

  Timer? _validationMessageTimer;

  bool _showValidationMessages = false;

  bool _didInitializeForm = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (_didInitializeForm) {
      return;
    }

    final viewModel = context.read<SocialInteractionFormViewModel>();

    _contextController.text = viewModel.initialContext;

    _observationController.text = viewModel.initialObservation;

    _didInitializeForm = true;
  }

  @override
  void dispose() {
    _validationMessageTimer?.cancel();

    _contextController.dispose();

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

  Future<void> _pickDate(SocialInteractionFormViewModel viewModel) async {
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

  Future<void> _save(SocialInteractionFormViewModel viewModel) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final isEditing = viewModel.isEditing;

    final success = await viewModel.save(
      context: _contextController.text,
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
      } else if (viewModel.errorFor('category') != null) {
        targetContext = _categorySectionKey.currentContext;
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

    if (!isEditing) {
      _contextController.clear();

      _observationController.clear();
    }

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Registro de interacción social actualizado correctamente.'
                : 'Registro de interacción social guardado correctamente.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

    Navigator.of(context).pop(isEditing ? true : null);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SocialInteractionFormViewModel>();

    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          viewModel.isEditing
              ? 'Editar registro de interacción social'
              : 'Registrar interacción social',
        ),
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
            _IntroCard(
              colorScheme: colorScheme,
              isEditing: viewModel.isEditing,
            ),
            const SizedBox(height: 20),
            KeyedSubtree(
              key: _dateSectionKey,
              child: _SectionCard(
                title: 'Cuándo ocurrió',
                subtitle:
                    'Selecciona la fecha correspondiente '
                    'al registro.',
                requiredField: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PickerButton(
                      key: const Key('social-interaction-date-picker'),
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
              key: _categorySectionKey,
              child: _SectionCard(
                title: 'Categoría de interacción',
                subtitle:
                    'Selecciona una categoría general '
                    'para clasificar el registro.',
                requiredField: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final category in SocialInteractionCategory.values)
                          ChoiceChip(
                            key: Key(
                              'social-interaction-category-'
                              '${category.code}',
                            ),
                            label: Text(category.label),
                            selected: viewModel.selectedCategory == category,
                            showCheckmark: false,
                            onSelected: viewModel.isSaving
                                ? null
                                : (_) {
                                    viewModel.setCategory(category);
                                  },
                          ),
                      ],
                    ),
                    if (_showValidationMessages &&
                        viewModel.errorFor('category') != null) ...[
                      const SizedBox(height: 10),
                      _FieldError(message: viewModel.errorFor('category')!),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: 'Contexto general (opcional)',
              subtitle:
                  'Describe brevemente dónde o bajo '
                  'qué situación ocurrió, solo si es necesario.',
              child: TextField(
                key: const Key('social-interaction-context-field'),
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
              title: 'Observación (opcional)',
              subtitle:
                  'Añade información descriptiva '
                  'complementaria solo si es necesaria.',
              child: TextField(
                key: const Key('social-interaction-observation-field'),
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
              key: const Key('social-interaction-save-button'),
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
                    : 'Guardar interacción social',
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
                child: Icon(Icons.people_outline, color: colorScheme.onPrimary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isEditing
                      ? 'Actualizar registro de interacción social'
                      : 'Registro de interacción social',
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
                ? 'Actualiza la fecha, la categoría, el contexto '
                      'o la observación del registro.'
                : 'Registra situaciones generales de '
                      'interacción social de forma clara '
                      'y descriptiva.',
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
                  'Sendaris no evalúa habilidades sociales '
                  'ni genera puntuaciones clínicas; este '
                  'registro es únicamente descriptivo.',
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
