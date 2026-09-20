class RoutineComplianceFailure implements Exception {
  const RoutineComplianceFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
