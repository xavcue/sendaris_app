import 'app_routes.dart';

/// Protege las rutas privadas de Sendaris.
///
/// Para acceder al contenido autenticado se requieren
/// dos condiciones independientes:
///
/// 1. La autenticación está lista para utilizar la aplicación.
/// 2. El control de acceso de la sesión permite entrar.
///
/// La segunda condición será administrada por el
/// coordinador biométrico durante la integración.
///
/// Su valor predeterminado conserva el comportamiento
/// anterior hasta conectar explícitamente la nueva barrera.
abstract final class AuthRouteGuard {
  static String? redirect({
    required bool isAuthenticated,
    required String matchedLocation,
    bool privateAccessGranted = true,
  }) {
    final isGoingToLogin = matchedLocation == AppRoutes.login;

    // Una sesión Firebase autenticada no es suficiente
    // mientras la evaluación biométrica esté pendiente.
    final canAccessPrivateRoutes = isAuthenticated && privateAccessGranted;

    if (!canAccessPrivateRoutes) {
      return isGoingToLogin ? null : AppRoutes.login;
    }

    if (isGoingToLogin) {
      return AppRoutes.home;
    }

    return null;
  }
}
