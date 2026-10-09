import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/app/widgets/sendaris_primary_app_bar.dart';

void main() {
  group('SendarisPrimaryAppBar Ajustes', () {
    testWidgets('el AppBar principal muestra el engranaje y abre Ajustes', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) {
              return const Scaffold(
                appBar: SendarisPrimaryAppBar(),
                body: SizedBox(),
              );
            },
          ),
          GoRoute(
            path: AppRoutes.settings,
            builder: (context, state) {
              return const Scaffold(
                key: Key('settings-destination'),
                body: SizedBox(),
              );
            },
          ),
        ],
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('sendaris-primary-app-bar-settings-button')),
        findsOneWidget,
      );

      expect(find.byTooltip('Ajustes'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('sendaris-primary-app-bar-settings-button')),
      );

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.settings);

      expect(find.byKey(const Key('settings-destination')), findsOneWidget);
    });

    testWidgets('el modo Ajustes muestra Atrás y oculta el engranaje', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            appBar: SendarisPrimaryAppBar(
              showSettingsAction: false,
              showBackButton: true,
            ),
            body: SizedBox(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('sendaris-primary-app-bar-back-button')),
        findsOneWidget,
      );

      expect(find.byTooltip('Volver'), findsOneWidget);

      expect(
        find.byKey(const Key('sendaris-primary-app-bar-settings-button')),
        findsNothing,
      );
    });
  });
}
