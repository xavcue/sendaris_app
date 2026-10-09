import 'package:flutter/material.dart';

import '../../domain/models/behavior_record.dart';

class BehaviorDetailView extends StatelessWidget {
  const BehaviorDetailView({required this.record, super.key});

  final BehaviorRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('behavior-detail-view'),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Detalle de conducta'),
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
              'Registro de conducta',
              key: const Key('behavior-detail-title'),
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
            _BehaviorSummaryCard(record: record),
            const SizedBox(height: 18),
            _BehaviorDetailSection(
              key: const Key('behavior-detail-date-section'),
              icon: Icons.calendar_today_outlined,
              title: 'Fecha',
              value: _formatDate(record.date),
            ),
            const SizedBox(height: 12),
            _BehaviorDetailSection(
              key: const Key('behavior-detail-time-section'),
              icon: Icons.schedule_outlined,
              title: 'Hora',
              value: record.time ?? 'Sin hora',
            ),
            const SizedBox(height: 12),
            _BehaviorDetailSection(
              key: const Key('behavior-detail-duration-section'),
              icon: Icons.timer_outlined,
              title: 'Duración',
              value: record.durationMinutes == null
                  ? 'Sin duración'
                  : '${record.durationMinutes} min',
            ),
            const SizedBox(height: 12),
            _BehaviorDetailSection(
              key: const Key('behavior-detail-intensity-section'),
              icon: Icons.speed_outlined,
              title: 'Intensidad descriptiva',
              value: record.intensity?.label ?? 'Sin intensidad',
            ),
            const SizedBox(height: 12),
            _BehaviorDetailSection(
              key: const Key('behavior-detail-context-section'),
              icon: Icons.location_on_outlined,
              title: 'Contexto general',
              value: record.context ?? 'Sin contexto',
            ),
            const SizedBox(height: 12),
            _BehaviorDetailSection(
              key: const Key('behavior-detail-observation-section'),
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

class _BehaviorSummaryCard extends StatelessWidget {
  const _BehaviorSummaryCard({required this.record});

  final BehaviorRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const accentColor = Color(0xFFE56F61);

    return Card(
      key: const Key('behavior-detail-summary-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.20 : 0.14,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.psychology_alt_outlined,
                color: theme.brightness == Brightness.dark
                    ? Color.lerp(accentColor, Colors.white, 0.25)
                    : accentColor,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.category.label,
                    key: const Key('behavior-detail-category'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatSummaryDateTime(record),
                    key: const Key('behavior-detail-summary-date'),
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
    );
  }
}

class _BehaviorDetailSection extends StatelessWidget {
  const _BehaviorDetailSection({
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

String _formatSummaryDateTime(BehaviorRecord record) {
  final date = _formatDate(record.date);

  final time = record.time;

  if (time == null) {
    return '$date · Sin hora';
  }

  return '$date · $time';
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
