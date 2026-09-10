class SleepFailure implements Exception {
  const SleepFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
