import 'app_routes.dart';

abstract final class AuthRouteGuard {
  static String? redirect({
    required bool isAuthenticated,
    required String matchedLocation,
  }) {
    final isGoingToLogin = matchedLocation == AppRoutes.login;

    if (!isAuthenticated) {
      return isGoingToLogin ? null : AppRoutes.login;
    }

    if (isGoingToLogin) {
      return AppRoutes.home;
    }

    return null;
  }
}
