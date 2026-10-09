import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/animation/animated_entrance.dart';
import '../../../../app/animation/animated_pressable_scale.dart';
import '../../../../app/theme/sendaris_section_label.dart';
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
                    'Revisa indicadores descriptivos '
                    'del seguimiento actual.',
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
              child: SendarisSectionLabel(label: 'Indicadores disponibles'),
            ),
            const SizedBox(height: 14),
            AnimatedEntrance(
              delay: const Duration(milliseconds: 150),
              duration: const Duration(milliseconds: 450),
              beginScale: 0.99,
              child: AnimatedPressableScale(
                child: _IndicatorOptionCard(
                  key: const Key('indicators-frequency-option'),
                  title: 'Frecuencias descriptivas',
                  subtitle:
                      'Consulta cuántos registros aparecen '
                      'en el periodo seleccionado.',
                  icon: Icons.bar_chart_rounded,
                  accentColor: const Color(0xFF5D8EB8),
                  enabled: hasTracking,
                  onTap: () {
                    context.push('/frequencies');
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
                  key: const Key('indicators-duration-option'),
                  title: 'Duraciones y promedios',
                  subtitle:
                      'Consulta duraciones registradas '
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
              delay: const Duration(milliseconds: 290),
              duration: const Duration(milliseconds: 450),
              beginScale: 0.99,
              child: AnimatedPressableScale(
                child: _IndicatorOptionCard(
                  key: const Key('indicators-routine-compliance-option'),
                  title: 'Cumplimiento de rutinas',
                  subtitle:
                      'Consulta los estados registrados '
                      'de las rutinas del seguimiento.',
                  icon: Icons.fact_check_outlined,
                  accentColor: const Color(0xFF5DAE98),
                  enabled: hasTracking,
                  onTap: () {
                    context.push('/routine-compliance');
                  },
                ),
              ),
            ),
            if (!hasTracking) ...[
              const SizedBox(height: 24),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 350),
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
                          'para consultar sus indicadores.',
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
          : '$title. No disponible sin un seguimiento seleccionado.',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(22),
          child: Opacity(
            opacity: enabled ? 1 : 0.48,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
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
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
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
          ),
        ),
      ),
    );
  }
}
