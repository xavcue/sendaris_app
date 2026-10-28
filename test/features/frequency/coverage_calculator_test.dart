import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/frequency/domain/services/coverage_calculator.dart';

void main() {
  MonthlyCalendarRecord record({
    required String id,
    required DateTime date,
    required CalendarRecordType type,
    String anonymousId = 'perfil-a',
  }) {
    return MonthlyCalendarRecord(
      id: id,
      anonymousId: anonymousId,
      date: date,
      type: type,
      description: type.label,
    );
  }

  MonthlyCalendarIndex createIndex(List<MonthlyCalendarRecord> records) {
    return MonthlyCalendarIndex(anonymousId: 'perfil-a', records: records);
  }

  group('CoverageCalculator - HU-21 / MET-01', () {
    test('calcula la cobertura utilizando días distintos', () {
      final index = createIndex([
        record(
          id: 'conducta',
          date: DateTime(2026, 10, 1),
          type: CalendarRecordType.behavior,
        ),
        record(
          id: 'sueno',
          date: DateTime(2026, 10, 1),
          type: CalendarRecordType.sleep,
        ),
        record(
          id: 'alimentacion',
          date: DateTime(2026, 10, 5),
          type: CalendarRecordType.feeding,
        ),
        record(
          id: 'rutina',
          date: DateTime(2026, 10, 10),
          type: CalendarRecordType.routineStatus,
        ),
      ]);

      final result = CoverageCalculator.calculate(
        index: index,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 10),
      );

      expect(result.anonymousId, 'perfil-a');
      expect(result.totalDays, 10);
      expect(result.daysWithRecords, 3);
      expect(result.daysWithoutRecords, 7);
      expect(result.percentage, 30.0);
      expect(result.hasRecords, isTrue);
    });

    test('presenta cero cuando no existen registros', () {
      final index = createIndex([]);

      final result = CoverageCalculator.calculate(
        index: index,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
      );

      expect(result.totalDays, 31);
      expect(result.daysWithRecords, 0);
      expect(result.daysWithoutRecords, 31);
      expect(result.percentage, 0.0);
      expect(result.hasRecords, isFalse);
    });

    test('cuenta una sola vez los registros del mismo día', () {
      final index = createIndex([
        for (var i = 0; i < CalendarRecordType.values.length; i++)
          record(
            id: 'registro-$i',
            date: DateTime(2026, 10, 15, i),
            type: CalendarRecordType.values[i],
          ),
      ]);

      final result = CoverageCalculator.calculate(
        index: index,
        startDate: DateTime(2026, 10, 15),
        endDate: DateTime(2026, 10, 16),
      );

      expect(index.countFor(DateTime(2026, 10, 15)), 7);
      expect(result.daysWithRecords, 1);
      expect(result.totalDays, 2);
      expect(result.percentage, 50.0);
    });

    test('excluye registros de otros seguimientos', () {
      final index = createIndex([
        record(
          id: 'perfil-a-registro',
          date: DateTime(2026, 10, 1),
          type: CalendarRecordType.behavior,
        ),
        record(
          id: 'perfil-b-registro',
          anonymousId: 'perfil-b',
          date: DateTime(2026, 10, 2),
          type: CalendarRecordType.sleep,
        ),
      ]);

      final result = CoverageCalculator.calculate(
        index: index,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 2),
      );

      expect(result.anonymousId, 'perfil-a');
      expect(result.daysWithRecords, 1);
      expect(result.percentage, 50.0);
    });

    test('incluye correctamente ambas fechas del periodo', () {
      final index = createIndex([
        record(
          id: 'primero',
          date: DateTime(2026, 10, 5),
          type: CalendarRecordType.behavior,
        ),
        record(
          id: 'ultimo',
          date: DateTime(2026, 10, 15),
          type: CalendarRecordType.sleep,
        ),
        record(
          id: 'fuera',
          date: DateTime(2026, 10, 16),
          type: CalendarRecordType.feeding,
        ),
      ]);

      final result = CoverageCalculator.calculate(
        index: index,
        startDate: DateTime(2026, 10, 5),
        endDate: DateTime(2026, 10, 15),
      );

      expect(result.totalDays, 11);
      expect(result.daysWithRecords, 2);
      expect(result.percentage, closeTo(18.1818, 0.001));
    });

    test('funciona con un periodo de un solo día', () {
      final index = createIndex([
        record(
          id: 'uno',
          date: DateTime(2026, 10, 15, 20, 30),
          type: CalendarRecordType.behavior,
        ),
      ]);

      final result = CoverageCalculator.calculate(
        index: index,
        startDate: DateTime(2026, 10, 15, 8),
        endDate: DateTime(2026, 10, 15, 23),
      );

      expect(result.startDate, DateTime(2026, 10, 15));
      expect(result.endDate, DateTime(2026, 10, 15));
      expect(result.totalDays, 1);
      expect(result.daysWithRecords, 1);
      expect(result.percentage, 100.0);
    });

    test('respeta el cambio de mes y el año bisiesto', () {
      final index = createIndex([
        record(
          id: 'febrero-28',
          date: DateTime(2024, 2, 28),
          type: CalendarRecordType.behavior,
        ),
        record(
          id: 'febrero-29',
          date: DateTime(2024, 2, 29),
          type: CalendarRecordType.sleep,
        ),
        record(
          id: 'marzo-1',
          date: DateTime(2024, 3, 1),
          type: CalendarRecordType.feeding,
        ),
      ]);

      final result = CoverageCalculator.calculate(
        index: index,
        startDate: DateTime(2024, 2, 28),
        endDate: DateTime(2024, 3, 1),
      );

      expect(result.totalDays, 3);
      expect(result.daysWithRecords, 3);
      expect(result.percentage, 100.0);
    });

    test('rechaza un periodo con fechas invertidas', () {
      final index = createIndex([]);

      expect(
        () => CoverageCalculator.calculate(
          index: index,
          startDate: DateTime(2026, 10, 20),
          endDate: DateTime(2026, 10, 10),
        ),
        throwsArgumentError,
      );

      expect(
        () => index.countDaysWithRecords(
          startDate: DateTime(2026, 10, 20),
          endDate: DateTime(2026, 10, 10),
        ),
        throwsArgumentError,
      );
    });

    test('no modifica el historial al calcular cobertura', () {
      final index = createIndex([
        record(
          id: 'uno',
          date: DateTime(2026, 10, 1),
          type: CalendarRecordType.behavior,
        ),
        record(
          id: 'dos',
          date: DateTime(2026, 10, 1),
          type: CalendarRecordType.sleep,
        ),
      ]);

      expect(index.countFor(DateTime(2026, 10, 1)), 2);

      final result = CoverageCalculator.calculate(
        index: index,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
      );

      expect(result.daysWithRecords, 1);
      expect(index.countFor(DateTime(2026, 10, 1)), 2);
      expect(index.countForMonth(DateTime(2026, 10)), 2);
    });

    test('el resultado no depende de los filtros del calendario', () {
      final index = createIndex([
        record(
          id: 'conducta',
          date: DateTime(2026, 10, 1),
          type: CalendarRecordType.behavior,
        ),
        record(
          id: 'sueno',
          date: DateTime(2026, 10, 2),
          type: CalendarRecordType.sleep,
        ),
      ]);

      expect(
        index.countForMonth(
          DateTime(2026, 10),
          selectedTypes: {CalendarRecordType.behavior},
        ),
        1,
      );

      final result = CoverageCalculator.calculate(
        index: index,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 2),
      );

      expect(result.daysWithRecords, 2);
      expect(result.percentage, 100.0);
    });
  });
}
