import 'package:flutter/material.dart';

import '../../domain/models/feeding_record.dart';

class FeedingDetailView extends StatelessWidget {
  const FeedingDetailView({required this.record, super.key});

  final FeedingRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('feeding-detail-view'),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Detalle de alimentación'),
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
              'Registro de alimentación',
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
              key: const Key('feeding-detail-summary-card'),
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FeedingDetailIcon(),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                record.category.label,
                                key: const Key('feeding-detail-category'),
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                _formatDate(record.date),
                                key: const Key('feeding-detail-date'),
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _FeedingDetailSection(
              key: const Key('feeding-detail-category-section'),
              icon: Icons.restaurant_outlined,
              title: 'Categoría',
              value: record.category.label,
            ),
            const SizedBox(height: 12),
            _FeedingDetailSection(
              key: const Key('feeding-detail-date-section'),
              icon: Icons.calendar_today_outlined,
              title: 'Fecha',
              value: _formatDate(record.date),
            ),
            const SizedBox(height: 12),
            _FeedingDetailSection(
              key: const Key('feeding-detail-observation-section'),
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

class _FeedingDetailIcon extends StatelessWidget {
  const _FeedingDetailIcon();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    const accentColor = Color(0xFFE7A85B);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: accentColor.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.20 : 0.14,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        Icons.restaurant_outlined,
        color: theme.brightness == Brightness.dark
            ? Color.lerp(accentColor, Colors.white, 0.25)
            : accentColor,
      ),
    );
  }
}

class _FeedingDetailSection extends StatelessWidget {
  const _FeedingDetailSection({
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
