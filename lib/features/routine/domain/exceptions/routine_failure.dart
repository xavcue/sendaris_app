class RoutineFailure implements Exception {
  const RoutineFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
