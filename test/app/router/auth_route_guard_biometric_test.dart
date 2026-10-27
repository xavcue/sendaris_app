import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/app/router/auth_route_guard.dart';

void main() {
  group('AUTH-03 - Acceso privado condicionado', () {
    test('biometría pendiente impide ingresar a Eventos', () {
      final redirect = AuthRouteGuard.redirect(
        isAuthenticated: true,
        privateAccessGranted: false,
        matchedLocation: AppRoutes.events,
      );

      expect(redirect, AppRoutes.login);
    });

    test('biometría pendiente impide ingresar a Ajustes', () {
      final redirect = AuthRouteGuard.redirect(
        isAuthenticated: true,
        privateAccessGranted: false,
        matchedLocation: AppRoutes.settings,
      );

      expect(redirect, AppRoutes.login);
    });

    test('biometría pendiente permite permanecer en Login', () {
      final redirect = AuthRouteGuard.redirect(
        isAuthenticated: true,
        privateAccessGranted: false,
        matchedLocation: AppRoutes.login,
      );

      expect(redirect, isNull);
    });

    test('sesión autorizada permite acceder a contenido privado', () {
      final redirect = AuthRouteGuard.redirect(
        isAuthenticated: true,
        privateAccessGranted: true,
        matchedLocation: AppRoutes.indicators,
      );

      expect(redirect, isNull);
    });

    test('sesión autorizada permite salir de Login hacia Inicio', () {
      final redirect = AuthRouteGuard.redirect(
        isAuthenticated: true,
        privateAccessGranted: true,
        matchedLocation: AppRoutes.login,
      );

      expect(redirect, AppRoutes.home);
    });

    test('autorización biométrica no sustituye autenticación', () {
      final redirect = AuthRouteGuard.redirect(
        isAuthenticated: false,
        privateAccessGranted: true,
        matchedLocation: AppRoutes.routines,
      );

      expect(redirect, AppRoutes.login);
    });
  });
}
