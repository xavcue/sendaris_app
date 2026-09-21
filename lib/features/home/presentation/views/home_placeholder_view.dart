import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/animation/animated_entrance.dart';
import '../../../../app/animation/animated_pressable_scale.dart';
import '../../../../app/theme/ambient_background.dart';
import '../../../../app/theme/sendaris_section_label.dart';
import '../../../../app/theme/theme_mode_controller.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../tracking/domain/models/anonymous_tracking_profile.dart';
import '../../../tracking/presentation/viewmodels/tracking_view_model.dart';

class HomePlaceholderView extends StatefulWidget {
  const HomePlaceholderView({required this.trackingViewModel, super.key});

  final TrackingViewModel trackingViewModel;

  @override
  State<HomePlaceholderView> createState() => _HomePlaceholderViewState();
}

class _HomePlaceholderViewState extends State<HomePlaceholderView> {
  late final AmbientBackgroundController _ambientBackgroundController;

  @override
  void initState() {
    super.initState();

    _ambientBackgroundController = AmbientBackgroundController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.trackingViewModel.initialize();
    });
  }

  @override
  void dispose() {
    _ambientBackgroundController.dispose();

    super.dispose();
  }

  Future<void> _openRegister() async {
    await context.push<void>('/register');

    if (!mounted) {
      return;
    }

    _ambientBackgroundController.replay();
  }

  Future<void> _openRoutines() async {
    await context.push<void>('/routines');

    if (!mounted) {
      return;
    }

    _ambientBackgroundController.replay();
  }

  Future<void> _openHistory() async {
    await context.push<void>('/history');

    if (!mounted) {
      return;
    }

    _ambientBackgroundController.replay();
  }

  Future<void> _openFrequencies() async {
    await context.push<void>('/frequencies');

    if (!mounted) {
      return;
    }

    _ambientBackgroundController.replay();
  }

  Future<void> _openDurations() async {
    await context.push<void>('/durations');

    if (!mounted) {
      return;
    }

    _ambientBackgroundController.replay();
  }

  Future<void> _openRoutineCompliance() async {
    await context.push<void>('/routine-compliance');

    if (!mounted) {
      return;
    }

    _ambientBackgroundController.replay();
  }

  Future<void> _showTrackingSelector(TrackingViewModel viewModel) async {
    final resultMessage = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) {
        return ChangeNotifierProvider<TrackingViewModel>.value(
          value: viewModel,
          child: const _TrackingSelectorSheet(),
        );
      },
    );

    if (!mounted || resultMessage == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(resultMessage)));

    _ambientBackgroundController.replay();
  }

  void _toggleTheme(Brightness brightness) {
    final controller = context.read<ThemeModeController?>();

    controller?.toggle(brightness);
  }

  @override
  Widget build(BuildContext context) {
    final trackingViewModel = context.watch<TrackingViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final themeModeController = context.read<ThemeModeController?>();

    return AmbientBackground(
      controller: _ambientBackgroundController,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          toolbarHeight: 80,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          titleSpacing: 20,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  'assets/branding/sendaris_app_icon.png',
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Sendaris',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.65,
                ),
              ),
            ],
          ),
          actions: [
            if (themeModeController != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: IconButton(
                  tooltip: isDark ? 'Usar modo claro' : 'Usar modo oscuro',
                  style: IconButton.styleFrom(
                    backgroundColor: colorScheme.surface.withValues(
                      alpha: isDark ? 0.72 : 0.68,
                    ),
                    foregroundColor: colorScheme.onSurface,
                    side: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.56),
                    ),
                  ),
                  onPressed: () {
                    _toggleTheme(theme.brightness);
                  },
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      );
                    },
                    child: Icon(
                      isDark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_rounded,
                      key: ValueKey<bool>(isDark),
                      size: 20,
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                tooltip: 'Cerrar sesión',
                style: IconButton.styleFrom(
                  backgroundColor: colorScheme.surface.withValues(
                    alpha: isDark ? 0.72 : 0.68,
                  ),
                  foregroundColor: colorScheme.onSurface,
                  side: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.56),
                  ),
                ),
                onPressed: trackingViewModel.isLoading
                    ? null
                    : () async {
                        final authViewModel = context.read<AuthViewModel>();

                        final success = await authViewModel.signOut();

                        if (!success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                authViewModel.errorMessage ??
                                    'No fue posible cerrar la sesión.',
                              ),
                            ),
                          );
                        }
                      },
                icon: const Icon(Icons.logout_rounded, size: 20),
              ),
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: _buildBody(context, trackingViewModel),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, TrackingViewModel viewModel) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (viewModel.isLoading && !viewModel.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!viewModel.hasActiveProfile) {
      if (viewModel.errorMessage != null) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: AnimatedEntrance(
              beginScale: 0.98,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.cloud_off_outlined,
                      size: 30,
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'No pudimos preparar los seguimientos',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    viewModel.errorMessage!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: viewModel.isLoading
                        ? null
                        : viewModel.initialize,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: AnimatedEntrance(
            beginScale: 0.98,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.58),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.layers_outlined,
                    size: 32,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Aún no tienes seguimientos',
                  key: const Key('home-empty-tracking-title'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Crea un seguimiento para comenzar.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('home-empty-create-tracking-button'),
                  onPressed: viewModel.isLoading
                      ? null
                      : () async {
                          final success = await viewModel
                              .createAndPersistProfile();

                          if (!context.mounted || !success) {
                            return;
                          }

                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(
                                  viewModel.successMessage ??
                                      'Seguimiento creado correctamente.',
                                ),
                              ),
                            );

                          _ambientBackgroundController.replay();
                        },
                  icon: viewModel.isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_rounded),
                  label: Text(
                    viewModel.isLoading ? 'Creando...' : 'Crear seguimiento',
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final activeTrackingLabel =
        viewModel.activeTrackingLabel ?? 'Seguimiento actual';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 36),
      children: [
        AnimatedEntrance(
          duration: const Duration(milliseconds: 430),
          offset: const Offset(0, 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.13 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: colorScheme.primary.withValues(
                      alpha: isDark ? 0.20 : 0.10,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      'Seguimiento actual',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text('Resumen de hoy', style: theme.textTheme.headlineMedium),
              const SizedBox(height: 7),
              Text(
                'Organiza y consulta la información registrada.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        AnimatedEntrance(
          delay: const Duration(milliseconds: 90),
          duration: const Duration(milliseconds: 470),
          beginScale: 0.985,
          child: AnimatedPressableScale(
            child: Card(
              key: const Key('home-tracking-selector-card'),
              margin: EdgeInsets.zero,
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: viewModel.isLoading
                    ? null
                    : () {
                        _showTrackingSelector(viewModel);
                      },
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.layers_outlined,
                          color: colorScheme.onPrimary,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              activeTrackingLabel,
                              key: const Key('home-active-tracking-label'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Toca para cambiar, crear o administrar seguimientos.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerLow,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        const AnimatedEntrance(
          delay: Duration(milliseconds: 170),
          child: SendarisSectionLabel(label: 'Acciones rápidas'),
        ),
        const SizedBox(height: 14),

        // Nuevo registro.
        AnimatedEntrance(
          delay: const Duration(milliseconds: 240),
          duration: const Duration(milliseconds: 460),
          beginScale: 0.99,
          child: AnimatedPressableScale(
            child: Card(
              key: const Key('home-new-register-action'),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _openRegister,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: isDark ? 0.42 : 0.72,
                          ),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nuevo registro',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Añade información al seguimiento actual.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      _ArrowCircle(colorScheme: colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Rutinas.
        AnimatedEntrance(
          delay: const Duration(milliseconds: 320),
          duration: const Duration(milliseconds: 460),
          beginScale: 0.99,
          child: AnimatedPressableScale(
            child: Card(
              key: const Key('home-routines-action'),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _openRoutines,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1B302E)
                              : const Color(0xFFE8F0F1),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.event_repeat_rounded,
                          color: isDark
                              ? const Color(0xFF8ABDB8)
                              : const Color(0xFF527B7E),
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Rutinas', style: theme.textTheme.titleMedium),
                            const SizedBox(height: 5),
                            Text(
                              'Crea y organiza actividades habituales.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      _ArrowCircle(colorScheme: colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 30),
        const AnimatedEntrance(
          delay: Duration(milliseconds: 390),
          child: SendarisSectionLabel(label: 'Seguimiento'),
        ),
        const SizedBox(height: 14),

        // Historial.
        AnimatedEntrance(
          delay: const Duration(milliseconds: 450),
          duration: const Duration(milliseconds: 470),
          beginScale: 0.99,
          child: AnimatedPressableScale(
            child: Card(
              key: const Key('home-history-action'),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _openHistory,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: isDark ? 0.36 : 0.62,
                          ),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.history_rounded,
                          color: colorScheme.primary,
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Historial',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Consulta los registros del seguimiento actual.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      _ArrowCircle(colorScheme: colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Frecuencias.
        AnimatedEntrance(
          delay: const Duration(milliseconds: 520),
          duration: const Duration(milliseconds: 470),
          beginScale: 0.99,
          child: AnimatedPressableScale(
            child: Card(
              key: const Key('home-frequency-action'),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _openFrequencies,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF27283A)
                              : const Color(0xFFEEEAF8),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.bar_chart_rounded,
                          color: isDark
                              ? const Color(0xFFB4A8E0)
                              : const Color(0xFF6F5E9C),
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Frecuencias descriptivas',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Cuenta registros por periodo y categoría.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      _ArrowCircle(colorScheme: colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Duraciones.
        AnimatedEntrance(
          delay: const Duration(milliseconds: 590),
          duration: const Duration(milliseconds: 470),
          beginScale: 0.99,
          child: AnimatedPressableScale(
            child: Card(
              key: const Key('home-duration-action'),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _openDurations,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF203234)
                              : const Color(0xFFE7F1F0),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.timer_outlined,
                          color: isDark
                              ? const Color(0xFF8FC5C2)
                              : const Color(0xFF4E817F),
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Duraciones y promedios',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Consulta duraciones válidas y promedios por periodo.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      _ArrowCircle(colorScheme: colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Cumplimiento de rutinas.
        AnimatedEntrance(
          delay: const Duration(milliseconds: 660),
          duration: const Duration(milliseconds: 470),
          beginScale: 0.99,
          child: AnimatedPressableScale(
            child: Card(
              key: const Key('home-routine-compliance-action'),
              child: InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: _openRoutineCompliance,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF302C23)
                              : const Color(0xFFF4EFE2),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: Icon(
                          Icons.task_alt_rounded,
                          color: isDark
                              ? const Color(0xFFD7BE83)
                              : const Color(0xFF806B39),
                          size: 27,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cumplimiento de rutinas',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Revisa cuántos registros de rutina '
                              'se completaron en un periodo.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      _ArrowCircle(colorScheme: colorScheme),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TrackingSelectorSheet extends StatefulWidget {
  const _TrackingSelectorSheet();

  @override
  State<_TrackingSelectorSheet> createState() => _TrackingSelectorSheetState();
}

class _TrackingSelectorSheetState extends State<_TrackingSelectorSheet> {
  bool _isManaging = false;

  final Set<String> _selectedIds = <String>{};

  void _startManaging() {
    setState(() {
      _isManaging = true;
      _selectedIds.clear();
    });
  }

  void _cancelManaging() {
    setState(() {
      _isManaging = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelection(String anonymousId) {
    setState(() {
      if (!_selectedIds.add(anonymousId)) {
        _selectedIds.remove(anonymousId);
      }
    });
  }

  void _toggleSelectAll(List<AnonymousTrackingProfile> profiles) {
    setState(() {
      if (_selectedIds.length == profiles.length) {
        _selectedIds.clear();
        return;
      }

      _selectedIds
        ..clear()
        ..addAll(profiles.map((profile) => profile.anonymousId));
    });
  }

  Future<void> _confirmDeletion(TrackingViewModel viewModel) async {
    if (_selectedIds.isEmpty || viewModel.isLoading) {
      return;
    }

    final selectedCount = _selectedIds.length;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final dialogColorScheme = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: const Text('¿Eliminar definitivamente?'),
          content: Text(
            selectedCount == 1
                ? 'Se eliminarán este seguimiento y toda la información '
                      'asociada, incluidos registros y rutinas. '
                      'Esta acción no se puede deshacer.'
                : 'Se eliminarán los seguimientos seleccionados y toda la '
                      'información asociada, incluidos registros y rutinas. '
                      'Esta acción no se puede deshacer.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('tracking-confirm-delete-button'),
              style: FilledButton.styleFrom(
                backgroundColor: dialogColorScheme.error,
                foregroundColor: dialogColorScheme.onError,
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Eliminar definitivamente'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    final idsToDelete = Set<String>.unmodifiable(_selectedIds);

    final success = await viewModel.deleteProfiles(idsToDelete);

    if (!mounted) {
      return;
    }

    if (success) {
      final message =
          viewModel.successMessage ?? 'Seguimiento eliminado definitivamente.';

      Navigator.of(context).pop(message);

      return;
    }

    final remainingIds = viewModel.profiles
        .map((profile) => profile.anonymousId)
        .toSet();

    setState(() {
      _selectedIds.removeWhere((id) => !remainingIds.contains(id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TrackingViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final profiles = _isManaging
        ? viewModel.orderedProfiles
        : viewModel.activeProfiles;

    final allSelected =
        profiles.isNotEmpty && _selectedIds.length == profiles.length;

    return PopScope(
      canPop: !_isManaging,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }

        if (_isManaging && !viewModel.isLoading) {
          _cancelManaging();
        }
      },
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isManaging ? 'Administrar seguimientos' : 'Tus seguimientos',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _isManaging
                    ? 'Selecciona uno o varios seguimientos para eliminarlos definitivamente.'
                    : 'La información de cada seguimiento se mantiene separada.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                key: const Key('tracking-privacy-message'),
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _isManaging
                          ? Icons.warning_amber_rounded
                          : Icons.shield_outlined,
                      size: 19,
                      color: _isManaging
                          ? colorScheme.error
                          : colorScheme.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        _isManaging
                            ? 'La eliminación es permanente y también borra los registros y rutinas asociados.'
                            : 'Cada seguimiento es anónimo. No se solicitan nombres ni datos personales.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (viewModel.errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  key: const Key('tracking-selector-error'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    viewModel.errorMessage!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              if (_isManaging && profiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedIds.length} '
                        '${_selectedIds.length == 1 ? 'seleccionado' : 'seleccionados'}',
                        key: const Key('tracking-selected-count'),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('tracking-select-all-button'),
                      onPressed: viewModel.isLoading
                          ? null
                          : () {
                              _toggleSelectAll(profiles);
                            },
                      child: Text(
                        allSelected ? 'Quitar selección' : 'Seleccionar todos',
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Flexible(
                child: profiles.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 28),
                          child: Text(
                            'Aún no tienes seguimientos.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      )
                    : ListView.separated(
                        key: const Key('tracking-selector-list'),
                        shrinkWrap: true,
                        itemCount: profiles.length,
                        separatorBuilder: (_, _) {
                          return const SizedBox(height: 10);
                        },
                        itemBuilder: (context, index) {
                          final profile = profiles[index];

                          final number =
                              viewModel.trackingNumberFor(profile) ?? index + 1;

                          final label = viewModel.trackingLabelFor(profile);

                          final isCurrent =
                              viewModel.activeAnonymousId ==
                              profile.anonymousId;

                          final isMarked = _selectedIds.contains(
                            profile.anonymousId,
                          );

                          return _TrackingOptionCard(
                            key: Key('tracking-option-$number'),
                            profile: profile,
                            label: label,
                            isCurrent: isCurrent,
                            isManaging: _isManaging,
                            isMarked: isMarked,
                            isLoading: viewModel.isLoading,
                            onSelected: () {
                              if (_isManaging) {
                                _toggleSelection(profile.anonymousId);

                                return;
                              }

                              final success = viewModel.selectProfile(profile);

                              if (!success) {
                                return;
                              }

                              Navigator.of(context).pop('$label seleccionado.');
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 18),
              if (_isManaging) ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('tracking-delete-selected-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                    onPressed: _selectedIds.isEmpty || viewModel.isLoading
                        ? null
                        : () {
                            _confirmDeletion(viewModel);
                          },
                    icon: viewModel.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline_rounded),
                    label: Text(
                      viewModel.isLoading
                          ? 'Eliminando...'
                          : 'Eliminar definitivamente',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    key: const Key('tracking-management-cancel-button'),
                    onPressed: viewModel.isLoading ? null : _cancelManaging,
                    child: const Text('Cancelar'),
                  ),
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('tracking-create-button'),
                    onPressed: viewModel.isLoading
                        ? null
                        : () async {
                            final success = await viewModel
                                .createAndPersistProfile();

                            if (!context.mounted || !success) {
                              return;
                            }

                            final label = viewModel.activeTrackingLabel;

                            if (label == null) {
                              return;
                            }

                            Navigator.of(context)
                                .pop('$label creado y seleccionado.');
                          },
                    icon: viewModel.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.add_rounded),
                    label: Text(
                      viewModel.isLoading ? 'Creando...' : 'Nuevo seguimiento',
                    ),
                  ),
                ),
                if (profiles.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const Key('tracking-manage-button'),
                      onPressed: viewModel.isLoading ? null : _startManaging,
                      icon: const Icon(Icons.tune_rounded),
                      label: const Text('Administrar'),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackingOptionCard extends StatelessWidget {
  const _TrackingOptionCard({
    required this.profile,
    required this.label,
    required this.isCurrent,
    required this.isManaging,
    required this.isMarked,
    required this.isLoading,
    required this.onSelected,
    super.key,
  });

  final AnonymousTrackingProfile profile;
  final String label;
  final bool isCurrent;
  final bool isManaging;
  final bool isMarked;
  final bool isLoading;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final canSelect = profile.isActive && !isLoading;

    final canManage = !isLoading;

    final highlighted = isManaging ? isMarked : isCurrent;

    return Material(
      color: highlighted
          ? colorScheme.primaryContainer.withValues(alpha: 0.55)
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: (isManaging ? canManage : canSelect) ? onSelected : null,
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: highlighted
                      ? colorScheme.primary
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.layers_outlined,
                  color: highlighted
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
                      label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Creado el '
                      '${_formatTrackingDate(profile.createdAt)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (isManaging)
                Checkbox(
                  value: isMarked,
                  onChanged: canManage
                      ? (_) {
                          onSelected();
                        }
                      : null,
                )
              else if (isCurrent)
                Icon(Icons.check_circle_rounded, color: colorScheme.primary)
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ArrowCircle extends StatelessWidget {
  const _ArrowCircle({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.arrow_forward_rounded,
        size: 18,
        color: colorScheme.onSurfaceVariant,
      ),
    );
  }
}

String _formatTrackingDate(DateTime value) {
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

  final localValue = value.toLocal();

  return '${localValue.day.toString().padLeft(2, '0')} '
      '${months[localValue.month - 1]} '
      '${localValue.year}';
}
