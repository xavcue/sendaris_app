import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../routine/domain/models/routine.dart';
import '../../../routine/domain/repositories/routine_repository.dart';
import '../../domain/models/routine_status.dart';
import '../../domain/models/routine_status_record.dart';
import '../../domain/repositories/routine_status_repository.dart';
import '../../domain/services/routine_status_record_factory.dart';
import '../viewmodels/routine_status_form_view_model.dart';

class RoutineStatusFormView extends StatelessWidget {
  const RoutineStatusFormView({
    required this.routineRepository,
    required this.routineStatusRepository,
    required this.recordFactory,
    required this.anonymousId,
    this.initialRecord,
    super.key,
  });

  final RoutineRepository routineRepository;
  final RoutineStatusRepository routineStatusRepository;
  final RoutineStatusRecordFactory recordFactory;
  final String anonymousId;
  final RoutineStatusRecord? initialRecord;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RoutineStatusFormViewModel(
        routineRepository,
        routineStatusRepository,
        recordFactory,
        anonymousId: anonymousId,
        initialRecord: initialRecord,
      )..initialize(),
      child: _RoutineStatusFormContent(initialRecord: initialRecord),
    );
  }
}

class _RoutineStatusFormContent extends StatefulWidget {
  const _RoutineStatusFormContent({required this.initialRecord});

  final RoutineStatusRecord? initialRecord;

  @override
  State<_RoutineStatusFormContent> createState() =>
      _RoutineStatusFormContentState();
}

class _RoutineStatusFormContentState extends State<_RoutineStatusFormContent> {
  static const Duration _validationMessageDuration = Duration(seconds: 4);

  final GlobalKey _generalErrorKey = GlobalKey();
  final GlobalKey _routineSectionKey = GlobalKey();
  final GlobalKey _dateSectionKey = GlobalKey();
  final GlobalKey _statusSectionKey = GlobalKey();

  late final TextEditingController _observationController;

  Timer? _validationMessageTimer;

  bool _showValidationMessages = false;

