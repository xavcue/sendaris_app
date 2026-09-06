class RoutineValidationFailure implements Exception {
  const RoutineValidationFailure(this.errors);

  final Map<String, String> errors;

  @override
  String toString() {
    return errors.values.join(' ');
  }
}
