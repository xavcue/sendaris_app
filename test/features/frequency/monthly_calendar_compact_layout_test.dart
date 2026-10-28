import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/frequency/data/repositories/composite_monthly_calendar_repository.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/frequency/presentation/views/monthly_calendar_view.dart';

class _FakeMonthlyCalendarRepository implements MonthlyCalendarRepository {
  @override
  Future<MonthlyCalendarIndex> recover({required String anonymousId}) async {
    final now = DateTime.now();

    return MonthlyCalendarIndex(
      anonymousId: anonymousId,
      records: [
        MonthlyCalendarRecord(
          id: 'conducta-1',
          anonymousId: anonymousId,
          date: DateTime(now.year, now.month, 15, 9),
          type: CalendarRecordType.behavior,
          description: 'Registro ficticio de conducta',
        ),
        MonthlyCalendarRecord(
          id: 'sueno-1',
          anonymousId: anonymousId,
          date: DateTime(now.year, now.month, 15, 20),
          type: CalendarRecordType.sleep,
          description: 'Registro ficticio de sueño',
        ),
      ],
    );
  }
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required double width,
  required double height,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: MonthlyCalendarView(
        repository: _FakeMonthlyCalendarRepository(),
        anonymousId: 'seguimiento-ficticio',
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  const screenSizes = <({String name, double width, double height})>[
    (name: 'movil compacto', width: 360, height: 800),
    (name: 'tablet Android', width: 800, height: 1280),
  ];

  for (final screen in screenSizes) {
    testWidgets('HU-15 calendario compacto en ${screen.name} '
        'con numeros y conteos visibles', (tester) async {
      await _pumpCalendar(tester, width: screen.width, height: screen.height);

      final grid = tester.widget<GridView>(
        find.byKey(const Key('monthly-calendar-grid')),
      );

      final delegate =
          grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;

      expect(delegate.crossAxisCount, 7);
      expect(delegate.mainAxisExtent, inInclusiveRange(48, 62));

      final day = find.byKey(const Key('monthly-calendar-day-15'));

      expect(day, findsOneWidget);

      final daySize = tester.getSize(day);

      expect(daySize.height, inInclusiveRange(48, 62));

      final dayNumber = tester.widget<Text>(
        find.descendant(of: day, matching: find.text('15')),
      );

      final recordCount = tester.widget<Text>(
        find.descendant(of: day, matching: find.text('2')),
      );

      expect(dayNumber.style?.fontSize, 14);
      expect(recordCount.style?.fontSize, 12);
      expect(recordCount.style?.fontWeight, FontWeight.bold);

      expect(find.textContaining('2 registros en'), findsOneWidget);

      await tester.tap(day);
      await tester.pumpAndSettle();

      final selectedDate = find.byKey(
        const Key('monthly-calendar-selected-day'),
      );

      expect(selectedDate, findsOneWidget);

      expect(
        tester.widget<Text>(selectedDate).data,
        startsWith('Registros del 15 de'),
      );

      expect(tester.takeException(), isNull);
    });
  }
}
