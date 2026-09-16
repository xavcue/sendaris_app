class HistoryFailure implements Exception {
  const HistoryFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
