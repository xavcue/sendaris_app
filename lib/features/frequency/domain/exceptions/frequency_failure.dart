class FrequencyFailure implements Exception {
  const FrequencyFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
