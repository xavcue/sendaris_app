import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/animation/animated_entrance.dart';
import '../../../../app/animation/animated_pressable_scale.dart';
import '../../../../app/theme/ambient_background.dart';
import '../../../../app/theme/sendaris_section_label.dart';
import '../../../../app/theme/theme_mode_controller.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
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
                  'No pudimos preparar el perfil',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall,
                ),

                const SizedBox(height: 8),

                Text(
                  viewModel.errorMessage ?? 'Inténtalo nuevamente.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 24),

                FilledButton.icon(
                  onPressed: viewModel.isLoading ? null : viewModel.initialize,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                      'Perfil activo',
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
          child: Container(
            key: const Key('home-profile-ready-card'),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.primaryContainer.withValues(alpha: 0.36)
                  : colorScheme.primaryContainer.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colorScheme.primary.withValues(
                  alpha: isDark ? 0.16 : 0.08,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    color: colorScheme.onPrimary,
                    size: 26,
                  ),
                ),

                const SizedBox(width: 15),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Perfil listo', style: theme.textTheme.titleMedium),

                      const SizedBox(height: 4),

                      Text(
                        'Puedes comenzar a registrar información.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.verified_rounded,
                  size: 20,
                  color: colorScheme.primary.withValues(alpha: 0.72),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 30),

        const AnimatedEntrance(
          delay: Duration(milliseconds: 170),
          child: SendarisSectionLabel(label: 'Acciones rápidas'),
        ),

        const SizedBox(height: 14),

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
                              'Añade información del perfil activo.',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),

                      Container(
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

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

                      Container(
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
          delay: Duration(milliseconds: 390),
          child: SendarisSectionLabel(label: 'Seguimiento'),
        ),

        const SizedBox(height: 14),

        AnimatedEntrance(
          delay: const Duration(milliseconds: 450),
          duration: const Duration(milliseconds: 470),
          child: Card(
            key: const Key('home-period-summary'),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.insights_outlined,
                      color: colorScheme.onSurfaceVariant,
                      size: 22,
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resumen del periodo',
                          style: theme.textTheme.titleMedium,
                        ),

                        const SizedBox(height: 6),

                        Text(
                          'Aún no hay información suficiente para mostrar un resumen.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
