class TrackingFailure implements Exception {
  const TrackingFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
