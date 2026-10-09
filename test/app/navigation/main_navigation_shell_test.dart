import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/app/navigation/main_navigation_shell.dart';

void main() {
  testWidgets(
    'muestra únicamente los cuatro destinos principales y comienza en Inicio',
    (tester) async {
      final router = _createRouter();

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('main-bottom-navigation')), findsOneWidget);

      expect(find.text('Inicio'), findsOneWidget);

      expect(find.text('Eventos'), findsOneWidget);

      expect(find.text('Rutinas'), findsOneWidget);

      expect(find.text('Indicadores'), findsOneWidget);

      expect(find.text('Registrar'), findsNothing);

      expect(find.text('Registros'), findsNothing);

      expect(find.text('Ajustes'), findsNothing);

      expect(find.byKey(const Key('test-home-screen')), findsOneWidget);
    },
  );

  testWidgets('permite navegar entre las cuatro secciones principales', (
    tester,
  ) async {
    final router = _createRouter();

    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('main-navigation-events')));

    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/events');

    expect(find.byKey(const Key('test-events-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('main-navigation-routines')));

    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/routines');

    expect(find.byKey(const Key('test-routines-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('main-navigation-indicators')));

    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/indicators');

    expect(find.byKey(const Key('test-indicators-screen')), findsOneWidget);

    await tester.tap(find.byKey(const Key('main-navigation-home')));

    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');

    expect(find.byKey(const Key('test-home-screen')), findsOneWidget);
  });

  testWidgets('Atrás desde Eventos vuelve primero a Inicio', (tester) async {
    final router = _createRouter();

    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('main-navigation-events')));

    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/events');

    await tester.binding.handlePopRoute();

    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');
  });

  testWidgets('Atrás desde Rutinas vuelve primero a Inicio', (tester) async {
    final router = _createRouter();

    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('main-navigation-routines')));

    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/routines');

    await tester.binding.handlePopRoute();

    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');
  });

  testWidgets('Atrás desde Indicadores vuelve primero a Inicio', (
    tester,
  ) async {
    final router = _createRouter();

    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('main-navigation-indicators')));

    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/indicators');

    await tester.binding.handlePopRoute();

    await tester.pumpAndSettle();

    expect(router.state.uri.path, '/');
  });

  testWidgets(
    'un detalle abierto desde una sección oculta la barra y Atrás regresa a la sección',
    (tester) async {
      final router = _createRouter();

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('main-navigation-indicators')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/indicators');

      router.push('/indicator-detail');

      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/indicator-detail');

      expect(find.byKey(const Key('main-bottom-navigation')), findsNothing);

      expect(
        find.byKey(const Key('test-indicator-detail-screen')),
        findsOneWidget,
      );

      await tester.binding.handlePopRoute();

      await tester.pumpAndSettle();

      expect(router.state.uri.path, '/indicators');

      expect(find.byKey(const Key('main-bottom-navigation')), findsOneWidget);

      expect(find.byKey(const Key('test-indicators-screen')), findsOneWidget);
    },
  );
}

GoRouter _createRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                pageBuilder: (context, state) {
                  return const NoTransitionPage<void>(
                    child: _TestScreen(
                      key: Key('test-home-screen'),
                      label: 'Pantalla Inicio',
                    ),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/events',
                pageBuilder: (context, state) {
                  return const NoTransitionPage<void>(
                    child: _TestScreen(
                      key: Key('test-events-screen'),
                      label: 'Pantalla Eventos',
                    ),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/routines',
                pageBuilder: (context, state) {
                  return const NoTransitionPage<void>(
                    child: _TestScreen(
                      key: Key('test-routines-screen'),
                      label: 'Pantalla Rutinas',
                    ),
                  );
                },
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/indicators',
                pageBuilder: (context, state) {
                  return const NoTransitionPage<void>(
                    child: _TestScreen(
                      key: Key('test-indicators-screen'),
                      label: 'Pantalla Indicadores',
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/indicator-detail',
        pageBuilder: (context, state) {
          return const MaterialPage<void>(
            child: _TestScreen(
              key: Key('test-indicator-detail-screen'),
              label: 'Detalle de indicador',
            ),
          );
        },
      ),
    ],
  );
}

class _TestScreen extends StatelessWidget {
  const _TestScreen({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
