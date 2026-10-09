import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/app/theme/app_theme.dart';
import 'package:sendaris/app/theme/theme_mode_controller.dart';
import 'package:sendaris/features/settings/presentation/views/settings_view.dart';

void main() {
  group('SettingsView apariencia', () {
    testWidgets(
      'muestra únicamente la configuración de apariencia prevista en HU-29',
      (tester) async {
        final controller = ThemeModeController();

        addTearDown(controller.dispose);

        await _pumpSettings(tester, controller);

        expect(find.text('Ajustes'), findsOneWidget);

        expect(find.text('APARIENCIA'), findsOneWidget);

        expect(find.text('Tema de la aplicación'), findsOneWidget);

        expect(find.byKey(const Key('settings-theme-system')), findsOneWidget);

        expect(find.byKey(const Key('settings-theme-light')), findsOneWidget);

        expect(find.byKey(const Key('settings-theme-dark')), findsOneWidget);

        expect(find.text('Cerrar sesión'), findsNothing);

        expect(find.text('Eliminar cuenta'), findsNothing);

        expect(find.text('SESIÓN'), findsNothing);

        expect(find.text('CUENTA'), findsNothing);
      },
    );

    testWidgets('permite seleccionar Sistema Claro y Oscuro inmediatamente', (
      tester,
    ) async {
      final controller = ThemeModeController();

      addTearDown(controller.dispose);

      await _pumpSettings(tester, controller);

      expect(controller.themeMode, ThemeMode.system);

      await tester.tap(find.byKey(const Key('settings-theme-light')));

      await tester.pumpAndSettle();

      expect(controller.themeMode, ThemeMode.light);

      await tester.tap(find.byKey(const Key('settings-theme-dark')));

      await tester.pumpAndSettle();

      expect(controller.themeMode, ThemeMode.dark);

      await tester.tap(find.byKey(const Key('settings-theme-system')));

      await tester.pumpAndSettle();

      expect(controller.themeMode, ThemeMode.system);
    });

    testWidgets('la opción seleccionada se distingue visualmente', (
      tester,
    ) async {
      final controller = ThemeModeController();

      addTearDown(controller.dispose);

      await _pumpSettings(tester, controller);

      expect(
        find.descendant(
          of: find.byKey(const Key('settings-theme-system')),
          matching: find.byKey(const ValueKey('selected')),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('settings-theme-dark')));

      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('settings-theme-dark')),
          matching: find.byKey(const ValueKey('selected')),
        ),
        findsOneWidget,
      );
    });

    testWidgets('se renderiza sin errores en tema claro y oscuro', (
      tester,
    ) async {
      final controller = ThemeModeController();

      addTearDown(controller.dispose);

      await _pumpSettings(tester, controller);

      expect(tester.takeException(), isNull);

      controller.setThemeMode(ThemeMode.dark);

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      controller.setThemeMode(ThemeMode.light);

      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}

Future<void> _pumpSettings(
  WidgetTester tester,
  ThemeModeController controller,
) async {
  tester.view.physicalSize = const Size(1000, 1800);

  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();

    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeModeController>.value(
      value: controller,
      child: Consumer<ThemeModeController>(
        builder: (context, themeModeController, child) {
          return MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeModeController.themeMode,
            home: const SettingsView(),
          );
        },
      ),
    ),
  );

  await tester.pumpAndSettle();
}
