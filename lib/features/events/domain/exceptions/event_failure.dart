class EventFailure implements Exception {
  const EventFailure(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
