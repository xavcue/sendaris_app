import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/frequency/presentation/widgets/records_timeline_panel.dart';

MonthlyCalendarRecord _record({
  required String id,
  required int day,
  required CalendarRecordType type,
  DateTime? eventTime,
  Object? source,
}) {
  return MonthlyCalendarRecord(
    id: id,
    anonymousId: 'perfil-a',
    date: DateTime(2026, 10, day),
    eventDateTime: eventTime,
    createdAt: DateTime(2026, 10, day, 20),
    type: type,
    description: 'Descripción ficticia',
    sourceRecord: source,
  );
}

Future<void> _show(
  WidgetTester tester,
  List<MonthlyCalendarRecord> records, {
  bool ascending = true,
  ValueChanged<bool>? onOrderChanged,
  ValueChanged<MonthlyCalendarRecord>? onRecordTap,
}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: RecordsTimelinePanel(
            records: records,
            ascending: ascending,
            onOrderChanged: onOrderChanged ?? (_) {},
            onRecordTap: onRecordTap ?? (_) {},
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('agrupa fechas por separado y ordena de antiguas a recientes', (
    tester,
  ) async {
    await _show(tester, [
      _record(id: 'ultimo', day: 23, type: CalendarRecordType.behavior),
      _record(id: 'primero', day: 14, type: CalendarRecordType.sleep),
      _record(id: 'intermedio', day: 15, type: CalendarRecordType.feeding),
    ]);

    final first = find.byKey(const Key('records-timeline-date-2026-10-14'));
    final middle = find.byKey(const Key('records-timeline-date-2026-10-15'));
    final last = find.byKey(const Key('records-timeline-date-2026-10-23'));

    expect(first, findsOneWidget);
    expect(middle, findsOneWidget);
    expect(last, findsOneWidget);

    expect(tester.getTopLeft(first).dy, lessThan(tester.getTopLeft(middle).dy));

    expect(tester.getTopLeft(middle).dy, lessThan(tester.getTopLeft(last).dy));

    expect(find.text('3 acontecimientos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite cambiar a recientes primero', (tester) async {
    final records = [
      _record(id: 'antiguo', day: 14, type: CalendarRecordType.sleep),
      _record(id: 'reciente', day: 23, type: CalendarRecordType.behavior),
    ];

    bool ascending = true;

    Future<void> pumpWithOrder() async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, update) {
                return SingleChildScrollView(
                  child: RecordsTimelinePanel(
                    records: records,
                    ascending: ascending,
                    onOrderChanged: (value) {
                      update(() => ascending = value);
                    },
                    onRecordTap: (_) {},
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    tester.view.physicalSize = const Size(1000, 1800);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpWithOrder();

    final older = find.byKey(const Key('records-timeline-date-2026-10-14'));
    final newer = find.byKey(const Key('records-timeline-date-2026-10-23'));

    expect(tester.getTopLeft(older).dy, lessThan(tester.getTopLeft(newer).dy));

    await tester.tap(find.byKey(const Key('records-timeline-order')));
    await tester.pumpAndSettle();

    expect(ascending, isFalse);
    expect(find.text('Recientes primero'), findsOneWidget);

    expect(tester.getTopLeft(newer).dy, lessThan(tester.getTopLeft(older).dy));
  });

  testWidgets('no inventa horas y distingue los nodos por categoria', (
    tester,
  ) async {
    await _show(tester, [
      _record(
        id: 'sueno',
        day: 15,
        type: CalendarRecordType.sleep,
        eventTime: DateTime(2026, 10, 15, 22),
      ),
      _record(id: 'conducta', day: 15, type: CalendarRecordType.behavior),
    ]);

    expect(find.text('Hora: 22:00'), findsOneWidget);
    expect(find.text('Hora no registrada'), findsOneWidget);

    final sleep = find.byKey(const Key('records-timeline-node-sleep-sueno'));

    final behavior = find.byKey(
      const Key('records-timeline-node-behavior-conducta'),
    );

    expect(sleep, findsOneWidget);
    expect(behavior, findsOneWidget);

    final first = tester.widget<Container>(sleep);
    final second = tester.widget<Container>(behavior);

    expect(first.decoration, isNot(second.decoration));

    expect(
      find.byKey(const Key('records-timeline-link-sleep-sueno')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('abre el registro original solamente cuando existe', (
    tester,
  ) async {
    String? openedId;

    await _show(tester, [
      _record(
        id: 'con-detalle',
        day: 15,
        type: CalendarRecordType.behavior,
        source: 'original',
      ),
      _record(id: 'sin-detalle', day: 15, type: CalendarRecordType.sleep),
    ], onRecordTap: (record) => openedId = record.id);

    final enabled = find.byKey(
      const Key('records-timeline-record-behavior-con-detalle'),
    );

    final disabled = find.byKey(
      const Key('records-timeline-record-sleep-sin-detalle'),
    );

    final firstInk = tester.widget<InkWell>(
      find.descendant(of: enabled, matching: find.byType(InkWell)),
    );

    final secondInk = tester.widget<InkWell>(
      find.descendant(of: disabled, matching: find.byType(InkWell)),
    );

    expect(firstInk.onTap, isNotNull);
    expect(secondInk.onTap, isNull);

    await tester.tap(enabled);
    await tester.pumpAndSettle();

    expect(openedId, 'con-detalle');
  });

  testWidgets('presenta estado vacio sin inventar registros', (tester) async {
    await _show(tester, const []);

    expect(find.byKey(const Key('records-timeline-empty')), findsOneWidget);

    expect(find.text('0 acontecimientos'), findsOneWidget);

    expect(find.byKey(const Key('records-timeline-note')), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
