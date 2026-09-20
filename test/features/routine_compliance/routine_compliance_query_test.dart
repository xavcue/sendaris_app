import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine_compliance/domain/exceptions/routine_compliance_query_validation_failure.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_query.dart';

void main() {
  group('RoutineComplianceQuery', () {
    test('normaliza identificador y fechas', () {
      final query = RoutineComplianceQuery.create(
        anonymousId: ' perfil-a ',
        startDate: DateTime(2026, 9, 1, 18, 30),
        endDate: DateTime(2026, 9, 15, 23, 59),
      );

      expect(query.anonymousId, 'perfil-a');

      expect(query.startDate, DateTime(2026, 9, 1));

      expect(query.endDate, DateTime(2026, 9, 15));
    });

    test('mantiene un periodo inclusivo válido', () {
      final query = RoutineComplianceQuery.create(
        anonymousId: 'perfil-a',
        startDate: DateTime(2026, 9, 10),
        endDate: DateTime(2026, 9, 10),
      );

      expect(query.startDate, query.endDate);
    });

    test('rechaza criterios inválidos', () {
      expect(
        () => RoutineComplianceQuery.create(
          anonymousId: 'perfil-a',
          startDate: DateTime(2026, 9, 20),
          endDate: DateTime(2026, 9, 10),
        ),
        throwsA(isA<RoutineComplianceQueryValidationFailure>()),
      );
    });
  });
}
