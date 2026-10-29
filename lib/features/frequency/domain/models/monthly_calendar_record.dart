enum CalendarRecordType {
  behavior('Conducta'),
  sleep('Sueño'),
  feeding('Alimentación'),
  socialInteraction('Interacción social'),
  dysregulation('Desregulación'),
  atypicalSituation('Otra situación'),
  routineStatus('Estado de rutina');

  const CalendarRecordType(this.label);

  final String label;
}

class MonthlyCalendarRecord {
  const MonthlyCalendarRecord({
    required this.id,
    required this.anonymousId,
    required this.date,
    required this.type,
    required this.description,
    this.eventDateTime,
    this.createdAt,
    this.sourceRecord,
  });

  final String id;
  final String anonymousId;
  final DateTime date;
  final CalendarRecordType type;
  final String description;

  // HU-19: fecha y hora del evento, cuando se dispone de ella.
  // Si el tipo no registra hora, se utiliza su fecha original.
  final DateTime? eventDateTime;

  // Permite desempatar acontecimientos con la misma fecha de evento.
  // Corresponde a la creación del registro fuente.
  final DateTime? createdAt;

  // Registro original que consumen las pantallas de detalle.
  // No se persiste ni constituye una copia en Firestore.
  final Object? sourceRecord;

  DateTime get chronologicalDate => eventDateTime ?? date;
}

class MonthlyCalendarIndex {
  MonthlyCalendarIndex({
    required String anonymousId,
    required Iterable<MonthlyCalendarRecord> records,
  }) : _anonymousId = anonymousId.trim(),
       _byDate = _group(anonymousId.trim(), records);

  final String _anonymousId;
  final Map<DateTime, List<MonthlyCalendarRecord>> _byDate;

  String get anonymousId => _anonymousId;

  List<MonthlyCalendarRecord> recordsFor(
    DateTime date, {
    Set<CalendarRecordType>? selectedTypes,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    final day = _dayOnly(date);

    if (!_withinRange(day, startDate, endDate)) {
      return const <MonthlyCalendarRecord>[];
    }

    final records = _byDate[day] ?? const <MonthlyCalendarRecord>[];

    if (selectedTypes == null) {
      return records;
    }

    return List<MonthlyCalendarRecord>.unmodifiable(
      records.where((record) => selectedTypes.contains(record.type)),
    );
  }

  int countFor(
    DateTime date, {
    Set<CalendarRecordType>? selectedTypes,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    return recordsFor(
      date,
      selectedTypes: selectedTypes,
      startDate: startDate,
      endDate: endDate,
    ).length;
  }

  int countForMonth(
    DateTime month, {
    Set<CalendarRecordType>? selectedTypes,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    var count = 0;

    for (final entry in _byDate.entries) {
      final day = entry.key;

      if (day.year != month.year ||
          day.month != month.month ||
          !_withinRange(day, startDate, endDate)) {
        continue;
      }

      if (selectedTypes == null) {
        count += entry.value.length;
      } else {
        count += entry.value
            .where((record) => selectedTypes.contains(record.type))
            .length;
      }
    }

    return count;
  }

  // HU-19: consulta derivada de registros en un intervalo inclusivo.
  // No modifica los registros fuente ni el índice.
  // El orden cronológico se aplica posteriormente en TimelineCalculator.
  List<MonthlyCalendarRecord> recordsInPeriod({
    required DateTime startDate,
    required DateTime endDate,
    Set<CalendarRecordType>? selectedTypes,
  }) {
    final start = _dayOnly(startDate);
    final end = _dayOnly(endDate);

    if (end.isBefore(start)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'La fecha final no puede ser anterior a la inicial.',
      );
    }

    final result = <MonthlyCalendarRecord>[];

    for (final entry in _byDate.entries) {
      final day = entry.key;

      if (day.isBefore(start) || day.isAfter(end)) {
        continue;
      }

      for (final record in entry.value) {
        if (selectedTypes == null || selectedTypes.contains(record.type)) {
          result.add(record);
        }
      }
    }

    return List<MonthlyCalendarRecord>.unmodifiable(result);
  }

  // HU-21 / MET-01:
  // Cuenta cada fecha con al menos un registro una sola vez.
  // Se consideran todos los tipos y no se aplican los filtros
  // visuales del calendario.
  int countDaysWithRecords({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = _dayOnly(startDate);
    final end = _dayOnly(endDate);

    if (end.isBefore(start)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'La fecha final no puede ser anterior a la inicial.',
      );
    }

    var daysWithRecords = 0;

    for (final day in _byDate.keys) {
      if (!day.isBefore(start) && !day.isAfter(end)) {
        daysWithRecords++;
      }
    }

    return daysWithRecords;
  }

  static DateTime _dayOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _withinRange(
    DateTime date,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    final start = startDate == null ? null : _dayOnly(startDate);
    final end = endDate == null ? null : _dayOnly(endDate);

    if (start != null && date.isBefore(start)) {
      return false;
    }

    if (end != null && date.isAfter(end)) {
      return false;
    }

    return true;
  }

  static Map<DateTime, List<MonthlyCalendarRecord>> _group(
    String anonymousId,
    Iterable<MonthlyCalendarRecord> records,
  ) {
    if (anonymousId.isEmpty || anonymousId.contains('/')) {
      throw ArgumentError.value(anonymousId, 'anonymousId');
    }

    final grouped = <DateTime, List<MonthlyCalendarRecord>>{};
    final seen = <String>{};

    for (final record in records) {
      if (record.anonymousId != anonymousId) {
        continue;
      }

      final identifier = '${record.type.name}:${record.id}';

      if (!seen.add(identifier)) {
        continue;
      }

      final day = _dayOnly(record.date);

      grouped.putIfAbsent(day, () => <MonthlyCalendarRecord>[]).add(record);
    }

    for (final values in grouped.values) {
      values.sort((a, b) {
        final dateOrder = a.date.compareTo(b.date);

        if (dateOrder != 0) {
          return dateOrder;
        }

        return a.id.compareTo(b.id);
      });
    }

    return Map<DateTime, List<MonthlyCalendarRecord>>.unmodifiable(
      grouped.map(
        (key, value) =>
            MapEntry(key, List<MonthlyCalendarRecord>.unmodifiable(value)),
      ),
    );
  }
}
