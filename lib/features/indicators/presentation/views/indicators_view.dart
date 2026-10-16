import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/animation/animated_entrance.dart';
import '../../../../app/animation/animated_pressable_scale.dart';
import '../../../../app/widgets/sendaris_primary_app_bar.dart';
import '../../../tracking/presentation/viewmodels/tracking_view_model.dart';

class IndicatorsView extends StatelessWidget {
  const IndicatorsView({super.key});

  @override
  Widget build(BuildContext context) {
    final trackingViewModel = context.watch<TrackingViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final hasTracking = trackingViewModel.hasActiveProfile;

    return Scaffold(
      key: const Key('indicators-view'),
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
                    'Indicadores',
                    key: const Key('indicators-title'),
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Consulta la información registrada',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Revisa los registros y los indicadores '
                    'descriptivos del seguimiento actual.',
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
                  key: const Key('indicators-no-tracking-message'),
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
                          'desde Inicio para consultar sus indicadores.',
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
                child: _IndicatorOptionCard(
                  key: const Key('indicators-frequency-option'),
                  title: 'Calendario de registros',
                  subtitle:
                      'Consulta los registros y sus conteos '
                      'por fecha.',
                  icon: Icons.event_note_rounded,
                  accentColor: const Color(0xFF5D8EB8),
                  enabled: hasTracking,
                  onTap: () {
                    context.push('/calendar');
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedEntrance(
              delay: const Duration(milliseconds: 170),
              duration: const Duration(milliseconds: 450),
              beginScale: 0.99,
              child: AnimatedPressableScale(
                child: _IndicatorOptionCard(
                  key: const Key('indicators-duration-option'),
                  title: 'Resumen de duraciones',
                  subtitle:
                      'Revisa las duraciones registradas '
                      'y sus valores promedio.',
                  icon: Icons.schedule_rounded,
                  accentColor: const Color(0xFF8173AE),
                  enabled: hasTracking,
                  onTap: () {
                    context.push('/durations');
                  },
                ),
              ),
            ),
            const SizedBox(height: 14),
            AnimatedEntrance(
              delay: const Duration(milliseconds: 220),
              duration: const Duration(milliseconds: 450),
              beginScale: 0.99,
              child: AnimatedPressableScale(
                child: _IndicatorOptionCard(
                  key: const Key('indicators-routine-compliance-option'),
                  title: 'Resumen de cumplimiento de rutinas',
                  subtitle:
                      'Consulta el porcentaje de cumplimiento '
                      'y los estados registrados.',
                  icon: Icons.fact_check_outlined,
                  accentColor: const Color(0xFF5DAE98),
                  enabled: hasTracking,
                  onTap: () {
                    context.push('/routine-compliance');
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndicatorOptionCard extends StatelessWidget {
  const _IndicatorOptionCard({
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
  final VoidCallback onTap;

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
