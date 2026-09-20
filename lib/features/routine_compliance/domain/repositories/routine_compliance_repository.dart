import '../models/routine_compliance_entry.dart';

abstract interface class RoutineComplianceRepository {
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  });
}
