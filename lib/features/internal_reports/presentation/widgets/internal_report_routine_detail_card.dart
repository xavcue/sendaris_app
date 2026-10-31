import 'package:flutter/material.dart';

import '../../../frequency/domain/models/monthly_calendar_record.dart';
import '../../../routine_status/domain/models/routine_status.dart';
import '../../../routine_status/domain/models/routine_status_record.dart';
import '../../domain/models/internal_report.dart';
import '../models/internal_report_routine_details.dart';

/// Recupera observaciones de estados de rutina ya incluidos en el reporte.
///
/// No consulta Firebase ni otros repositorios. Verifica la identidad,
/// el registro original, su rutina, fecha y estado antes de mostrar datos.
abstract final class InternalReportRoutineObservation {
  static String? resolve(
    InternalReport report,
    InternalReportRoutineEntry entry,
  ) {
    final anonymousId = report.anonymousId.trim();

    if (anonymousId.isEmpty || report.routines.anonymousId != anonymousId) {
      return null;
    }

    for (final record in report.records) {
      if (record.type != CalendarRecordType.routineStatus ||
          record.anonymousId != anonymousId ||
          record.id != entry.recordId) {
        continue;
      }

      final source = record.sourceRecord;

      if (source is! RoutineStatusRecord ||
          source.recordId != entry.recordId ||
          source.anonymousId != anonymousId ||
          source.status != entry.status ||
          !_sameDay(source.date, entry.date) ||
          !_sameDay(record.date, entry.date)) {
        continue;
      }

      final belongsToRoutine = report.routines.result.entries.any(
        (original) =>
            original.recordId == entry.recordId &&
            original.anonymousId == anonymousId &&
            original.routineId == source.routineId &&
            original.status == entry.status &&
            _sameDay(original.date, entry.date),
      );

      if (!belongsToRoutine) {
        continue;
      }

      final observation = source.observation
          ?.replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (observation != null && observation.isNotEmpty) {
        return observation;
      }
    }

    return null;
  }

  static bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

/// Presenta un estado individual de rutina dentro de Reportes internos.
///
/// La tarjeta es de solo lectura y utiliza el modelo compartido
/// InternalReportRoutineDetails, igual que el generador PDF.
class InternalReportRoutineDetailCard extends StatelessWidget {
  const InternalReportRoutineDetailCard({
    required this.report,
    required this.entry,
    super.key,
  });

  final InternalReport report;
  final InternalReportRoutineEntry entry;

  Color _statusColor(ColorScheme colors) {
    return switch (entry.status) {
      RoutineStatus.completed => colors.primary,
      RoutineStatus.modified => colors.tertiary,
      RoutineStatus.interrupted => Colors.orange.shade800,
      RoutineStatus.notCompleted => colors.error,
    };
  }

  IconData get _statusIcon {
    return switch (entry.status) {
      RoutineStatus.completed => Icons.check_circle_outline_rounded,
      RoutineStatus.modified => Icons.edit_note_outlined,
      RoutineStatus.interrupted => Icons.pause_circle_outline_rounded,
      RoutineStatus.notCompleted => Icons.cancel_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final statusColor = _statusColor(colors);

    final observation = InternalReportRoutineObservation.resolve(report, entry);

    return Card(
      key: Key('internal-report-routine-detail-${entry.recordId}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.event_repeat_outlined,
                  color: colors.primary,
                  size: 25,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.routineName,
                        key: Key(
                          'internal-report-routine-name-${entry.recordId}',
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        entry.dateLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: statusColor.withAlpha(22),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_statusIcon, color: statusColor, size: 17),
                  const SizedBox(width: 6),
                  Text(
                    entry.statusLabel,
                    key: Key(
                      'internal-report-routine-status-${entry.recordId}',
                    ),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            if (observation != null) ...[
              const SizedBox(height: 13),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 11),
              Text(
                'Observación registrada',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                observation,
                key: Key(
                  'internal-report-routine-observation-${entry.recordId}',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
