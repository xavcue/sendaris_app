import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../tracking/presentation/viewmodels/tracking_view_model.dart';

class RegisterView extends StatelessWidget {
  const RegisterView({super.key});

  @override
  Widget build(BuildContext context) {
    final trackingViewModel = context.watch<TrackingViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar seguimiento'),
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
            Text(
              'Selecciona una categoría',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 20),

            _RegisterOptionCard(
              key: const Key('register-behavior-option'),
              title: 'Conducta',
              subtitle: 'Añadir registro',
              icon: Icons.psychology_alt_outlined,
              accentColor: const Color(0xFFFF7A66),
              enabled: trackingViewModel.hasActiveProfile,
              onTap: () {
                context.push('/register/behavior');
              },
            ),

            const SizedBox(height: 12),

            const Row(
              children: [
                Expanded(
                  child: _RegisterOptionCard(
                    title: 'Sueño',
                    subtitle: 'Disponible próximamente',
                    icon: Icons.bedtime_outlined,
                    accentColor: Color(0xFF67A9C7),
                    enabled: false,
                  ),
                ),

                SizedBox(width: 12),

                Expanded(
                  child: _RegisterOptionCard(
                    title: 'Alimentación',
                    subtitle: 'Disponible próximamente',
                    icon: Icons.restaurant_outlined,
                    accentColor: Color(0xFFE8B84C),
                    enabled: false,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            const Row(
              children: [
                Expanded(
                  child: _RegisterOptionCard(
                    title: 'Interacción social',
                    subtitle: 'Disponible próximamente',
                    icon: Icons.groups_outlined,
                    accentColor: Color(0xFF67B49A),
                    enabled: false,
                  ),
                ),

                SizedBox(width: 12),

                Expanded(
                  child: _RegisterOptionCard(
                    title: 'Desregulación',
                    subtitle: 'Disponible próximamente',
                    icon: Icons.sentiment_dissatisfied_outlined,
                    accentColor: Color(0xFF9477C9),
                    enabled: false,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                const Expanded(
                  child: _RegisterOptionCard(
                    title: 'Situación atípica',
                    subtitle: 'Disponible próximamente',
                    icon: Icons.warning_amber_outlined,
                    accentColor: Color(0xFFB6A27C),
                    enabled: false,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _RegisterOptionCard(
                    key: const Key('register-routines-option'),
                    title: 'Rutinas',
                    subtitle: 'Administrar rutinas',
                    icon: Icons.checklist_rounded,
                    accentColor: const Color(0xFF5E8FC7),
                    enabled: trackingViewModel.hasActiveProfile,
                    onTap: () {
                      context.push('/routines');
                    },
                  ),
                ),
              ],
            ),

            if (!trackingViewModel.hasActiveProfile) ...[
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: colorScheme.onErrorContainer,
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'No existe un seguimiento '
                        'anónimo activo para '
                        'registrar información.',
                        style: TextStyle(color: colorScheme.onErrorContainer),
                      ),
                    ),
                  ],
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

    final contentOpacity = enabled ? 1.0 : 0.52;

    return Opacity(
      opacity: contentOpacity,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accentColor),
                ),

                const SizedBox(height: 18),

                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
