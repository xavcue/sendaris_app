import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/atypical_situation_category.dart';
import '../../domain/repositories/atypical_situation_repository.dart';
import '../../domain/services/atypical_situation_record_factory.dart';
import '../viewmodels/atypical_situation_form_view_model.dart';

class AtypicalSituationFormView extends StatelessWidget {
  const AtypicalSituationFormView({
    required this.repository,
    required this.recordFactory,
    required this.anonymousId,
    super.key,
  });

  final AtypicalSituationRepository repository;
  final AtypicalSituationRecordFactory recordFactory;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AtypicalSituationFormViewModel(
        repository,
        recordFactory,
        anonymousId: anonymousId,
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
  final GlobalKey _categorySectionKey = GlobalKey();

  final GlobalKey _observationSectionKey = GlobalKey();

  final GlobalKey _generalErrorKey = GlobalKey();

  final TextEditingController _observationController = TextEditingController();

  @override
  void dispose() {
    _observationController.dispose();

    super.dispose();
  }

  Future<void> _pickDate(AtypicalSituationFormViewModel viewModel) async {
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

  Future<void> _save(AtypicalSituationFormViewModel viewModel) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final success = await viewModel.save(
      observation: _observationController.text,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      if (viewModel.errorFor('category') != null) {
        _scrollToSection(_categorySectionKey);

        return;
      }

      if (viewModel.errorFor('observation') != null) {
        _scrollToSection(_observationSectionKey);

        return;
      }

      if (viewModel.errorMessage != null) {
        _scrollToSection(_generalErrorKey);
      }

      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Situación guardada correctamente.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

    Navigator.of(context).pop(true);
  }

  void _scrollToSection(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final sectionContext = key.currentContext;

      if (sectionContext == null || !sectionContext.mounted) {
        return;
      }

      Scrollable.ensureVisible(
        sectionContext,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<AtypicalSituationFormViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar situación'),
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
              subtitle: 'Selecciona la fecha correspondiente.',
              requiredField: true,
              child: _DatePickerButton(
                key: const Key('atypical-situation-date-picker'),
                value: _formatDate(viewModel.selectedDate),
                onPressed: viewModel.isSaving
                    ? null
                    : () => _pickDate(viewModel),
              ),
            ),

            const SizedBox(height: 16),

            KeyedSubtree(
              key: _categorySectionKey,
              child: _SectionCard(
                title: '¿Qué ocurrió?',
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
                              'atypical-situation-category-${category.code}',
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

                    if (viewModel.errorFor('category') != null) ...[
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
                subtitle: 'Cuenta brevemente qué sucedió.',
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
                    labelText: 'Describe lo ocurrido',
                    hintText:
                        'Ej. La actividad prevista '
                        'se realizó en un lugar diferente.',
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(Icons.notes_outlined),
                    errorText: viewModel.errorFor('observation'),
                  ),
                ),
              ),
            ),

            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),

              KeyedSubtree(
                key: _generalErrorKey,
                child: _GeneralErrorCard(message: viewModel.errorMessage!),
              ),
            ],

            const SizedBox(height: 24),

            FilledButton.icon(
              key: const Key('atypical-situation-save-button'),
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
                viewModel.isSaving ? 'Guardando...' : 'Guardar situación',
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
                  Icons.event_note_outlined,
                  color: colorScheme.onPrimary,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  'Añade un acontecimiento',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            'Utiliza este registro para una situación '
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
              Icon(Icons.info_outline, size: 20, color: colorScheme.primary),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  'La información se guardará '
                  'en el perfil activo.',
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

class _DatePickerButton extends StatelessWidget {
  const _DatePickerButton({
    required this.value,
    required this.onPressed,
    super.key,
  });

  final String value;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: colorScheme.primary),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fecha',
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

              Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
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
