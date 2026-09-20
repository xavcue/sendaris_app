import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_query.dart';
import 'package:sendaris/features/routine_compliance/domain/services/routine_compliance_calculator.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

void main() {
  group('RoutineComplianceCalculator', () {
    test('calcula correctamente programadas completadas y porcentaje', () {
      final result = RoutineComplianceCalculator.calculate(
        query: _query(),
        entries: [
          _entry(
            id: 'e1',
            routineId: 'r1',
            date: DateTime(2026, 9, 5),
            status: RoutineStatus.completed,
          ),
          _entry(
            id: 'e2',
            routineId: 'r2',
            date: DateTime(2026, 9, 6),
            status: RoutineStatus.completed,
          ),
          _entry(
            id: 'e3',
            routineId: 'r3',
            date: DateTime(2026, 9, 7),
            status: RoutineStatus.modified,
          ),
          _entry(
            id: 'e4',
            routineId: 'r4',
            date: DateTime(2026, 9, 8),
            status: RoutineStatus.notCompleted,
          ),
        ],
      );

      expect(result.programmedCount, 4);

      expect(result.completedCount, 2);

      expect(result.compliancePercentage, 50);
    });

    test('solo completada incrementa el conteo de completadas', () {
      final result = RoutineComplianceCalculator.calculate(
        query: _query(),
        entries: [
          _entry(
            id: 'completada',
            routineId: 'r1',
            date: DateTime(2026, 9, 5),
            status: RoutineStatus.completed,
          ),
          _entry(
            id: 'modificada',
            routineId: 'r2',
            date: DateTime(2026, 9, 6),
            status: RoutineStatus.modified,
          ),
          _entry(
            id: 'interrumpida',
            routineId: 'r3',
            date: DateTime(2026, 9, 7),
            status: RoutineStatus.interrupted,
          ),
          _entry(
            id: 'no-realizada',
            routineId: 'r4',
            date: DateTime(2026, 9, 8),
            status: RoutineStatus.notCompleted,
          ),
        ],
      );

      expect(result.programmedCount, 4);

      expect(result.completedCount, 1);

      expect(result.compliancePercentage, 25);
    });

    test('excluye registros fuera del periodo', () {
      final result = RoutineComplianceCalculator.calculate(
        query: _query(),
        entries: [
          _entry(
            id: 'dentro',
            routineId: 'r1',
            date: DateTime(2026, 9, 10),
            status: RoutineStatus.completed,
          ),
          _entry(
            id: 'fuera',
            routineId: 'r2',
            date: DateTime(2026, 9, 20),
            status: RoutineStatus.completed,
          ),
        ],
      );

      expect(result.programmedCount, 1);

      expect(result.completedCount, 1);

      expect(result.compliancePercentage, 100);
    });

    test('incluye las fechas inicial y final', () {
      final result = RoutineComplianceCalculator.calculate(
        query: _query(),
        entries: [
          _entry(
            id: 'inicio',
            routineId: 'r1',
            date: DateTime(2026, 9, 1),
            status: RoutineStatus.completed,
          ),
          _entry(
            id: 'fin',
            routineId: 'r2',
            date: DateTime(2026, 9, 15),
            status: RoutineStatus.modified,
          ),
        ],
      );

      expect(result.programmedCount, 2);

      expect(result.completedCount, 1);

      expect(result.compliancePercentage, 50);
    });

    test('excluye registros de otro perfil anónimo', () {
      final result = RoutineComplianceCalculator.calculate(
        query: _query(),
        entries: [
          _entry(
            id: 'perfil-a',
            routineId: 'r1',
            date: DateTime(2026, 9, 5),
            status: RoutineStatus.completed,
          ),
          _entry(
            id: 'perfil-b',
            anonymousId: 'perfil-b',
            routineId: 'r2',
            date: DateTime(2026, 9, 6),
            status: RoutineStatus.completed,
          ),
        ],
      );

      expect(result.programmedCount, 1);

      expect(result.completedCount, 1);
    });

    test('periodo sin ocurrencias no genera porcentaje', () {
      final result = RoutineComplianceCalculator.calculate(
        query: _query(),
        entries: const [],
      );

      expect(result.programmedCount, 0);

      expect(result.completedCount, 0);

      expect(result.compliancePercentage, isNull);
    });

    test(
      'con rutinas programadas y ninguna completada devuelve cero por ciento',
      () {
        final result = RoutineComplianceCalculator.calculate(
          query: _query(),
          entries: [
            _entry(
              id: 'e1',
              routineId: 'r1',
              date: DateTime(2026, 9, 5),
              status: RoutineStatus.interrupted,
            ),
            _entry(
              id: 'e2',
              routineId: 'r2',
              date: DateTime(2026, 9, 6),
              status: RoutineStatus.notCompleted,
            ),
          ],
        );

        expect(result.programmedCount, 2);

        expect(result.completedCount, 0);

        expect(result.compliancePercentage, 0);
      },
    );

    test('mantiene completadas dentro del rango de programadas', () {
      final result = RoutineComplianceCalculator.calculate(
        query: _query(),
        entries: [
          _entry(
            id: 'e1',
            routineId: 'r1',
            date: DateTime(2026, 9, 5),
            status: RoutineStatus.completed,
          ),
          _entry(
            id: 'e2',
            routineId: 'r2',
            date: DateTime(2026, 9, 6),
            status: RoutineStatus.modified,
          ),
        ],
      );

      expect(result.completedCount, lessThanOrEqualTo(result.programmedCount));

      expect(result.compliancePercentage, inInclusiveRange(0, 100));
    });
  });
}

RoutineComplianceQuery _query() {
  return RoutineComplianceQuery.create(
    anonymousId: 'perfil-a',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 9, 15),
  );
}

RoutineComplianceEntry _entry({
  required String id,
  required String routineId,
  required DateTime date,
  required RoutineStatus status,
  String anonymousId = 'perfil-a',
}) {
  return RoutineComplianceEntry(
    recordId: id,
    anonymousId: anonymousId,
    routineId: routineId,
    date: date,
    status: status,
  );
}
