import 'package:flutter/material.dart';

import '../../domain/models/routine_status.dart';
import '../../domain/models/routine_status_record.dart';

class RoutineStatusDetailArguments {
  const RoutineStatusDetailArguments({
    required this.record,
    required this.routineName,
  });

  final RoutineStatusRecord record;
  final String routineName;
}

class RoutineStatusDetailView extends StatelessWidget {
  const RoutineStatusDetailView({
    required this.record,
    required this.routineName,
    super.key,
  });

  final RoutineStatusRecord record;
  final String routineName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      key: const Key('routine-status-detail-view'),
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Detalle de estado de rutina'),
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
              Text(
                'Estado de rutina',
                key: const Key('routine-status-detail-title'),
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: 7),
              Text(
                'Consulta la información registrada para esta rutina.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              _RoutineStatusSummaryCard(
                routineName: _normalizedRoutineName(routineName),
                status: record.status,
              ),
              const SizedBox(height: 18),
              _DetailSection(
                title: 'Registro',
                icon: Icons.event_note_outlined,
                children: [
                  _DetailRow(
                    key: const Key('routine-status-detail-date'),
                    label: 'Fecha',
                    value: _formatDate(record.date),
                  ),
                  _DetailRow(
                    key: const Key('routine-status-detail-status'),
                    label: 'Estado',
                    value: record.status.label,
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _DetailSection(
                title: 'Información adicional',
                icon: Icons.notes_outlined,
                children: [
                  _DetailRow(
                    key: const Key('routine-status-detail-observation'),
                    label: 'Observación',
                    value: _formatObservation(record.observation),
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

class _RoutineStatusSummaryCard extends StatelessWidget {
  const _RoutineStatusSummaryCard({
    required this.routineName,
    required this.status,
  });

  final String routineName;
  final RoutineStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    const accentColor = Color(0xFF5CB9AA);

    return Card(
      key: const Key('routine-status-detail-summary-card'),
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
                Icons.fact_check_outlined,
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
                    routineName,
                    key: const Key('routine-status-detail-routine-name'),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 9),
                  _StatusBadge(status: status),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final RoutineStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const Key('routine-status-detail-status-badge'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          status.label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
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
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
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

String _normalizedRoutineName(String value) {
  final normalized = value.trim();

  if (normalized.isEmpty) {
    return 'Rutina no disponible';
  }

  return normalized;
}

String _formatObservation(String? value) {
  final normalized = value?.trim();

  if (normalized == null || normalized.isEmpty) {
    return 'Sin observación';
  }

  return normalized;
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
