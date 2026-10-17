final class GoogleIdentityFailure implements Exception {
  const GoogleIdentityFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
