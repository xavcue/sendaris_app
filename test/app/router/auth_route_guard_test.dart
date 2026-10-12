import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/app/router/auth_route_guard.dart';

void main() {
  group('AuthRouteGuard', () {
    test('permite Login cuando no existe una sesión autenticada', () {
      final redirect = AuthRouteGuard.redirect(
        isAuthenticated: false,
        matchedLocation: AppRoutes.login,
      );

      expect(redirect, isNull);
    });

    test('redirige una ruta protegida a Login cuando no hay sesión', () {
      final redirect = AuthRouteGuard.redirect(
        isAuthenticated: false,
        matchedLocation: AppRoutes.events,
      );

      expect(redirect, AppRoutes.login);
    });

    test('redirige Login a Inicio cuando ya existe una sesión lista', () {
      final redirect = AuthRouteGuard.redirect(
        isAuthenticated: true,
        matchedLocation: AppRoutes.login,
      );

      expect(redirect, AppRoutes.home);
    });

    test('permite una ruta protegida cuando existe una sesión lista', () {
      final redirect = AuthRouteGuard.redirect(
        isAuthenticated: true,
        matchedLocation: AppRoutes.settings,
      );

      expect(redirect, isNull);
    });
  });
}
