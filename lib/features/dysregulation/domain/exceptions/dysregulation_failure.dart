class DysregulationFailure implements Exception {
  const DysregulationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
