class PasswordResetFailure implements Exception {
  const PasswordResetFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
