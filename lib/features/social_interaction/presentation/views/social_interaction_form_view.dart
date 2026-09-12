import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/social_interaction_category.dart';
import '../../domain/repositories/social_interaction_repository.dart';
import '../../domain/services/social_interaction_record_factory.dart';
import '../viewmodels/social_interaction_form_view_model.dart';

class SocialInteractionFormView extends StatelessWidget {
  const SocialInteractionFormView({
    required this.repository,
    required this.recordFactory,
    required this.anonymousId,
    super.key,
  });

  final SocialInteractionRepository repository;
  final SocialInteractionRecordFactory recordFactory;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SocialInteractionFormViewModel(
        repository,
        recordFactory,
        anonymousId: anonymousId,
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
  final TextEditingController _contextController = TextEditingController();
  final TextEditingController _observationController = TextEditingController();

  @override
  void dispose() {
    _contextController.dispose();
    _observationController.dispose();

    super.dispose();
  }

  Future<void> _pickDate(SocialInteractionFormViewModel viewModel) async {
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

  Future<void> _save(SocialInteractionFormViewModel viewModel) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final success = await viewModel.save(
      context: _contextController.text,
      observation: _observationController.text,
    );

    if (!mounted || !success) {
      return;
    }

    _contextController.clear();
    _observationController.clear();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Registro de interacción social guardado correctamente.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SocialInteractionFormViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar interacción social'),
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
              subtitle: 'Selecciona la fecha correspondiente al registro.',
              requiredField: true,
              child: _PickerButton(
                key: const Key('social-interaction-date-picker'),
                icon: Icons.calendar_today_outlined,
                label: 'Fecha',
                value: _formatDate(viewModel.selectedDate),
                onPressed: viewModel.isSaving
                    ? null
                    : () => _pickDate(viewModel),
              ),
            ),

            const SizedBox(height: 16),

            _SectionCard(
              title: 'Categoría de interacción',
              subtitle: 'Selecciona una categoría general para clasificar el registro.',
              requiredField: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: SocialInteractionCategory.values
                        .map((category) {
                          return ChoiceChip(
                            key: Key(
                              'social-interaction-category-${category.code}',
                            ),
                            label: Text(category.label),
                            selected: viewModel.selectedCategory == category,
                            showCheckmark: false,
                            onSelected: viewModel.isSaving
                                ? null
                                : (selected) {
                                    if (selected) {
                                      viewModel.setCategory(category);
                                    }
                                  },
                          );
                        })
                        .toList(growable: false),
                  ),

                  if (viewModel.errorFor('category') != null) ...[
                    const SizedBox(height: 10),
                    _FieldError(message: viewModel.errorFor('category')!),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),

            _SectionCard(
              title: 'Contexto general',
              subtitle: 'Describe brevemente dónde o bajo qué situación ocurrió, solo si es necesario.',
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
              title: 'Observación',
              subtitle: 'Añade información descriptiva complementaria solo si es necesaria.',
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

            if (viewModel.errorMessage != null) ...[
              const SizedBox(height: 16),

              _GeneralErrorCard(message: viewModel.errorMessage!),
            ],

            const SizedBox(height: 24),

            FilledButton.icon(
              key: const Key('social-interaction-save-button'),
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
                viewModel.isSaving
                    ? 'Guardando...'
                    : 'Guardar interacción social',
              ),
            ),

            const SizedBox(height: 12),

            Text(
              'Los campos indicados como obligatorios deben completarse.',
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
                child: Icon(Icons.people_outline, color: colorScheme.onPrimary),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Text(
                  'Registro de interacción social',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            'Registra situaciones generales de interacción social de forma clara y descriptiva.',
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
                  'Sendaris no evalúa habilidades sociales ni genera puntuaciones clínicas; este registro es únicamente descriptivo.',
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

class _FieldError extends StatelessWidget {
  const _FieldError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, size: 18, color: colorScheme.error),

        const SizedBox(width: 7),

        Expanded(
          child: Text(
            message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.error,
            ),
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
