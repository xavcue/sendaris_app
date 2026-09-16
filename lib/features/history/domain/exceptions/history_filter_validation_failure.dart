class HistoryFilterValidationFailure implements Exception {
  const HistoryFilterValidationFailure(this.fieldErrors);

  final Map<String, String> fieldErrors;

  String? errorFor(String field) {
    return fieldErrors[field];
  }

  bool get hasErrors => fieldErrors.isNotEmpty;

  String get message =>
      'Revisa el periodo seleccionado antes de aplicar los filtros.';

  @override
  String toString() => message;
}
