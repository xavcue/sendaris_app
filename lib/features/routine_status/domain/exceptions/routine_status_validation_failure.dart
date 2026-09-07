class RoutineStatusValidationFailure implements Exception {
  const RoutineStatusValidationFailure(this.fieldErrors);

  final Map<String, String> fieldErrors;

  @override
  String toString() {
    return fieldErrors.values.join(' ');
  }
}
