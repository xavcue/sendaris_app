import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/atypical_situation_category.dart';
import '../../domain/models/atypical_situation_record.dart';
import '../../domain/repositories/atypical_situation_repository.dart';
import '../../domain/services/atypical_situation_record_factory.dart';
import '../viewmodels/atypical_situation_form_view_model.dart';

class AtypicalSituationFormView extends StatelessWidget {
  const AtypicalSituationFormView({
    required this.repository,
    required this.recordFactory,
    required this.anonymousId,
    this.initialRecord,
    super.key,
  });

  final AtypicalSituationRepository repository;
  final AtypicalSituationRecordFactory recordFactory;
  final String anonymousId;
  final AtypicalSituationRecord? initialRecord;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AtypicalSituationFormViewModel(
        repository,
        recordFactory,
        anonymousId: anonymousId,
        initialRecord: initialRecord,
      ),
      child: const _AtypicalSituationFormContent(),
    );
  }
}

class _AtypicalSituationFormContent extends StatefulWidget {
  const _AtypicalSituationFormContent();

  @override
  State<_AtypicalSituationFormContent> createState() =>
      _AtypicalSituationFormContentState();
}

class _AtypicalSituationFormContentState
    extends State<_AtypicalSituationFormContent> {
  static const Duration _validationMessageDuration = Duration(seconds: 4);

  final ScrollController _scrollController = ScrollController();

  final GlobalKey _dateSectionKey = GlobalKey();

  final GlobalKey _categorySectionKey = GlobalKey();

  final GlobalKey _observationSectionKey = GlobalKey();

  final GlobalKey _generalErrorKey = GlobalKey();

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

    final viewModel = context.read<AtypicalSituationFormViewModel>();

    _observationController.text = viewModel.initialObservation;

    _didInitializeForm = true;
  }

  @override
  void dispose() {
    _validationMessageTimer?.cancel();

    _scrollController.dispose();
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

  Future<void> _pickDate(AtypicalSituationFormViewModel viewModel) async {
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
      viewModel.selectDate(selected);
    }
  }

  Future<void> _save(AtypicalSituationFormViewModel viewModel) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final isEditing = viewModel.isEditing;

    final success = await viewModel.save(
      observation: _observationController.text,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      _showErrorsTemporarily();

      if (viewModel.errorFor('date') != null) {
        await _scrollToSection(_dateSectionKey, fallbackToEnd: false);

        return;
      }

      if (viewModel.errorFor('category') != null) {
        await _scrollToSection(_categorySectionKey, fallbackToEnd: false);

        return;
      }

      if (viewModel.errorFor('observation') != null) {
        await _scrollToSection(_observationSectionKey, fallbackToEnd: true);

        return;
      }

      if (viewModel.errorMessage != null) {
        await _scrollToSection(_generalErrorKey, fallbackToEnd: true);
      }

      return;
    }

    _validationMessageTimer?.cancel();

    if (!isEditing) {
      _observationController.clear();
    }

    final messenger = ScaffoldMessenger.of(context);

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            isEditing
                ? 'Registro de otra situación '
                      'actualizado correctamente.'
                : 'Situación guardada correctamente.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

    Navigator.of(context).pop(isEditing ? true : null);
  }

  Future<void> _scrollToSection(
    GlobalKey key, {
    required bool fallbackToEnd,
  }) async {
    var sectionContext = key.currentContext;

    if (sectionContext == null && _scrollController.hasClients) {
      final position = fallbackToEnd
          ? _scrollController.position.maxScrollExtent
          : _scrollController.position.minScrollExtent;

      await _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );

      if (!mounted) {
        return;
      }

      await WidgetsBinding.instance.endOfFrame;

      if (!mounted) {
        return;
      }

      sectionContext = key.currentContext;
    }

    if (sectionContext != null && sectionContext.mounted) {
      await Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AtypicalSituationFormViewModel>();

    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('atypical-situation-form-view'),
      appBar: AppBar(
        title: Text(
          viewModel.isEditing
              ? 'Editar registro de otra situación'
              : 'Registrar otra situación',
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
          controller: _scrollController,
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
                    'al acontecimiento.',
                requiredField: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _PickerButton(
                      key: const Key('atypical-situation-date-picker'),
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
                title: 'Qué ocurrió',
                subtitle:
                    'Selecciona la opción que mejor '
                    'describe la situación.',
                requiredField: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in AtypicalSituationCategory.values)
                          ChoiceChip(
                            key: Key(
                              'atypical-situation-category-'
                              '${category.code}',
                            ),
                            selected: viewModel.selectedCategory == category,
                            showCheckmark: false,
                            onSelected: viewModel.isSaving
                                ? null
                                : (_) {
                                    viewModel.selectCategory(category);
                                  },
                            label: Text(category.label),
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
            KeyedSubtree(
              key: _observationSectionKey,
              child: _SectionCard(
                title: 'Descripción',
                subtitle: viewModel.isEditing
                    ? 'Actualiza brevemente qué sucedió.'
                    : 'Describe brevemente qué sucedió.',
                requiredField: true,
                child: TextField(
                  key: const Key('atypical-situation-observation-field'),
                  controller: _observationController,
                  enabled: !viewModel.isSaving,
                  minLines: 4,
                  maxLines: 7,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText:
                        'Ej. La actividad prevista '
                        'se realizó en un lugar diferente.',
                    hintMaxLines: 2,
                    prefixIcon: const Icon(Icons.notes_outlined),
                    errorText: _showValidationMessages
                        ? viewModel.errorFor('observation')
                        : null,
                  ),
                ),
              ),
            ),
            if (_showValidationMessages && viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),
              KeyedSubtree(
                key: _generalErrorKey,
                child: _GeneralErrorCard(message: viewModel.errorMessage!),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const Key('atypical-situation-save-button'),
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
                    : 'Guardar situación',
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
                child: Icon(
                  Icons.event_note_outlined,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isEditing
                      ? 'Actualizar registro de otra situación'
                      : 'Registro de otra situación',
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
                ? 'Actualiza la fecha, la categoría y '
                      'la descripción del registro.'
                : 'Utiliza este registro para una situación '
                      'relevante que no encaje en las demás opciones.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'La información se guardará '
                  'en el seguimiento actual.',
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
