import 'package:flutter/material.dart';

import '../../../../app/animation/animated_entrance.dart';
import '../../../../app/animation/animated_pressable_scale.dart';
import '../../../../app/widgets/sendaris_primary_app_bar.dart';

class RoutinesView extends StatelessWidget {
  const RoutinesView({
    required this.hasTracking,
    this.onManagementTap,
    this.onStatusTap,
    super.key,
  });

  final bool hasTracking;

  final VoidCallback? onManagementTap;
  final VoidCallback? onStatusTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      key: const Key('routines-view'),
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
                    'Rutinas',
                    key: const Key('routines-title'),
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Organiza y administra tus rutinas',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Selecciona una opción para gestionar '
                    'las rutinas o registrar su estado.',
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
                  key: const Key('routines-no-tracking-message'),
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
                          'desde Inicio para gestionar rutinas.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onErrorContainer,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 28),
            AnimatedEntrance(
              delay: const Duration(milliseconds: 120),
              duration: const Duration(milliseconds: 450),
              beginScale: 0.99,
              child: AnimatedPressableScale(
                child: _RoutineOptionCard(
                  key: const Key('routines-management-option'),
                  title: 'Rutinas',
                  subtitle:
                      'Crea, consulta, edita o elimina '
                      'las rutinas del seguimiento actual.',
                  icon: Icons.checklist_rounded,
                  accentColor: const Color(0xFF5CB9AA),
                  enabled: hasTracking && onManagementTap != null,
                  onTap: onManagementTap,
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedEntrance(
              delay: const Duration(milliseconds: 170),
              duration: const Duration(milliseconds: 450),
              beginScale: 0.99,
              child: AnimatedPressableScale(
                child: _RoutineOptionCard(
                  key: const Key('routines-status-option'),
                  title: 'Estados de rutina',
                  subtitle:
                      'Registra y consulta el estado '
                      'observado de las rutinas.',
                  icon: Icons.fact_check_outlined,
                  accentColor: const Color(0xFF78AFC1),
                  enabled: hasTracking && onStatusTap != null,
                  onTap: onStatusTap,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineOptionCard extends StatelessWidget {
  const _RoutineOptionCard({
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
          : '$title. Requiere un seguimiento actual.',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(22),
          child: Opacity(
            opacity: enabled ? 1 : 0.48,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 126),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: accentColor.withValues(
                          alpha: isDark ? 0.18 : 0.14,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        icon,
                        color: isDark
                            ? Color.lerp(accentColor, Colors.white, 0.25)
                            : accentColor,
                        size: 27,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (enabled)
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 22,
                        color: colorScheme.onSurfaceVariant.withValues(
                          alpha: 0.76,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
