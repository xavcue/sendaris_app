class SocialInteractionFailure implements Exception {
  const SocialInteractionFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
