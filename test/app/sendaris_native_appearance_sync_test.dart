import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sendaris/app/theme/sendaris_theme_preference.dart';
import 'package:sendaris/app/widgets/sendaris_animated_launch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.xavcue.sendaris/appearance');

  group('AUTH-03 3L.3 - Tema nativo', () {
    late List<MethodCall> nativeCalls;

    setUp(() {
      SharedPreferences.setMockInitialValues({});

      nativeCalls = <MethodCall>[];

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            nativeCalls.add(call);
            return true;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('sin preferencia utiliza Sistema', () async {
      await SendarisThemePreference.initialize();

      expect(SendarisThemePreference.selectedMode, ThemeMode.system);

      expect(nativeCalls, hasLength(1));
      expect(nativeCalls.single.method, 'setMode');

      expect(nativeCalls.single.arguments, <String, String>{'mode': 'system'});
    });

    test('al abrir recupera Claro y lo envia a Android', () async {
      SharedPreferences.setMockInitialValues({
        SendarisThemePreference.storageKey: 'light',
      });

      await SendarisThemePreference.initialize();

      expect(SendarisThemePreference.selectedMode, ThemeMode.light);

      expect(nativeCalls, hasLength(1));

      expect(nativeCalls.single.arguments, <String, String>{'mode': 'light'});
    });

    test('al abrir recupera Oscuro y lo envia a Android', () async {
      SharedPreferences.setMockInitialValues({
        SendarisThemePreference.storageKey: 'dark',
      });

      await SendarisThemePreference.initialize();

      expect(SendarisThemePreference.selectedMode, ThemeMode.dark);

      expect(nativeCalls.single.arguments, <String, String>{'mode': 'dark'});
    });

    test('guarda la seleccion y actualiza Android', () async {
      await SendarisThemePreference.initialize();

      final saved = await SendarisThemePreference.save(ThemeMode.light);

      expect(saved, isTrue);

      final preferences = await SharedPreferences.getInstance();

      expect(
        preferences.getString(SendarisThemePreference.storageKey),
        'light',
      );

      expect(nativeCalls.last.arguments, <String, String>{'mode': 'light'});
    });

    test('ordena los cambios rapidos de apariencia', () async {
      await SendarisThemePreference.initialize();

      final writes = <Future<bool>>[
        SendarisThemePreference.save(ThemeMode.light),
        SendarisThemePreference.save(ThemeMode.dark),
        SendarisThemePreference.save(ThemeMode.system),
      ];

      final results = await Future.wait(writes);

      expect(results, everyElement(isTrue));

      expect(
        nativeCalls.skip(1).map((call) => call.arguments),
        <Map<String, String>>[
          <String, String>{'mode': 'light'},
          <String, String>{'mode': 'dark'},
          <String, String>{'mode': 'system'},
        ],
      );

      final preferences = await SharedPreferences.getInstance();

      expect(
        preferences.getString(SendarisThemePreference.storageKey),
        'system',
      );

      expect(SendarisThemePreference.selectedMode, ThemeMode.system);
    });

    test('la falta de canal nativo no impide guardar el tema', () async {
      await SendarisThemePreference.initialize();

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);

      final saved = await SendarisThemePreference.save(ThemeMode.dark);

      expect(saved, isTrue);

      final preferences = await SharedPreferences.getInstance();

      expect(preferences.getString(SendarisThemePreference.storageKey), 'dark');
    });
  });

  testWidgets('el arranque utiliza un logo circular', (tester) async {
    await tester.pumpWidget(
      const SendarisAnimatedLaunch(themeMode: ThemeMode.light),
    );

    expect(find.byType(ClipOval), findsOneWidget);

    final image = tester.widget<Image>(find.byType(Image));

    expect(image.width, 192);
    expect(image.height, 192);

    expect(find.textContaining('Preparando'), findsNothing);

    expect(find.byType(CircularProgressIndicator), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