  @override
  void initState() {
    super.initState();

    _observationController = TextEditingController(
      text: widget.initialRecord?.observation ?? '',
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

  Future<void> _pickRoutine(RoutineStatusFormViewModel viewModel) async {
    final selectedRoutine = await showModalBottomSheet<Routine>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.55,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return _RoutineSelectorSheet(
              routines: viewModel.routines,
              selectedRoutineId: viewModel.selectedRoutineId,
              scrollController: scrollController,
            );
          },
        );
      },
    );

    if (!mounted || selectedRoutine == null) {
      return;
    }

    if (selectedRoutine.routineId == viewModel.selectedRoutineId) {
      return;
    }

    viewModel.selectRoutine(selectedRoutine.routineId);
  }

  Future<void> _pickDate(RoutineStatusFormViewModel viewModel) async {
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
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
    });
  }

  Future<void> _save(RoutineStatusFormViewModel viewModel) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final isEditing = viewModel.isEditing;

    viewModel.setObservation(_observationController.text);

    final success = await viewModel.save();

    if (!mounted) {
      return;
    }

    if (!success) {
      _showErrorsTemporarily();

      if (viewModel.routineError != null) {
        _scrollToSection(_routineSectionKey);
      } else if (viewModel.dateError != null) {
        _scrollToSection(_dateSectionKey);
      } else if (viewModel.statusError != null) {
        _scrollToSection(_statusSectionKey);
      } else if (viewModel.errorMessage != null) {
        _scrollToSection(_generalErrorKey);
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
                ? 'Estado de rutina actualizado correctamente.'
                : 'Estado de rutina guardado correctamente.',
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

    Navigator.of(context).pop(isEditing ? true : null);
  }

  Routine? _selectedRoutine(RoutineStatusFormViewModel viewModel) {
    final selectedRoutineId = viewModel.selectedRoutineId;

    if (selectedRoutineId == null) {
      return null;
    }

    for (final routine in viewModel.routines) {
      if (routine.routineId == selectedRoutineId) {
        return routine;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RoutineStatusFormViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final selectedRoutine = _selectedRoutine(viewModel);

    return Scaffold(
      key: Key(
        viewModel.isEditing
            ? 'routine-status-edit-view'
            : 'routine-status-create-view',
      ),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          viewModel.isEditing
              ? 'Editar registro de estado de rutina'
              : 'Registrar estado de rutina',
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
        child: viewModel.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _IntroCard(
                      colorScheme: colorScheme,
                      isEditing: viewModel.isEditing,
                    ),
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
                        title: 'Rutina',
                        subtitle: viewModel.isEditing
                            ? 'Revisa o cambia la rutina asociada a este estado.'
                            : 'Selecciona la rutina cuyo estado deseas registrar.',
                        requiredField: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!viewModel.hasRoutines)
                              const _NoRoutinesCard()
                            else
                              _RoutinePickerButton(
                                key: const Key('routine-status-routine-picker'),
                                routine: selectedRoutine,
                                enabled: !viewModel.isSaving,
                                onPressed: () {
                                  _pickRoutine(viewModel);
                                },
                              ),
                            if (_showValidationMessages &&
                                viewModel.routineError != null) ...[
                              const SizedBox(height: 8),
                              _FieldError(message: viewModel.routineError!),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    KeyedSubtree(
                      key: _dateSectionKey,
                      child: _SectionCard(
                        title: 'Fecha del registro',
                        subtitle:
                            'Indica la fecha a la que corresponde el estado.',
                        requiredField: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _PickerButton(
                              key: const Key('routine-status-date-picker'),
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
                                viewModel.dateError != null) ...[
                              const SizedBox(height: 8),
                              _FieldError(message: viewModel.dateError!),
                            ],
                          ],
                        ),
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
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                for (final status in RoutineStatus.values)
                                  ChoiceChip(
                                    key: Key('routine-status-${status.code}'),
                                    selected:
                                        viewModel.selectedStatus == status,
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
                            if (_showValidationMessages &&
                                viewModel.statusError != null) ...[
                              const SizedBox(height: 10),
                              _FieldError(message: viewModel.statusError!),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Observación (opcional)',
                      subtitle:
                          'Añade información descriptiva complementaria '
                          'solo si es necesaria.',
                      child: TextField(
                        key: const Key('routine-status-observation-field'),
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
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      key: const Key('routine-status-save-button'),
                      onPressed: viewModel.isSaving || !viewModel.hasRoutines
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
                            : 'Guardar estado',
                      ),
                    ),
                  ],
                ),
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

class _RoutineSelectorSheet extends StatefulWidget {
  const _RoutineSelectorSheet({
    required this.routines,
    required this.selectedRoutineId,
    required this.scrollController,
  });

  final List<Routine> routines;
  final String? selectedRoutineId;
  final ScrollController scrollController;

  @override
  State<_RoutineSelectorSheet> createState() => _RoutineSelectorSheetState();
}

class _RoutineSelectorSheetState extends State<_RoutineSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  List<Routine> get _filteredRoutines {
    final normalizedQuery = _query.trim().toLowerCase();

    if (normalizedQuery.isEmpty) {
      return widget.routines;
    }

    return widget.routines
        .where(
          (routine) => routine.name.toLowerCase().contains(normalizedQuery),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final routines = _filteredRoutines;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Seleccionar rutina',
                key: const Key('routine-selector-title'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Busca y selecciona la rutina correspondiente.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const Key('routine-selector-search-field'),
                controller: _searchController,
                autofocus: false,
                onChanged: (value) {
                  setState(() {
                    _query = value;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar rutina',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          key: const Key('routine-selector-clear-search'),
                          tooltip: 'Limpiar búsqueda',
                          onPressed: () {
                            _searchController.clear();

                            setState(() {
                              _query = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: routines.isEmpty
              ? const _RoutineSelectorEmptyState()
              : ListView.separated(
                  key: const Key('routine-selector-list'),
                  controller: widget.scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  itemCount: routines.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final routine = routines[index];

                    final selected =
                        routine.routineId == widget.selectedRoutineId;

                    return Material(
                      color: selected
                          ? colorScheme.primaryContainer.withValues(alpha: 0.55)
                          : colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        key: Key(
                          'routine-selector-option-'
                          '${routine.routineId}',
                        ),
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.of(context).pop(routine);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
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
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    if (routine.scheduledTime != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        routine.scheduledTime!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (selected)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _RoutineSelectorEmptyState extends StatelessWidget {
  const _RoutineSelectorEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      key: const Key('routine-selector-empty-state'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 42,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No se encontraron rutinas',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Prueba con otro nombre.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
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
      key: const Key('routine-status-intro-card'),
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
                  isEditing
                      ? Icons.edit_outlined
                      : Icons.event_available_outlined,
                  color: colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isEditing
                      ? 'Actualizar registro de estado de rutina'
                      : 'Registro de estado de rutina',
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
                ? 'Revisa y modifica únicamente la información '
                      'necesaria del estado registrado.'
                : 'Registra de forma descriptiva qué ocurrió '
                      'con una rutina en una fecha determinada.',
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
              'No hay rutinas disponibles. '
              'Crea una rutina antes de registrar su estado.',
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
            const SizedBox(height: 6),
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

class _RoutinePickerButton extends StatelessWidget {
  const _RoutinePickerButton({
    required this.routine,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final Routine? routine;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final selectedRoutine = routine;

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.checklist_rounded,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: selectedRoutine == null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Sin seleccionar',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Toca para elegir una rutina',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            selectedRoutine.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (selectedRoutine.scheduledTime != null) ...[
                            const SizedBox(height: 3),
                            Text(
                              selectedRoutine.scheduledTime!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
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
        minimumSize: const Size.fromHeight(74),
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
        Icon(Icons.error_outline_rounded, size: 18, color: colorScheme.error),
        const SizedBox(width: 6),
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
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
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
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
