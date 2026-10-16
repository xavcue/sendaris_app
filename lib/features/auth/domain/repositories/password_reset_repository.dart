abstract interface class PasswordResetRepository {
  Future<void> requestPasswordReset({required String email});
}
