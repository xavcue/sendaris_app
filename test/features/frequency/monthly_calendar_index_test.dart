import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';

void main() {
  MonthlyCalendarRecord entry(
    String id,
    int day,
    CalendarRecordType type, {
    String anonymousId = 'perfil-a',
    int month = 10,
  }) {
    return MonthlyCalendarRecord(
      id: id,
      anonymousId: anonymousId,
      date: DateTime(2026, month, day),
      type: type,
      description: type.label,
    );
  }

  test('agrupa por día, conserva siete tipos y evita duplicados', () {
    final index = MonthlyCalendarIndex(
      anonymousId: 'perfil-a',
      records: [
        for (var i = 0; i < CalendarRecordType.values.length; i++)
          entry('registro-$i', 15, CalendarRecordType.values[i]),
        entry('registro-0', 15, CalendarRecordType.behavior),
        entry('otro', 15, CalendarRecordType.sleep, anonymousId: 'perfil-b'),
        entry('registro-oct', 1, CalendarRecordType.sleep),
        entry('registro-sep', 1, CalendarRecordType.sleep, month: 9),
      ],
    );

    expect(index.countFor(DateTime(2026, 10, 15)), 7);

    expect(index.countForMonth(DateTime(2026, 10)), 8);

    expect(index.countForMonth(DateTime(2026, 9)), 1);

    expect(index.countFor(DateTime(2026, 10, 2)), 0);
  });

  test('los filtros no alteran los registros originales', () {
    final index = MonthlyCalendarIndex(
      anonymousId: 'perfil-a',
      records: [
        entry('conducta', 5, CalendarRecordType.behavior),
        entry('sueno', 5, CalendarRecordType.sleep),
        entry('rutina', 5, CalendarRecordType.routineStatus),
      ],
    );

    expect(
      index.countFor(
        DateTime(2026, 10, 5),
        selectedTypes: {CalendarRecordType.routineStatus},
      ),
      1,
    );

    expect(
      index.countForMonth(
        DateTime(2026, 10),
        selectedTypes: {CalendarRecordType.behavior, CalendarRecordType.sleep},
      ),
      2,
    );

    expect(index.countFor(DateTime(2026, 10, 5)), 3);
  });

  test('el filtro de fechas incluye ambos extremos', () {
    final index = MonthlyCalendarIndex(
      anonymousId: 'perfil-a',
      records: [
        entry('a', 1, CalendarRecordType.behavior),
        entry('b', 5, CalendarRecordType.sleep),
        entry('c', 10, CalendarRecordType.feeding),
        entry('d', 15, CalendarRecordType.behavior),
        entry('e', 20, CalendarRecordType.sleep),
      ],
    );

    final start = DateTime(2026, 10, 5);
    final end = DateTime(2026, 10, 15);

    expect(
      index.countForMonth(DateTime(2026, 10), startDate: start, endDate: end),
      3,
    );

    expect(
      index.countFor(DateTime(2026, 10, 5), startDate: start, endDate: end),
      1,
    );

    expect(
      index.countFor(DateTime(2026, 10, 15), startDate: start, endDate: end),
      1,
    );

    expect(
      index.countFor(DateTime(2026, 10, 20), startDate: start, endDate: end),
      0,
    );
  });

  test('permite filtrar únicamente desde o hasta', () {
    final index = MonthlyCalendarIndex(
      anonymousId: 'perfil-a',
      records: [
        entry('a', 1, CalendarRecordType.behavior),
        entry('b', 10, CalendarRecordType.behavior),
        entry('c', 20, CalendarRecordType.behavior),
      ],
    );

    expect(
      index.countForMonth(
        DateTime(2026, 10),
        startDate: DateTime(2026, 10, 10),
      ),
      2,
    );

    expect(
      index.countForMonth(DateTime(2026, 10), endDate: DateTime(2026, 10, 10)),
      2,
    );
  });

  test('combina correctamente fechas y tipos', () {
    final index = MonthlyCalendarIndex(
      anonymousId: 'perfil-a',
      records: [
        entry('a', 5, CalendarRecordType.behavior),
        entry('b', 5, CalendarRecordType.sleep),
        entry('c', 10, CalendarRecordType.sleep),
        entry('d', 20, CalendarRecordType.sleep),
      ],
    );

    expect(
      index.countForMonth(
        DateTime(2026, 10),
        selectedTypes: {CalendarRecordType.sleep},
        startDate: DateTime(2026, 10, 5),
        endDate: DateTime(2026, 10, 10),
      ),
      2,
    );
  });

  test('rechaza identificadores de seguimiento inválidos', () {
    expect(
      () => MonthlyCalendarIndex(anonymousId: '', records: []),
      throwsArgumentError,
    );

    expect(
      () => MonthlyCalendarIndex(anonymousId: 'a/b', records: []),
      throwsArgumentError,
    );
  });
}
