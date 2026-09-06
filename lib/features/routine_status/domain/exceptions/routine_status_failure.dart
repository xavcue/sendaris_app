class RoutineStatusFailure implements Exception {
  const RoutineStatusFailure(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
