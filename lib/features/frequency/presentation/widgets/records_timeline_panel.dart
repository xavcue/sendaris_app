import 'package:flutter/material.dart';

import '../../domain/models/monthly_calendar_record.dart';

class RecordsTimelinePanel extends StatelessWidget {
  const RecordsTimelinePanel({
    required this.records,
    required this.ascending,
    required this.onOrderChanged,
    required this.onRecordTap,
    super.key,
  });

  final List<MonthlyCalendarRecord> records;
  final bool ascending;
  final ValueChanged<bool> onOrderChanged;
  final ValueChanged<MonthlyCalendarRecord> onRecordTap;

  static const _months = <String>[
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  static DateTime _day(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _dateLabel(DateTime date) {
    return '${date.day} de ${_months[date.month - 1]} de ${date.year}';
  }

  static String _timeLabel(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  static int _compare(
    MonthlyCalendarRecord a,
    MonthlyCalendarRecord b,
    bool ascending,
  ) {
    final dayResult = _day(a.date).compareTo(_day(b.date));

    if (dayResult != 0) {
      return ascending ? dayResult : -dayResult;
    }

    // La falta de hora no se interpreta como medianoche.
    // Dentro del mismo dia, los registros sin hora van
    // despues de los que tienen una hora conocida.
    final aTime = a.eventDateTime;
    final bTime = b.eventDateTime;

    if (aTime == null && bTime != null) {
      return 1;
    }

    if (aTime != null && bTime == null) {
      return -1;
    }

    if (aTime != null && bTime != null) {
      final result = aTime.compareTo(bTime);

      if (result != 0) {
        return ascending ? result : -result;
      }
    }

    final aCreated = a.createdAt;
    final bCreated = b.createdAt;

    if (aCreated != null && bCreated != null) {
      final result = aCreated.compareTo(bCreated);

      if (result != 0) {
        return ascending ? result : -result;
      }
    } else if (aCreated != null) {
      return -1;
    } else if (bCreated != null) {
      return 1;
    }

    final typeResult = a.type.index.compareTo(b.type.index);

    if (typeResult != 0) {
      return typeResult;
    }

    return a.id.compareTo(b.id);
  }

  static IconData _icon(CalendarRecordType type) {
    return switch (type) {
      CalendarRecordType.behavior => Icons.psychology_outlined,
      CalendarRecordType.sleep => Icons.bedtime_outlined,
      CalendarRecordType.feeding => Icons.restaurant_outlined,
      CalendarRecordType.socialInteraction => Icons.people_outline_rounded,
      CalendarRecordType.dysregulation => Icons.self_improvement_rounded,
      CalendarRecordType.atypicalSituation => Icons.event_note_outlined,
      CalendarRecordType.routineStatus => Icons.event_available_outlined,
    };
  }

  static Color _accent(CalendarRecordType type) {
    return switch (type) {
      CalendarRecordType.behavior => const Color(0xFF4EA78D),
      CalendarRecordType.sleep => const Color(0xFF9784D4),
      CalendarRecordType.feeding => const Color(0xFFD6A46C),
      CalendarRecordType.socialInteraction => const Color(0xFF6DABD3),
      CalendarRecordType.dysregulation => const Color(0xFFD38D9A),
      CalendarRecordType.atypicalSituation => const Color(0xFFA3A9C6),
      CalendarRecordType.routineStatus => const Color(0xFF6BBDA9),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final sorted = records.toList(growable: false)
      ..sort((a, b) => _compare(a, b, ascending));

    final groups = <DateTime, List<MonthlyCalendarRecord>>{};

    for (final record in sorted) {
      groups
          .putIfAbsent(_day(record.date), () => <MonthlyCalendarRecord>[])
          .add(record);
    }

    final days = groups.entries.toList(growable: false);

    return Column(
      key: const Key('records-timeline-panel'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${sorted.length} '
                '${sorted.length == 1 ? 'acontecimiento' : 'acontecimientos'}',
                key: const Key('records-timeline-count'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              key: const Key('records-timeline-order'),
              onPressed: () => onOrderChanged(!ascending),
              icon: Icon(
                ascending
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 17,
              ),
              label: Text(ascending ? 'Antiguos primero' : 'Recientes primero'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (sorted.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'Sin acontecimientos para el período '
              'y las categorías seleccionadas.',
              key: const Key('records-timeline-empty'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
          )
        else
          for (var dayIndex = 0; dayIndex < days.length; dayIndex++) ...[
            _TimelineDateHeader(
              date: days[dayIndex].key,
              title: _dateLabel(days[dayIndex].key),
              count: days[dayIndex].value.length,
              isFirst: dayIndex == 0,
            ),
            for (
              var recordIndex = 0;
              recordIndex < days[dayIndex].value.length;
              recordIndex++
            )
              _TimelineEventRow(
                record: days[dayIndex].value[recordIndex],
                icon: _icon(days[dayIndex].value[recordIndex].type),
                accent: _accent(days[dayIndex].value[recordIndex].type),
                timeLabel:
                    days[dayIndex].value[recordIndex].eventDateTime == null
                    ? 'Hora no registrada'
                    : 'Hora: ${_timeLabel(days[dayIndex].value[recordIndex].eventDateTime!)}',
                isLast:
                    dayIndex == days.length - 1 &&
                    recordIndex == days[dayIndex].value.length - 1,
                onTap: days[dayIndex].value[recordIndex].sourceRecord == null
                    ? null
                    : () => onRecordTap(days[dayIndex].value[recordIndex]),
              ),
          ],
        const SizedBox(height: 18),
        Text(
          'Secuencia descriptiva de registros. '
          'Las categorías y los colores no indican gravedad. '
          'Los acontecimientos sin hora registrada no tienen '
          'una posición horaria determinada.',
          key: const Key('records-timeline-note'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Los encabezados de fecha usan una paleta propia,
/// coherente con la identidad visual de Sendaris.
///
/// Las tarjetas de acontecimientos mantienen los colores
/// correspondientes a sus respectivas categorias.
class _TimelineDateHeader extends StatelessWidget {
  const _TimelineDateHeader({
    required this.date,
    required this.title,
    required this.count,
    required this.isFirst,
  });

  final DateTime date;
  final String title;
  final int count;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Paleta especifica para los hitos de fecha.
    // Se adapta al tema oscuro y claro.
    final headerBackground = isDark
        ? const Color(0xFF17484B)
        : const Color(0xFFDDEFEA);

    final headerBorder = isDark
        ? const Color(0xFF397C7A)
        : const Color(0xFF86B9AD);

    final titleColor = isDark
        ? const Color(0xFFF4FFFC)
        : const Color(0xFF173B38);

    final countColor = isDark
        ? const Color(0xFFB9E9E3)
        : const Color(0xFF326E66);

    final dayBackground = isDark
        ? const Color(0xFF9FE3D6)
        : const Color(0xFF226D66);

    final dayForeground = isDark
        ? const Color(0xFF103531)
        : const Color(0xFFFFFFFF);

    final lineColor = colors.primary.withValues(alpha: 0.50);

    final dayKey = '${date.year}-${date.month}-${date.day}';

    return IntrinsicHeight(
      child: Stack(
        children: [
          // El eje conecta el hito de fecha con
          // los acontecimientos del mismo dia.
          Positioned(
            left: 21,
            top: isFirst ? 29 : 0,
            bottom: 0,
            width: 2,
            child: ColoredBox(color: lineColor),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 44,
                child: Stack(
                  children: [
                    Positioned(
                      left: 5,
                      top: 12,
                      child: Container(
                        key: Key('records-timeline-day-node-$dayKey'),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: dayBackground,
                          border: Border.all(color: headerBorder, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${date.day}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: dayForeground,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  key: Key('records-timeline-date-$dayKey'),
                  margin: const EdgeInsets.only(top: 5, bottom: 11),
                  padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
                  decoration: BoxDecoration(
                    color: headerBackground,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: headerBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$count '
                        '${count == 1 ? 'acontecimiento' : 'acontecimientos'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: countColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Un acontecimiento se dibuja sobre el mismo eje
/// que los hitos de fecha.
///
/// El ultimo nodo cierra el recorrido.
class _TimelineEventRow extends StatelessWidget {
  const _TimelineEventRow({
    required this.record,
    required this.icon,
    required this.accent,
    required this.timeLabel,
    required this.isLast,
    required this.onTap,
  });

  final MonthlyCalendarRecord record;
  final IconData icon;
  final Color accent;
  final String timeLabel;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final lineColor = colors.primary.withValues(alpha: 0.50);

    final recordKey = '${record.type.name}-${record.id}';

    return IntrinsicHeight(
      child: Stack(
        children: [
          // Segmento anterior: conecta el nodo con el
          // registro anterior o el hito de fecha.
          Positioned(
            left: 21,
            top: 0,
            height: 31,
            width: 2,
            child: ColoredBox(color: lineColor),
          ),

          // Continua incluso si el siguiente elemento
          // pertenece a otro dia del mismo periodo.
          if (!isLast)
            Positioned(
              left: 21,
              top: 31,
              bottom: 0,
              width: 2,
              child: ColoredBox(
                key: Key('records-timeline-link-$recordKey'),
                color: lineColor,
              ),
            ),

          // Conector horizontal hasta la tarjeta.
          Positioned(
            left: 22,
            top: 30,
            width: 34,
            height: 2,
            child: ColoredBox(color: accent.withValues(alpha: 0.70)),
          ),

          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 44,
                child: Stack(
                  children: [
                    Positioned(
                      left: 5,
                      top: 14,
                      child: Container(
                        key: Key('records-timeline-node-$recordKey'),
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.alphaBlend(
                            accent.withValues(alpha: 0.13),
                            colors.surface,
                          ),
                          border: Border.all(color: accent, width: 2),
                        ),
                        child: Icon(icon, size: 18, color: accent),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    key: Key('records-timeline-record-$recordKey'),
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    color: colors.surfaceContainerLow,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: accent.withValues(alpha: 0.48)),
                    ),
                    child: InkWell(
                      onTap: onTap,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(13, 12, 9, 12),
                        child: Row(
                          children: [
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
                                  const SizedBox(height: 4),
                                  Text(
                                    record.description,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: colors.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    timeLabel,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: accent,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (onTap != null)
                              Icon(
                                Icons.chevron_right_rounded,
                                color: colors.onSurfaceVariant,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
