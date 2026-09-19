class DurationQueryValidationFailure implements Exception {
  const DurationQueryValidationFailure(this.fieldErrors);

  final Map<String, String> fieldErrors;

  String? errorFor(String field) {
    return fieldErrors[field];
  }

  bool get hasErrors => fieldErrors.isNotEmpty;

  String get message =>
      'Revisa el periodo seleccionado antes de calcular las duraciones.';

  @override
  String toString() => message;
}
