class DurationFailure implements Exception {
  const DurationFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
