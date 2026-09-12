class SocialInteractionValidationFailure implements Exception {
  const SocialInteractionValidationFailure(this.fieldErrors);

  final Map<String, String> fieldErrors;

  String? errorFor(String field) {
    return fieldErrors[field];
  }

  bool get hasErrors => fieldErrors.isNotEmpty;

  String get message =>
      'Revisa los campos indicados antes de guardar '
      'el registro de interacción social.';

  @override
  String toString() => message;
}
