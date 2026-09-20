class RoutineComplianceQueryValidationFailure implements Exception {
  const RoutineComplianceQueryValidationFailure(this.fieldErrors);

  final Map<String, String> fieldErrors;

  String? errorFor(String field) {
    return fieldErrors[field];
  }

  bool get hasErrors => fieldErrors.isNotEmpty;

  String get message =>
      'Revisa el periodo seleccionado antes de '
      'calcular el cumplimiento de rutinas.';

  @override
  String toString() => message;
}
