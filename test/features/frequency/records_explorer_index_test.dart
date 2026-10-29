import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';

MonthlyCalendarRecord _record({
  required String id,
  required CalendarRecordType type,
  required DateTime date,
  String anonymousId = 'perfil-a',
  DateTime? eventDateTime,
  Object? sourceRecord,
}) {
  return MonthlyCalendarRecord(
    id: id,
    anonymousId: anonymousId,
    date: date,
    type: type,
    description: 'Registro ficticio',
    eventDateTime: eventDateTime,
    sourceRecord: sourceRecord,
  );
}

void main() {
  group('HU-19 - Exploración compartida de registros', () {
    test('recupera las siete categorias sin duplicados', () {
      final date = DateTime(2026, 10, 15);

      final records = [
        for (var i = 0; i < CalendarRecordType.values.length; i++)
          _record(
            id: 'registro-$i',
            type: CalendarRecordType.values[i],
            date: date,
          ),
        _record(
          id: 'registro-0',
          type: CalendarRecordType.behavior,
          date: date,
        ),
      ];

      final index = MonthlyCalendarIndex(
        anonymousId: 'perfil-a',
        records: records,
      );

      final result = index.recordsInPeriod(startDate: date, endDate: date);

      expect(result, hasLength(7));

      expect(
        result.map((item) => item.type).toSet(),
        CalendarRecordType.values.toSet(),
      );

      expect(index.countFor(date), 7);
    });

    test('aisla los registros del seguimiento solicitado', () {
      final date = DateTime(2026, 10, 15);

      final index = MonthlyCalendarIndex(
        anonymousId: 'perfil-a',
        records: [
          _record(
            id: 'registro-a',
            type: CalendarRecordType.behavior,
            date: date,
            anonymousId: 'perfil-a',
          ),
          _record(
            id: 'registro-b',
            type: CalendarRecordType.sleep,
            date: date,
            anonymousId: 'perfil-b',
          ),
        ],
      );

      final result = index.recordsInPeriod(startDate: date, endDate: date);

      expect(result, hasLength(1));
      expect(result.single.id, 'registro-a');
      expect(result.single.anonymousId, 'perfil-a');
    });

    test('incluye ambos extremos del periodo y un dia bisiesto', () {
      final index = MonthlyCalendarIndex(
        anonymousId: 'perfil-a',
        records: [
          _record(
            id: 'anterior',
            type: CalendarRecordType.behavior,
            date: DateTime(2024, 2, 27),
          ),
          _record(
            id: 'inicio',
            type: CalendarRecordType.sleep,
            date: DateTime(2024, 2, 28),
          ),
          _record(
            id: 'bisiesto',
            type: CalendarRecordType.feeding,
            date: DateTime(2024, 2, 29),
          ),
          _record(
            id: 'fin',
            type: CalendarRecordType.routineStatus,
            date: DateTime(2024, 3, 1),
          ),
          _record(
            id: 'posterior',
            type: CalendarRecordType.behavior,
            date: DateTime(2024, 3, 2),
          ),
        ],
      );

      final result = index.recordsInPeriod(
        startDate: DateTime(2024, 2, 28),
        endDate: DateTime(2024, 3, 1),
      );

      expect(result.map((item) => item.id).toSet(), {
        'inicio',
        'bisiesto',
        'fin',
      });
    });

    test('filtra categorias sin modificar los registros', () {
      final date = DateTime(2026, 10, 15);

      final index = MonthlyCalendarIndex(
        anonymousId: 'perfil-a',
        records: [
          _record(
            id: 'conducta',
            type: CalendarRecordType.behavior,
            date: date,
          ),
          _record(id: 'sueno', type: CalendarRecordType.sleep, date: date),
          _record(
            id: 'rutina',
            type: CalendarRecordType.routineStatus,
            date: date,
          ),
        ],
      );

      final filtered = index.recordsInPeriod(
        startDate: date,
        endDate: date,
        selectedTypes: {CalendarRecordType.sleep},
      );

      expect(filtered, hasLength(1));
      expect(filtered.single.id, 'sueno');

      final all = index.recordsInPeriod(startDate: date, endDate: date);

      expect(all, hasLength(3));
      expect(index.countFor(date), 3);
    });

    test('ninguna categoria seleccionada produce una lista vacia', () {
      final date = DateTime(2026, 10, 15);

      final index = MonthlyCalendarIndex(
        anonymousId: 'perfil-a',
        records: [
          _record(
            id: 'conducta',
            type: CalendarRecordType.behavior,
            date: date,
          ),
        ],
      );

      final result = index.recordsInPeriod(
        startDate: date,
        endDate: date,
        selectedTypes: <CalendarRecordType>{},
      );

      expect(result, isEmpty);
      expect(index.countFor(date), 1);
    });

    test('conserva la hora real y el registro original', () {
      final date = DateTime(2026, 10, 15);
      final eventTime = DateTime(2026, 10, 15, 16, 53);
      final original = Object();

      final index = MonthlyCalendarIndex(
        anonymousId: 'perfil-a',
        records: [
          _record(
            id: 'conducta',
            type: CalendarRecordType.behavior,
            date: date,
            eventDateTime: eventTime,
            sourceRecord: original,
          ),
        ],
      );

      final result = index.recordsInPeriod(startDate: date, endDate: date);

      expect(result.single.eventDateTime, eventTime);
      expect(identical(result.single.sourceRecord, original), isTrue);
    });
  });
}
