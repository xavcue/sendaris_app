class FeedingValidationFailure implements Exception {
  const FeedingValidationFailure(this.fieldErrors);

  final Map<String, String> fieldErrors;

  String? errorFor(String field) {
    return fieldErrors[field];
  }

  bool get hasErrors => fieldErrors.isNotEmpty;

  String get message =>
      'Revisa los campos indicados antes de guardar el registro de alimentación.';

  @override
  String toString() => message;
}
