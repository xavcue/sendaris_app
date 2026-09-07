class AtypicalSituationFailure implements Exception {
  const AtypicalSituationFailure(this.message);

  final String message;

  @override
  String toString() {
    return message;
  }
}
