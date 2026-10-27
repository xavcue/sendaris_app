import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/app/router/auth_route_guard.dart';

void main() {
  group('AUTH-03 - Actualización reactiva del enrutamiento', () {
    Future<void> mountRouter(
      WidgetTester tester, {
      required ValueNotifier<bool> authenticated,
      required ValueNotifier<bool> privatePermission,
    }) async {
      final router = GoRouter(
        initialLocation: AppRoutes.login,
        refreshListenable: Listenable.merge([authenticated, privatePermission]),
        redirect: (context, state) {
          return AuthRouteGuard.redirect(
            isAuthenticated: authenticated.value,
            privateAccessGranted: privatePermission.value,
            matchedLocation: state.matchedLocation,
          );
        },
        routes: [
          GoRoute(
            path: AppRoutes.login,
            builder: (_, _) => const Scaffold(
              body: Text('Inicio de sesión', key: Key('router-test-login')),
            ),
          ),
          GoRoute(
            path: AppRoutes.home,
            builder: (_, _) => const Scaffold(
              body: Text('Inicio privado', key: Key('router-test-private')),
            ),
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (_, _) => const Scaffold(
              body: Text('Ajustes privados', key: Key('router-test-settings')),
            ),
          ),
        ],
      );

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());

        router.dispose();
        authenticated.dispose();
        privatePermission.dispose();
      });

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();
    }

    testWidgets('Firebase autenticado sin permiso mantiene Login', (
      tester,
    ) async {
      final authenticated = ValueNotifier<bool>(true);
      final permission = ValueNotifier<bool>(false);

      await mountRouter(
        tester,
        authenticated: authenticated,
        privatePermission: permission,
      );

      expect(find.byKey(const Key('router-test-login')), findsOneWidget);

      expect(find.byKey(const Key('router-test-private')), findsNothing);
    });

    testWidgets('conceder el permiso reactivo permite entrar a Inicio', (
      tester,
    ) async {
      final authenticated = ValueNotifier<bool>(true);
      final permission = ValueNotifier<bool>(false);

      await mountRouter(
        tester,
        authenticated: authenticated,
        privatePermission: permission,
      );

      permission.value = true;

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('router-test-private')), findsOneWidget);

      expect(find.byKey(const Key('router-test-login')), findsNothing);
    });

    testWidgets('revocar permiso desmonta la ruta privada', (tester) async {
      final authenticated = ValueNotifier<bool>(true);
      final permission = ValueNotifier<bool>(true);

      await mountRouter(
        tester,
        authenticated: authenticated,
        privatePermission: permission,
      );

      expect(find.byKey(const Key('router-test-private')), findsOneWidget);

      permission.value = false;

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('router-test-private')), findsNothing);

      expect(find.byKey(const Key('router-test-login')), findsOneWidget);
    });

    testWidgets('Firebase desconectado bloquea aunque exista permiso', (
      tester,
    ) async {
      final authenticated = ValueNotifier<bool>(true);
      final permission = ValueNotifier<bool>(true);

      await mountRouter(
        tester,
        authenticated: authenticated,
        privatePermission: permission,
      );

      expect(find.byKey(const Key('router-test-private')), findsOneWidget);

      authenticated.value = false;

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('router-test-private')), findsNothing);

      expect(find.byKey(const Key('router-test-login')), findsOneWidget);
    });
  });
}
