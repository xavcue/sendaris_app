import 'routine_status.dart';

class RoutineStatusRecord {
  const RoutineStatusRecord({
    required this.recordId,
    required this.anonymousId,
    required this.routineId,
    required this.date,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.observation,
  });

  final String recordId;

  final String anonymousId;

  final String routineId;

  final DateTime date;

  final RoutineStatus status;

  final String? observation;

  final DateTime createdAt;

  final DateTime updatedAt;
}
