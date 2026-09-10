class SleepValidationFailure implements Exception {
  const SleepValidationFailure(this.fieldErrors);

  final Map<String, String> fieldErrors;

  String? errorFor(String field) {
    return fieldErrors[field];
  }

  bool get hasErrors => fieldErrors.isNotEmpty;

  String get message =>
      'Revisa los campos indicados antes de guardar el registro de sueño.';

  @override
  String toString() => message;
}
