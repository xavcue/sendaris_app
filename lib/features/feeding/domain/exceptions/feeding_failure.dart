class FeedingFailure implements Exception {
  const FeedingFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
