import 'package:flutter/material.dart';

import '../../domain/models/social_interaction_record.dart';

class SocialInteractionDetailView extends StatelessWidget {
  const SocialInteractionDetailView({required this.record, super.key});

  final SocialInteractionRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('social-interaction-detail-view'),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Detalle de interacción social'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          children: [
            Text(
              'Registro de interacción social',
              style: theme.textTheme.headlineMedium,
            ),
            const SizedBox(height: 7),
            Text(
              'Consulta la información registrada para este evento.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              key: const Key('social-interaction-detail-summary-card'),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SocialInteractionDetailIcon(),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.category.label,
                            key: const Key(
                              'social-interaction-detail-category',
                            ),
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _formatDate(record.date),
                            key: const Key('social-interaction-detail-date'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _SocialInteractionDetailSection(
              key: const Key('social-interaction-detail-category-section'),
              icon: Icons.people_outline,
              title: 'Categoría',
              value: record.category.label,
            ),
            const SizedBox(height: 12),
            _SocialInteractionDetailSection(
              key: const Key('social-interaction-detail-date-section'),
              icon: Icons.calendar_today_outlined,
              title: 'Fecha',
              value: _formatDate(record.date),
            ),
            const SizedBox(height: 12),
            _SocialInteractionDetailSection(
              key: const Key('social-interaction-detail-context-section'),
              icon: Icons.place_outlined,
              title: 'Contexto',
              value: record.context ?? 'Sin contexto',
            ),
            const SizedBox(height: 12),
            _SocialInteractionDetailSection(
              key: const Key('social-interaction-detail-observation-section'),
              icon: Icons.notes_outlined,
              title: 'Observación',
              value: record.observation ?? 'Sin observación',
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialInteractionDetailIcon extends StatelessWidget {
  const _SocialInteractionDetailIcon();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.20 : 0.12,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(Icons.people_outline, color: colorScheme.primary),
    );
  }
}

class _SocialInteractionDetailSection extends StatelessWidget {
  const _SocialInteractionDetailSection({
    required this.icon,
    required this.title,
    required this.value,
    super.key,
  });

  final IconData icon;

  final String title;

  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: colorScheme.primary),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    value,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();

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

  return '${local.day.toString().padLeft(2, '0')} '
      '${months[local.month - 1]} '
      '${local.year}';
}
