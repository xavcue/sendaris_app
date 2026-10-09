import 'package:flutter/material.dart';

import '../../../../app/animation/animated_entrance.dart';
import '../../../../app/animation/animated_pressable_scale.dart';
import '../../../../app/widgets/sendaris_primary_app_bar.dart';

class EventsView extends StatelessWidget {
  const EventsView({
    required this.hasTracking,
    this.onBehaviorTap,
    this.onSleepTap,
    this.onFeedingTap,
    this.onSocialInteractionTap,
    this.onDysregulationTap,
    this.onAtypicalSituationTap,
    super.key,
  });

  final bool hasTracking;

  final VoidCallback? onBehaviorTap;
  final VoidCallback? onSleepTap;
  final VoidCallback? onFeedingTap;
  final VoidCallback? onSocialInteractionTap;
  final VoidCallback? onDysregulationTap;
  final VoidCallback? onAtypicalSituationTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: const Key('events-view'),
      backgroundColor: Colors.transparent,
      appBar: const SendarisPrimaryAppBar(),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          children: [
            AnimatedEntrance(
              duration: const Duration(milliseconds: 420),
              offset: const Offset(0, 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eventos',
                    key: const Key('events-title'),
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Consulta y administra tus eventos',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Selecciona un tipo de evento para '
                    'consultar, editar o eliminar sus registros.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!hasTracking) ...[
              const SizedBox(height: 22),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 90),
                child: Container(
                  key: const Key('events-no-tracking-message'),
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
                          'Crea o selecciona un seguimiento '
                          'desde Inicio para consultar eventos.',
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
            const SizedBox(height: 28),
            GridView.count(
              key: const Key('events-type-grid'),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.02,
              children: [
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 120),
                  duration: const Duration(milliseconds: 450),
                  beginScale: 0.99,
                  child: AnimatedPressableScale(
                    child: _EventTypeCard(
                      key: const Key('events-behavior-option'),
                      title: 'Conducta',
                      subtitle: 'Consultar y administrar conductas',
                      icon: Icons.psychology_alt_outlined,
                      accentColor: const Color(0xFFE56F61),
                      enabled: hasTracking && onBehaviorTap != null,
                      onTap: onBehaviorTap,
                    ),
                  ),
                ),
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 160),
                  duration: const Duration(milliseconds: 450),
                  beginScale: 0.99,
                  child: AnimatedPressableScale(
                    child: _EventTypeCard(
                      key: const Key('events-sleep-option'),
                      title: 'Sueño',
                      subtitle: 'Consultar y administrar periodos de sueño',
                      icon: Icons.bedtime_outlined,
                      accentColor: const Color(0xFF78AFC1),
                      enabled: hasTracking && onSleepTap != null,
                      onTap: onSleepTap,
                    ),
                  ),
                ),
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 450),
                  beginScale: 0.99,
                  child: AnimatedPressableScale(
                    child: _EventTypeCard(
                      key: const Key('events-feeding-option'),
                      title: 'Alimentación',
                      subtitle:
                          'Consultar y administrar registros de alimentación',
                      icon: Icons.restaurant_outlined,
                      accentColor: const Color(0xFFC9A353),
                      enabled: hasTracking && onFeedingTap != null,
                      onTap: onFeedingTap,
                    ),
                  ),
                ),
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 240),
                  duration: const Duration(milliseconds: 450),
                  beginScale: 0.99,
                  child: AnimatedPressableScale(
                    child: _EventTypeCard(
                      key: const Key('events-social-interaction-option'),
                      title: 'Interacción social',
                      subtitle: 'Consultar y administrar interacciones',
                      icon: Icons.groups_outlined,
                      accentColor: const Color(0xFF69AA98),
                      enabled: hasTracking && onSocialInteractionTap != null,
                      onTap: onSocialInteractionTap,
                    ),
                  ),
                ),
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 280),
                  duration: const Duration(milliseconds: 450),
                  beginScale: 0.99,
                  child: AnimatedPressableScale(
                    child: _EventTypeCard(
                      key: const Key('events-dysregulation-option'),
                      title: 'Desregulación',
                      subtitle: 'Consultar y administrar episodios',
                      icon: Icons.sentiment_dissatisfied_outlined,
                      accentColor: const Color(0xFF8173AE),
                      enabled: hasTracking && onDysregulationTap != null,
                      onTap: onDysregulationTap,
                    ),
                  ),
                ),
                AnimatedEntrance(
                  delay: const Duration(milliseconds: 320),
                  duration: const Duration(milliseconds: 450),
                  beginScale: 0.99,
                  child: AnimatedPressableScale(
                    child: _EventTypeCard(
                      key: const Key('events-atypical-situation-option'),
                      title: 'Otra situación',
                      subtitle: 'Consultar y administrar otros acontecimientos',
                      icon: Icons.event_note_outlined,
                      accentColor: const Color(0xFF9B8564),
                      enabled: hasTracking && onAtypicalSituationTap != null,
                      onTap: onAtypicalSituationTap,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EventTypeCard extends StatelessWidget {
  const _EventTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: enabled,
      enabled: enabled,
      label: enabled
          ? '$title. $subtitle'
          : '$title. Administración no disponible.',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(22),
          child: Opacity(
            opacity: enabled ? 1 : 0.48,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(
                            alpha: isDark ? 0.18 : 0.14,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          icon,
                          color: isDark
                              ? Color.lerp(accentColor, Colors.white, 0.25)
                              : accentColor,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      if (enabled)
                        Icon(
                          Icons.north_east_rounded,
                          size: 18,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.72,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.30,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
