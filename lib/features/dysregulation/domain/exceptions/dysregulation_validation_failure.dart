class DysregulationValidationFailure implements Exception {
  const DysregulationValidationFailure(this.fieldErrors);

  final Map<String, String> fieldErrors;

  String? errorFor(String field) {
    return fieldErrors[field];
  }

  bool get hasErrors => fieldErrors.isNotEmpty;

  String get message =>
      'Revisa los campos indicados antes de guardar el episodio.';

  @override
  String toString() => message;
}
