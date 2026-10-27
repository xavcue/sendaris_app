import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sendaris/app/theme/sendaris_theme_preference.dart';
import 'package:sendaris/app/theme/theme_mode_controller.dart';
import 'package:sendaris/app/widgets/sendaris_animated_launch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AUTH-03 3L.1 - Apariencia persistente', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('sin preferencia guardada utiliza Sistema', () async {
      await SendarisThemePreference.initialize();

      expect(SendarisThemePreference.selectedMode, ThemeMode.system);
    });

    test('recupera la preferencia Oscuro', () async {
      SharedPreferences.setMockInitialValues({
        SendarisThemePreference.storageKey: 'dark',
      });

      await SendarisThemePreference.initialize();

      expect(SendarisThemePreference.selectedMode, ThemeMode.dark);
    });

    test('recupera la preferencia Claro', () async {
      SharedPreferences.setMockInitialValues({
        SendarisThemePreference.storageKey: 'light',
      });

      await SendarisThemePreference.initialize();

      expect(SendarisThemePreference.selectedMode, ThemeMode.light);
    });

    test('una preferencia desconocida no rompe el inicio', () async {
      SharedPreferences.setMockInitialValues({
        SendarisThemePreference.storageKey: 'invalid',
      });

      await SendarisThemePreference.initialize();

      expect(SendarisThemePreference.selectedMode, ThemeMode.system);
    });

    test('un cambio desde Ajustes puede persistirse', () async {
      await SendarisThemePreference.initialize();

      final controller = ThemeModeController(
        initialMode: SendarisThemePreference.selectedMode,
        onChanged: (mode) {
          unawaited(SendarisThemePreference.save(mode));
        },
      );

      addTearDown(controller.dispose);

      controller.setThemeMode(ThemeMode.dark);

      expect(controller.themeMode, ThemeMode.dark);

      // La escritura utiliza SharedPreferences;
      // al volver a cargar se conserva Oscuro.
      await SendarisThemePreference.save(ThemeMode.dark);

      await SendarisThemePreference.initialize();

      expect(SendarisThemePreference.selectedMode, ThemeMode.dark);
    });

    test('el controlador conserva su comportamiento por defecto', () {
      final controller = ThemeModeController();

      addTearDown(controller.dispose);

      expect(controller.themeMode, ThemeMode.system);

      controller.setThemeMode(ThemeMode.light);

      expect(controller.themeMode, ThemeMode.light);

      controller.useSystemMode();

      expect(controller.themeMode, ThemeMode.system);
    });
  });

  group('AUTH-03 3L.1 - Logo de arranque', () {
    testWidgets('respeta el modo Claro', (tester) async {
      await tester.pumpWidget(
        const SendarisAnimatedLaunch(themeMode: ThemeMode.light),
      );

      final context = tester.element(find.byType(Scaffold));

      expect(Theme.of(context).brightness, Brightness.light);

      expect(find.byType(Image), findsOneWidget);

      expect(find.text('Preparando el acceso a Sendaris'), findsNothing);

      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('respeta el modo Oscuro', (tester) async {
      await tester.pumpWidget(
        const SendarisAnimatedLaunch(themeMode: ThemeMode.dark),
      );

      final context = tester.element(find.byType(Scaffold));

      expect(Theme.of(context).brightness, Brightness.dark);

      expect(find.byType(Image), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('mantiene Sistema sin convertirlo en un modo fijo', (
      tester,
    ) async {
      await tester.pumpWidget(
        const SendarisAnimatedLaunch(themeMode: ThemeMode.system),
      );

      final application = tester.widget<MaterialApp>(find.byType(MaterialApp));

      expect(application.themeMode, ThemeMode.system);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('no muestra texto tecnico ni spinner', (tester) async {
      await tester.pumpWidget(
        const SendarisAnimatedLaunch(themeMode: ThemeMode.dark),
      );

      expect(find.textContaining('Preparando'), findsNothing);

      expect(find.textContaining('Comprobando'), findsNothing);

      expect(find.byType(CircularProgressIndicator), findsNothing);

      expect(find.byType(LinearProgressIndicator), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
