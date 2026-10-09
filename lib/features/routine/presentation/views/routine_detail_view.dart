import 'package:flutter/material.dart';

import '../../domain/models/routine.dart';

class RoutineDetailView extends StatelessWidget {
  const RoutineDetailView({required this.routine, super.key});

  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('routine-detail-view'),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Detalle de rutina'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _RoutineHeader(routine: routine),
              const SizedBox(height: 22),
              _DetailSection(
                title: 'Programación',
                icon: Icons.schedule_outlined,
                children: [
                  _DetailRow(
                    key: const Key('routine-detail-time'),
                    label: 'Hora programada',
                    value: routine.scheduledTime ?? 'Sin hora',
                  ),
                  _DetailRow(
                    key: const Key('routine-detail-recurrence'),
                    label: 'Frecuencia',
                    value: _formatRecurrence(routine.recurrence),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Información adicional',
                icon: Icons.notes_rounded,
                children: [
                  _DetailRow(
                    key: const Key('routine-detail-description'),
                    label: 'Descripción',
                    value: routine.description ?? 'No registrada',
                    multiline: true,
                    showDivider: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutineHeader extends StatelessWidget {
  const _RoutineHeader({required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const accentColor = Color(0xFF5CB9AA);

    return Card(
      key: const Key('routine-detail-header'),
      margin: EdgeInsets.zero,
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
                  alpha: theme.brightness == Brightness.dark ? 0.20 : 0.14,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.event_repeat_outlined,
                color: theme.brightness == Brightness.dark
                    ? Color.lerp(accentColor, Colors.white, 0.25)
                    : accentColor,
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rutina',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    routine.name,
                    key: const Key('routine-detail-name'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
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

class _DetailSection extends StatelessWidget {
  const _DetailSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.primary),
                const SizedBox(width: 9),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.multiline = false,
    this.showDivider = true,
    super.key,
  });

  final String label;
  final String value;
  final bool multiline;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: multiline
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: Text(
                        value,
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
      ],
    );
  }
}

String _formatRecurrence(String? recurrence) {
  return switch (recurrence) {
    'diaria' => 'Diaria',
    'semanal' => 'Semanal',
    'mensual' => 'Mensual',
    null => 'Sin recurrencia',
    _ => recurrence,
  };
}
