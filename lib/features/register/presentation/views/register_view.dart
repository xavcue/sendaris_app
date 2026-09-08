import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/animation/animated_entrance.dart';
import '../../../../app/animation/animated_pressable_scale.dart';
import '../../../../app/theme/sendaris_section_label.dart';
import '../../../tracking/presentation/viewmodels/tracking_view_model.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    final trackingViewModel = context.watch<TrackingViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo registro')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 36),
          children: [
            AnimatedEntrance(
              duration: const Duration(milliseconds: 420),
              offset: const Offset(0, 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Qué quieres registrar?',
                    style: theme.textTheme.headlineMedium,
                  ),

                  const SizedBox(height: 7),

                  Text(
                    'Selecciona el tipo de información '
                    'que deseas añadir.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const AnimatedEntrance(
              delay: Duration(milliseconds: 90),
              child: SendarisSectionLabel(label: 'Registros'),
            ),

            const SizedBox(height: 14),

            AnimatedEntrance(
              delay: const Duration(milliseconds: 150),
              duration: const Duration(milliseconds: 450),
              beginScale: 0.99,
              child: AnimatedPressableScale(
                child: _RegisterOptionCard(
                  key: const Key('register-behavior-option'),
                  title: 'Conducta',
                  subtitle: 'Registrar una conducta observada',
                  icon: Icons.psychology_alt_outlined,
                  accentColor: const Color(0xFFE56F61),
                  enabled: trackingViewModel.hasActiveProfile,
                  wide: true,
                  onTap: () {
                    context.push('/register/behavior');
                  },
                ),
              ),
            ),

            const SizedBox(height: 14),

            AnimatedEntrance(
              delay: const Duration(milliseconds: 220),
              duration: const Duration(milliseconds: 450),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _RegisterOptionCard(
                      title: 'Sueño',
                      subtitle: 'Próximamente',
                      icon: Icons.bedtime_outlined,
                      accentColor: const Color(0xFF78AFC1),
                      enabled: false,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _RegisterOptionCard(
                      title: 'Alimentación',
                      subtitle: 'Próximamente',
                      icon: Icons.restaurant_outlined,
                      accentColor: const Color(0xFFC9A353),
                      enabled: false,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            AnimatedEntrance(
              delay: const Duration(milliseconds: 290),
              duration: const Duration(milliseconds: 450),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _RegisterOptionCard(
                      title: 'Interacción social',
                      subtitle: 'Próximamente',
                      icon: Icons.groups_outlined,
                      accentColor: const Color(0xFF69AA98),
                      enabled: false,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: _RegisterOptionCard(
                      title: 'Desregulación',
                      subtitle: 'Próximamente',
                      icon: Icons.sentiment_dissatisfied_outlined,
                      accentColor: const Color(0xFF8173AE),
                      enabled: false,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            const AnimatedEntrance(
              delay: Duration(milliseconds: 350),
              child: SendarisSectionLabel(label: 'Otras acciones'),
            ),

            const SizedBox(height: 14),

            AnimatedEntrance(
              delay: const Duration(milliseconds: 410),
              duration: const Duration(milliseconds: 450),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AnimatedPressableScale(
                      child: _RegisterOptionCard(
                        key: const Key('register-atypical-situation-option'),
                        title: 'Otra situación',
                        subtitle: 'Registrar otro acontecimiento',
                        icon: Icons.event_note_outlined,
                        accentColor: const Color(0xFF9B8564),
                        enabled: trackingViewModel.hasActiveProfile,
                        onTap: () {
                          context.push('/register/atypical-situation');
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: AnimatedPressableScale(
                      child: _RegisterOptionCard(
                        key: const Key('register-routines-option'),
                        title: 'Rutinas',
                        subtitle: 'Administrar rutinas',
                        icon: Icons.checklist_rounded,
                        accentColor: const Color(0xFF5D8EB8),
                        enabled: trackingViewModel.hasActiveProfile,
                        onTap: () {
                          context.push('/routines');
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            AnimatedEntrance(
              delay: const Duration(milliseconds: 480),
              duration: const Duration(milliseconds: 460),
              beginScale: 0.99,
              child: AnimatedPressableScale(
                child: _RegisterOptionCard(
                  key: const Key('register-routine-status-option'),
                  title: 'Estado de rutina',
                  subtitle: 'Registrar el estado de una rutina',
                  icon: Icons.event_available_outlined,
                  accentColor: const Color(0xFF5DAE98),
                  enabled: trackingViewModel.hasActiveProfile,
                  wide: true,
                  onTap: () {
                    context.push('/routines/status/new');
                  },
                ),
              ),
            ),

            if (!trackingViewModel.hasActiveProfile) ...[
              const SizedBox(height: 24),

              AnimatedEntrance(
                delay: const Duration(milliseconds: 520),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(
                      alpha: isDark ? 0.54 : 0.74,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: colorScheme.error.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: colorScheme.onErrorContainer,
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          'No hay un perfil activo disponible '
                          'para registrar información.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RegisterOptionCard extends StatelessWidget {
  const _RegisterOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.enabled,
    this.onTap,
    this.wide = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool enabled;
  final VoidCallback? onTap;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final contentOpacity = enabled ? 1.0 : 0.48;

    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: enabled ? onTap : null,
        child: wide
            ? _buildWideContent(context, contentOpacity, colorScheme, isDark)
            : _buildCompactContent(
                context,
                contentOpacity,
                colorScheme,
                isDark,
              ),
      ),
    );

    return Semantics(
      button: enabled,
      enabled: enabled,
      label: enabled ? '$title. $subtitle' : '$title. Próximamente',
      child: card,
    );
  }

  Widget _buildWideContent(
    BuildContext context,
    double contentOpacity,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: contentOpacity,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            _IconContainer(
              icon: icon,
              accentColor: accentColor,
              isDark: isDark,
            ),

            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleMedium),

                  const SizedBox(height: 5),

                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),

            if (enabled) ...[
              const SizedBox(width: 10),

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
          ],
        ),
      ),
    );
  }

  Widget _buildCompactContent(
    BuildContext context,
    double contentOpacity,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: contentOpacity,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconContainer(
                  icon: icon,
                  accentColor: accentColor,
                  isDark: isDark,
                ),

                const Spacer(),

                if (enabled)
                  Icon(
                    Icons.north_east_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72),
                  ),
              ],
            ),

            const SizedBox(height: 18),

            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium,
            ),

            const SizedBox(height: 6),

            Text(subtitle, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _IconContainer extends StatelessWidget {
  const _IconContainer({
    required this.icon,
    required this.accentColor,
    required this.isDark,
  });

  final IconData icon;
  final Color accentColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.18 : 0.14),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(
        icon,
        color: isDark
            ? Color.lerp(accentColor, Colors.white, 0.25)
            : accentColor,
        size: 25,
      ),
    );
  }
}
