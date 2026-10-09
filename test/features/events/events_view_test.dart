import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/events/presentation/views/events_view.dart';

void main() {
  group('EventsView', () {
    testWidgets(
      'muestra los seis tipos de evento sin filtros ni listado global',
      (tester) async {
        await _pumpView(
          tester,
          hasTracking: true,
          onBehaviorTap: () {},
          onSleepTap: () {},
          onFeedingTap: () {},
          onSocialInteractionTap: () {},
          onDysregulationTap: () {},
          onAtypicalSituationTap: () {},
        );

        expect(find.text('Eventos'), findsOneWidget);

        expect(find.text('Conducta'), findsOneWidget);

        expect(find.text('Sueño'), findsOneWidget);

        expect(find.text('Alimentación'), findsOneWidget);

        expect(find.text('Interacción social'), findsOneWidget);

        expect(find.text('Desregulación'), findsOneWidget);

        expect(find.text('Otra situación'), findsOneWidget);

        expect(find.text('Periodo'), findsNothing);

        expect(find.text('Resultados'), findsNothing);

        expect(find.text('Desde'), findsNothing);

        expect(find.text('Hasta'), findsNothing);
      },
    );

    testWidgets(
      'los seis tipos ejecutan su navegación cuando están disponibles',
      (tester) async {
        var behaviorOpened = false;
        var sleepOpened = false;
        var feedingOpened = false;
        var socialOpened = false;
        var dysregulationOpened = false;
        var atypicalOpened = false;

        await _pumpView(
          tester,
          hasTracking: true,
          onBehaviorTap: () {
            behaviorOpened = true;
          },
          onSleepTap: () {
            sleepOpened = true;
          },
          onFeedingTap: () {
            feedingOpened = true;
          },
          onSocialInteractionTap: () {
            socialOpened = true;
          },
          onDysregulationTap: () {
            dysregulationOpened = true;
          },
          onAtypicalSituationTap: () {
            atypicalOpened = true;
          },
        );

        await _tapOption(tester, 'events-behavior-option');

        expect(behaviorOpened, isTrue);

        await _tapOption(tester, 'events-sleep-option');

        expect(sleepOpened, isTrue);

        await _tapOption(tester, 'events-feeding-option');

        expect(feedingOpened, isTrue);

        await _tapOption(tester, 'events-social-interaction-option');

        expect(socialOpened, isTrue);

        await _tapOption(tester, 'events-dysregulation-option');

        expect(dysregulationOpened, isTrue);

        await _tapOption(tester, 'events-atypical-situation-option');

        expect(atypicalOpened, isTrue);
      },
    );

    testWidgets(
      'sin seguimiento deshabilita los seis tipos y muestra orientación',
      (tester) async {
        var callbackExecuted = false;

        await _pumpView(
          tester,
          hasTracking: false,
          onBehaviorTap: () {
            callbackExecuted = true;
          },
          onSleepTap: () {
            callbackExecuted = true;
          },
          onFeedingTap: () {
            callbackExecuted = true;
          },
          onSocialInteractionTap: () {
            callbackExecuted = true;
          },
          onDysregulationTap: () {
            callbackExecuted = true;
          },
          onAtypicalSituationTap: () {
            callbackExecuted = true;
          },
        );

        expect(
          find.byKey(const Key('events-no-tracking-message')),
          findsOneWidget,
        );

        for (final key in _optionKeys) {
          final option = find.byKey(Key(key));

          await tester.scrollUntilVisible(
            option,
            220,
            scrollable: find.byType(Scrollable).first,
          );

          await tester.pumpAndSettle();

          final inkWell = tester.widget<InkWell>(
            find.descendant(of: option, matching: find.byType(InkWell)),
          );

          expect(inkWell.onTap, isNull);
        }

        expect(callbackExecuted, isFalse);
      },
    );

    testWidgets(
      'un tipo sin callback permanece deshabilitado sin afectar los demás',
      (tester) async {
        var behaviorOpened = false;

        await _pumpView(
          tester,
          hasTracking: true,
          onBehaviorTap: () {
            behaviorOpened = true;
          },
        );

        final behaviorOption = find.byKey(const Key('events-behavior-option'));

        final behaviorInkWell = tester.widget<InkWell>(
          find.descendant(of: behaviorOption, matching: find.byType(InkWell)),
        );

        expect(behaviorInkWell.onTap, isNotNull);

        await tester.tap(behaviorOption);

        await tester.pump();

        expect(behaviorOpened, isTrue);

        for (final key in _optionKeys.skip(1)) {
          final option = find.byKey(Key(key));

          await tester.scrollUntilVisible(
            option,
            220,
            scrollable: find.byType(Scrollable).first,
          );

          await tester.pumpAndSettle();

          final inkWell = tester.widget<InkWell>(
            find.descendant(of: option, matching: find.byType(InkWell)),
          );

          expect(inkWell.onTap, isNull);
        }
      },
    );
  });
}

const _optionKeys = [
  'events-behavior-option',
  'events-sleep-option',
  'events-feeding-option',
  'events-social-interaction-option',
  'events-dysregulation-option',
  'events-atypical-situation-option',
];

Future<void> _tapOption(WidgetTester tester, String key) async {
  final option = find.byKey(Key(key));

  await tester.scrollUntilVisible(
    option,
    220,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pumpAndSettle();

  await tester.tap(option);

  await tester.pump();
}

Future<void> _pumpView(
  WidgetTester tester, {
  required bool hasTracking,
  VoidCallback? onBehaviorTap,
  VoidCallback? onSleepTap,
  VoidCallback? onFeedingTap,
  VoidCallback? onSocialInteractionTap,
  VoidCallback? onDysregulationTap,
  VoidCallback? onAtypicalSituationTap,
}) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));

  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      home: EventsView(
        hasTracking: hasTracking,
        onBehaviorTap: onBehaviorTap,
        onSleepTap: onSleepTap,
        onFeedingTap: onFeedingTap,
        onSocialInteractionTap: onSocialInteractionTap,
        onDysregulationTap: onDysregulationTap,
        onAtypicalSituationTap: onAtypicalSituationTap,
      ),
    ),
  );

  await tester.pumpAndSettle();
}
