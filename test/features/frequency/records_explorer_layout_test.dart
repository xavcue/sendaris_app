import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/frequency/data/repositories/composite_monthly_calendar_repository.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/frequency/presentation/views/monthly_calendar_view.dart';
import 'package:sendaris/features/frequency/presentation/widgets/monthly_coverage_summary.dart';
import 'package:sendaris/features/frequency/presentation/widgets/records_timeline_panel.dart';

class _FakeCalendarRepository implements MonthlyCalendarRepository {
  @override
  Future<MonthlyCalendarIndex> recover({required String anonymousId}) async {
    final now = DateTime.now();

    return MonthlyCalendarIndex(
      anonymousId: anonymousId,
      records: [
        MonthlyCalendarRecord(
          id: 'registro-1',
          anonymousId: anonymousId,
          date: DateTime(now.year, now.month, 15),
          type: CalendarRecordType.behavior,
          description: 'Registro ficticio',
        ),
      ],
    );
  }
}

MonthlyCalendarRecord _event({
  required String id,
  required int day,
  required CalendarRecordType type,
  DateTime? eventDateTime,
}) {
  return MonthlyCalendarRecord(
    id: id,
    anonymousId: 'perfil-a',
    date: DateTime(2026, 10, day),
    type: type,
    description: 'Acontecimiento ficticio',
    eventDateTime: eventDateTime,
  );
}

void _configureScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1700);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets('HU-19: fechas y registros comparten el mismo eje continuo', (
    tester,
  ) async {
    _configureScreen(tester);

    final records = [
      _event(
        id: 'sueno-14',
        day: 14,
        type: CalendarRecordType.sleep,
        eventDateTime: DateTime(2026, 10, 14, 21, 35),
      ),
      _event(
        id: 'conducta-15',
        day: 15,
        type: CalendarRecordType.behavior,
        eventDateTime: DateTime(2026, 10, 15, 16, 53),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
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

    final date14 = find.byKey(
      const Key('records-timeline-day-node-2026-10-14'),
    );

    final event14 = find.byKey(
      const Key('records-timeline-node-sleep-sueno-14'),
    );

    final date15 = find.byKey(
      const Key('records-timeline-day-node-2026-10-15'),
    );

    final event15 = find.byKey(
      const Key('records-timeline-node-behavior-conducta-15'),
    );

    expect(date14, findsOneWidget);
    expect(event14, findsOneWidget);
    expect(date15, findsOneWidget);
    expect(event15, findsOneWidget);

    // Los hitos de fecha y los registros deben compartir
    // exactamente el mismo eje horizontal.
    final axisX = tester.getCenter(date14).dx;

    expect(tester.getCenter(event14).dx, closeTo(axisX, 1));

    expect(tester.getCenter(date15).dx, closeTo(axisX, 1));

    expect(tester.getCenter(event15).dx, closeTo(axisX, 1));

    // El último registro del día 14 debe mantener
    // la conexión hacia la fecha siguiente.
    expect(
      find.byKey(const Key('records-timeline-link-sleep-sueno-14')),
      findsOneWidget,
    );

    // El último acontecimiento termina el recorrido.
    expect(
      find.byKey(const Key('records-timeline-link-behavior-conducta-15')),
      findsNothing,
    );

    expect(tester.getCenter(date14).dy, lessThan(tester.getCenter(event14).dy));

    expect(tester.getCenter(event14).dy, lessThan(tester.getCenter(date15).dy));

    expect(tester.getCenter(date15).dy, lessThan(tester.getCenter(event15).dy));

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-19: cobertura encima del calendario y filtros disponibles', (
    tester,
  ) async {
    _configureScreen(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyCalendarView(
          repository: _FakeCalendarRepository(),
          anonymousId: 'perfil-a',
        ),
      ),
    );

    await tester.pumpAndSettle();

    final coverage = find.byType(MonthlyCoverageSummary);

    final calendar = find.byKey(const Key('monthly-calendar-grid'));

    expect(coverage, findsOneWidget);
    expect(calendar, findsOneWidget);

    expect(
      tester.getTopLeft(coverage).dy,
      lessThan(tester.getTopLeft(calendar).dy),
    );

    final filterToggle = find.byKey(
      const Key('monthly-calendar-filter-toggle'),
    );

    await tester.scrollUntilVisible(
      filterToggle,
      140,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(filterToggle, findsOneWidget);

    await tester.tap(filterToggle);
    await tester.pumpAndSettle();

    final typeFilter = find.byKey(const Key('monthly-calendar-type-behavior'));

    await tester.scrollUntilVisible(
      typeFilter,
      140,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(typeFilter, findsOneWidget);

    expect(
      find.byKey(
        const Key('monthly-calendar-start-date-button'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );

    expect(
      find.byKey(
        const Key('monthly-calendar-end-date-button'),
        skipOffstage: false,
      ),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });
}
