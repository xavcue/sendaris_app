import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/frequency/presentation/widgets/records_timeline_panel.dart';

void main() {
  const themes =
      <
        ({
          String name,
          Brightness brightness,
          Color background,
          Color border,
          Color nodeBackground,
          Color titleColor,
          Color countColor,
        })
      >[
        (
          name: 'oscuro',
          brightness: Brightness.dark,
          background: Color(0xFF17484B),
          border: Color(0xFF397C7A),
          nodeBackground: Color(0xFF9FE3D6),
          titleColor: Color(0xFFF4FFFC),
          countColor: Color(0xFFB9E9E3),
        ),
        (
          name: 'claro',
          brightness: Brightness.light,
          background: Color(0xFFDDEFEA),
          border: Color(0xFF86B9AD),
          nodeBackground: Color(0xFF226D66),
          titleColor: Color(0xFF173B38),
          countColor: Color(0xFF326E66),
        ),
      ];

  for (final scenario in themes) {
    testWidgets('HU-19: las fechas se distinguen de los registros '
        'en tema ${scenario.name}', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final date14 = DateTime(2026, 10, 14);
      final date15 = DateTime(2026, 10, 15);

      final records = <MonthlyCalendarRecord>[
        MonthlyCalendarRecord(
          id: 'sueno',
          anonymousId: 'perfil-a',
          date: date14,
          type: CalendarRecordType.sleep,
          description: 'Registro ficticio de sueño',
          eventDateTime: DateTime(2026, 10, 14, 21, 35),
        ),
        MonthlyCalendarRecord(
          id: 'conducta',
          anonymousId: 'perfil-a',
          date: date15,
          type: CalendarRecordType.behavior,
          description: 'Registro ficticio de conducta',
          eventDateTime: DateTime(2026, 10, 15, 16, 53),
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: scenario.brightness, useMaterial3: true),
          home: Scaffold(
            body: SingleChildScrollView(
              child: RecordsTimelinePanel(
                records: records,
                ascending: true,
                onOrderChanged: (_) {},
                onRecordTap: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final header14 = find.byKey(
        const Key('records-timeline-date-2026-10-14'),
      );

      final header15 = find.byKey(
        const Key('records-timeline-date-2026-10-15'),
      );

      expect(header14, findsOneWidget);
      expect(header15, findsOneWidget);

      final firstHeader = tester.widget<Container>(header14);
      final decoration = firstHeader.decoration! as BoxDecoration;

      expect(decoration.color, scenario.background);
      expect(decoration.border, isNotNull);

      final border = decoration.border! as Border;
      expect(border.top.color, scenario.border);

      final dayNode = tester.widget<Container>(
        find.byKey(const Key('records-timeline-day-node-2026-10-14')),
      );

      final nodeDecoration = dayNode.decoration! as BoxDecoration;

      expect(nodeDecoration.color, scenario.nodeBackground);

      final title = tester.widget<Text>(
        find.descendant(
          of: header14,
          matching: find.text('14 de octubre de 2026'),
        ),
      );

      expect(title.style?.color, scenario.titleColor);

      final count = tester.widget<Text>(
        find.descendant(of: header14, matching: find.text('1 acontecimiento')),
      );

      expect(count.style?.color, scenario.countColor);

      // El nuevo fondo se aplica solo a las fechas.
      // Los registros conservan su superficie habitual.
      final recordCard = tester.widget<Card>(
        find.byKey(const Key('records-timeline-record-sleep-sueno')),
      );

      final theme = Theme.of(
        tester.element(find.byKey(const Key('records-timeline-panel'))),
      );

      expect(recordCard.color, theme.colorScheme.surfaceContainerLow);

      expect(recordCard.color, isNot(equals(decoration.color)));

      // El eje cronologico sigue conectado.
      expect(
        find.byKey(const Key('records-timeline-link-sleep-sueno')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('records-timeline-node-behavior-conducta')),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });
  }
}
