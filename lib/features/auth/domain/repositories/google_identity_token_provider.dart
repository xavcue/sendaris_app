/// Obtiene temporalmente una identidad de Google para autenticarla
/// posteriormente mediante Firebase Authentication.
///
/// No modifica sesiones, cuentas ni datos persistidos.
abstract interface class GoogleIdentityTokenProvider {
  /// Devuelve el ID token de Google.
  ///
  /// Devuelve null cuando el usuario cancela el selector de cuentas.
  Future<String?> requestIdToken();
}
