import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_query.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_result.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

void main() {
  group('RoutineComplianceResult', () {
    test('mantiene trazabilidad con IND-09 y DAT-066 a DAT-068', () {
      expect(RoutineComplianceResult.indicatorCode, 'IND-09');

      expect(RoutineComplianceResult.programmedDataCode, 'DAT-066');

      expect(RoutineComplianceResult.completedDataCode, 'DAT-067');

      expect(RoutineComplianceResult.percentageDataCode, 'DAT-068');
    });

    test('sin ocurrencias programadas no calcula porcentaje', () {
      final result = RoutineComplianceResult(
        query: _query(),
        entries: const [],
      );

      expect(result.programmedCount, 0);

      expect(result.completedCount, 0);

      expect(result.compliancePercentage, isNull);

      expect(result.hasProgrammedRoutines, isFalse);

      expect(result.hasPercentage, isFalse);
    });

    test(
      'con ocurrencias pero ninguna completada devuelve cero por ciento',
      () {
        final result = RoutineComplianceResult(
          query: _query(),
          entries: [
            _entry(id: 'estado-1', status: RoutineStatus.modified),
            _entry(id: 'estado-2', status: RoutineStatus.notCompleted),
          ],
        );

        expect(result.programmedCount, 2);

        expect(result.completedCount, 0);

        expect(result.compliancePercentage, 0);

        expect(result.hasPercentage, isTrue);
      },
    );
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
  required RoutineStatus status,
}) {
  return RoutineComplianceEntry(
    recordId: id,
    anonymousId: 'perfil-a',
    routineId: 'rutina-$id',
    date: DateTime(2026, 9, 5),
    status: status,
  );
}
