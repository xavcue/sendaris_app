import 'package:flutter/material.dart';

import '../../../atypical_situation/domain/models/atypical_situation_record.dart';
import '../../../behavior/domain/models/behavior_record.dart';
import '../../../duration/presentation/widgets/duration_summary_cards.dart';
import '../../../dysregulation/domain/models/dysregulation_record.dart';
import '../../../feeding/domain/models/feeding_record.dart';
import '../../../frequency/domain/models/monthly_calendar_record.dart';
import '../../../sleep/domain/models/sleep_record.dart';
import '../../../social_interaction/domain/models/social_interaction_record.dart';

/// Información descriptiva de un acontecimiento del reporte.
///
/// Utiliza únicamente los datos transitorios del registro recuperado.
/// No consulta repositorios ni modifica información persistente.
class InternalReportEventDetails {
  InternalReportEventDetails._({
    required this.record,
    required this.dateText,
    required this.description,
    required List<InternalReportEventField> fields,
  }) : fields = List<InternalReportEventField>.unmodifiable(fields);

  final MonthlyCalendarRecord record;
  final String dateText;
  final String description;
  final List<InternalReportEventField> fields;

  /// No proyecta estados de rutina ni registros de otro seguimiento.
  ///
  /// Los campos del registro fuente solo se incorporan cuando su
  /// identificador, seguimiento y fecha coinciden con el acontecimiento.
  static InternalReportEventDetails? fromRecord(
    MonthlyCalendarRecord record, {
    required String anonymousId,
  }) {
    if (anonymousId.trim().isEmpty ||
        record.anonymousId != anonymousId ||
        record.type == CalendarRecordType.routineStatus) {
      return null;
    }

    final eventDate = record.chronologicalDate;
    final date = DurationSummaryCards.formatDate(eventDate);

    final hasTime = record.eventDateTime != null;
    final hour = eventDate.hour.toString().padLeft(2, '0');
    final minute = eventDate.minute.toString().padLeft(2, '0');

    final dateText = hasTime ? '$date · $hour:$minute' : date;
    final description = _clean(record.description) ?? 'Sin descripción';

    final fields = <InternalReportEventField>[];
    final source = record.sourceRecord;

    bool matches(String id, String owner, DateTime date) {
      return id == record.id &&
          owner == anonymousId &&
          _sameDay(date, record.date);
    }

    if (record.type == CalendarRecordType.behavior &&
        source is BehaviorRecord &&
        matches(source.recordId, source.anonymousId, source.date)) {
      _add(fields, 'Intensidad', source.intensity?.label);

      if (source.durationMinutes != null) {
        _add(fields, 'Duración', '${source.durationMinutes} min');
      }

      _add(fields, 'Contexto', source.context);
      _add(fields, 'Observación', source.observation);
    } else if (record.type == CalendarRecordType.sleep &&
        source is SleepRecord &&
        matches(source.recordId, source.anonymousId, source.date)) {
      _add(fields, 'Inicio', source.startTime);
      _add(fields, 'Fin', source.endTime);
      _add(fields, 'Observación', source.observation);
    } else if (record.type == CalendarRecordType.feeding &&
        source is FeedingRecord &&
        matches(source.recordId, source.anonymousId, source.date)) {
      _add(fields, 'Observación', source.observation);
    } else if (record.type == CalendarRecordType.socialInteraction &&
        source is SocialInteractionRecord &&
        matches(source.recordId, source.anonymousId, source.date)) {
      _add(fields, 'Contexto', source.context);
      _add(fields, 'Observación', source.observation);
    } else if (record.type == CalendarRecordType.dysregulation &&
        source is DysregulationRecord &&
        matches(source.recordId, source.anonymousId, source.date)) {
      _add(fields, 'Intensidad', source.intensity?.label);

      if (source.durationMinutes != null) {
        _add(fields, 'Duración', '${source.durationMinutes} min');
      }

      _add(fields, 'Contexto', source.context);
      _add(fields, 'Observación', source.observation);
    } else if (record.type == CalendarRecordType.atypicalSituation &&
        source is AtypicalSituationRecord &&
        matches(source.recordId, source.anonymousId, source.date)) {
      _add(fields, 'Observación', source.observation);
    }

    return InternalReportEventDetails._(
      record: record,
      dateText: dateText,
      description: description,
      fields: fields,
    );
  }

  static void _add(
    List<InternalReportEventField> fields,
    String label,
    String? value,
  ) {
    final cleanValue = _clean(value);

    if (cleanValue != null) {
      fields.add(InternalReportEventField(label: label, value: cleanValue));
    }
  }

  static String? _clean(String? value) {
    final cleaned = value?.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned == null || cleaned.isEmpty) {
      return null;
    }

    return cleaned;
  }

  static bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class InternalReportEventField {
  const InternalReportEventField({required this.label, required this.value});

  final String label;
  final String value;
}

/// Tarjeta visual del detalle de un evento.
///
/// Es exclusivamente de lectura. No ofrece acciones de modificación,
/// exportación, impresión o divulgación.
class InternalReportEventCard extends StatelessWidget {
  const InternalReportEventCard({
    required this.record,
    required this.anonymousId,
    super.key,
  });

  final MonthlyCalendarRecord record;
  final String anonymousId;

  IconData get _icon {
    return switch (record.type) {
      CalendarRecordType.behavior => Icons.psychology_outlined,
      CalendarRecordType.sleep => Icons.bedtime_outlined,
      CalendarRecordType.feeding => Icons.restaurant_outlined,
      CalendarRecordType.socialInteraction => Icons.groups_outlined,
      CalendarRecordType.dysregulation => Icons.self_improvement_rounded,
      CalendarRecordType.atypicalSituation => Icons.event_note_outlined,
      CalendarRecordType.routineStatus => Icons.fact_check_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final details = InternalReportEventDetails.fromRecord(
      record,
      anonymousId: anonymousId,
    );

    if (details == null) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      key: Key('internal-report-record-${record.type.name}-${record.id}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icon, color: colors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.type.label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        details.dateText,
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
            Text(
              details.description,
              key: Key(
                'internal-report-description-${record.type.name}-${record.id}',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
            ),
            if (details.fields.isNotEmpty) ...[
              const SizedBox(height: 13),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 12),
              for (final field in details.fields) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 94,
                        child: Text(
                          field.label,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          field.value,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurface,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
