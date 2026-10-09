import 'package:flutter/material.dart';

import '../../domain/models/sleep_record.dart';

class SleepDetailView extends StatelessWidget {
  const SleepDetailView({required this.record, super.key});

  final SleepRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('sleep-detail-view'),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Detalle de sueño'),
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
              'Registro de sueño',
              key: const Key('sleep-detail-title'),
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
            _SleepSummaryCard(record: record),
            const SizedBox(height: 18),
            _SleepDetailSection(
              key: const Key('sleep-detail-date-period-section'),
              icon: Icons.calendar_today_outlined,
              title: 'Periodo de fechas',
              value: _formatSleepDatePeriod(record),
            ),
            const SizedBox(height: 12),
            _SleepDetailSection(
              key: const Key('sleep-detail-start-time-section'),
              icon: Icons.bedtime_outlined,
              title: 'Hora de inicio',
              value: record.startTime,
            ),
            const SizedBox(height: 12),
            _SleepDetailSection(
              key: const Key('sleep-detail-end-time-section'),
              icon: Icons.wb_sunny_outlined,
              title: 'Hora de finalización',
              value: record.endTime,
            ),
            const SizedBox(height: 12),
            _SleepDetailSection(
              key: const Key('sleep-detail-duration-section'),
              icon: Icons.timer_outlined,
              title: 'Duración',
              value: _formatDuration(record.durationMinutes),
            ),
            const SizedBox(height: 12),
            _SleepDetailSection(
              key: const Key('sleep-detail-observation-section'),
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

class _SleepSummaryCard extends StatelessWidget {
  const _SleepSummaryCard({required this.record});

  final SleepRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const accentColor = Color(0xFF78AFC1);

    return Card(
      key: const Key('sleep-detail-summary-card'),
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
                Icons.bedtime_outlined,
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
                    '${record.startTime} – ${record.endTime}',
                    key: const Key('sleep-detail-period'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _formatSleepDatePeriod(record),
                    key: const Key('sleep-detail-summary-date-period'),
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

class _SleepDetailSection extends StatelessWidget {
  const _SleepDetailSection({
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

String _formatSleepDatePeriod(SleepRecord record) {
  final startDate = DateTime(
    record.date.year,
    record.date.month,
    record.date.day,
  );

  final endDate = _endsNextDay(record)
      ? startDate.add(const Duration(days: 1))
      : startDate;

  if (_isSameDate(startDate, endDate)) {
    return _formatDate(startDate);
  }

  return '${_formatDate(startDate)} – ${_formatDate(endDate)}';
}

bool _endsNextDay(SleepRecord record) {
  final startMinutes = _timeToMinutes(record.startTime);

  final endMinutes = _timeToMinutes(record.endTime);

  return endMinutes < startMinutes;
}

int _timeToMinutes(String value) {
  final parts = value.split(':');

  if (parts.length != 2) {
    return 0;
  }

  final hour = int.tryParse(parts[0]) ?? 0;

  final minute = int.tryParse(parts[1]) ?? 0;

  return hour * 60 + minute;
}

bool _isSameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
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

String _formatDuration(int minutes) {
  final hours = minutes ~/ 60;
  final remainingMinutes = minutes % 60;

  if (hours > 0 && remainingMinutes > 0) {
    return '$hours h $remainingMinutes min';
  }

  if (hours > 0) {
    return '$hours h';
  }

  return '$remainingMinutes min';
}
