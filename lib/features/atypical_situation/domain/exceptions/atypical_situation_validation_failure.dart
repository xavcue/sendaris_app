class AtypicalSituationValidationFailure implements Exception {
  const AtypicalSituationValidationFailure(this.fieldErrors);

  final Map<String, String> fieldErrors;

  String? errorFor(String field) {
    return fieldErrors[field];
  }

  bool get hasErrors => fieldErrors.isNotEmpty;

  String get message =>
      'Revisa los campos indicados antes de '
      'guardar la situación.';

  @override
  String toString() => message;
}
