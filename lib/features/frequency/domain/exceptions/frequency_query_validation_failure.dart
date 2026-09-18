class FrequencyQueryValidationFailure implements Exception {
  const FrequencyQueryValidationFailure(this.fieldErrors);

  final Map<String, String> fieldErrors;

  String? errorFor(String field) {
    return fieldErrors[field];
  }

  bool get hasErrors => fieldErrors.isNotEmpty;

  String get message =>
      'Revisa los criterios seleccionados antes de calcular la frecuencia.';

  @override
  String toString() => message;
}
