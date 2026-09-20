import '../../../routine_status/domain/models/routine_status.dart';

class RoutineComplianceEntry {
  const RoutineComplianceEntry({
    required this.recordId,
    required this.anonymousId,
    required this.routineId,
    required this.date,
    required this.status,
  });

  final String recordId;

  final String anonymousId;

  final String routineId;

  final DateTime date;

  final RoutineStatus status;
}
