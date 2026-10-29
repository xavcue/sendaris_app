import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/frequency/data/repositories/composite_monthly_calendar_repository.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/frequency/presentation/views/monthly_calendar_view.dart';

class _FakeExploreRepository implements MonthlyCalendarRepository {
  int requests = 0;

  @override
  Future<MonthlyCalendarIndex> recover({required String anonymousId}) async {
    requests++;

    final now = DateTime.now();
    final date = DateTime(now.year, now.month, 15);

    return MonthlyCalendarIndex(
      anonymousId: anonymousId,
      records: [
        MonthlyCalendarRecord(
          id: 'conducta',
          anonymousId: anonymousId,
          date: date,
          eventDateTime: DateTime(now.year, now.month, 15, 16, 30),
          type: CalendarRecordType.behavior,
          description: 'Conducta ficticia',
        ),
        MonthlyCalendarRecord(
          id: 'sueno',
          anonymousId: anonymousId,
          date: date,
          eventDateTime: DateTime(now.year, now.month, 15, 10),
          type: CalendarRecordType.sleep,
          description: 'Sueño ficticio',
        ),
      ],
    );
  }
}

void _configureScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  testWidgets(
    'HU-19: cambia de calendario a linea temporal sin nueva consulta',
    (tester) async {
      _configureScreen(tester);

      final repository = _FakeExploreRepository();

      await tester.pumpWidget(
        MaterialApp(
          home: MonthlyCalendarView(
            repository: repository,
            anonymousId: 'perfil-a',
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(repository.requests, 1);

      expect(find.byKey(const Key('monthly-calendar-grid')), findsOneWidget);

      expect(find.byKey(const Key('records-view-switch')), findsOneWidget);

      await tester.tap(find.byKey(const Key('records-view-timeline')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('records-timeline-panel')), findsOneWidget);

      expect(find.byKey(const Key('monthly-calendar-grid')), findsNothing);

      expect(repository.requests, 1);

      await tester.tap(find.byKey(const Key('records-view-calendar')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('monthly-calendar-grid')), findsOneWidget);

      expect(repository.requests, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('HU-19: los filtros se conservan al cambiar de vista', (
    tester,
  ) async {
    _configureScreen(tester);

    final repository = _FakeExploreRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyCalendarView(
          repository: repository,
          anonymousId: 'perfil-a',
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('records-view-timeline')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('records-timeline-count'))).data,
      '2 acontecimientos',
    );

    await tester.tap(find.byKey(const Key('monthly-calendar-filter-toggle')));
    await tester.pumpAndSettle();

    final sleepFilter = find.byKey(const Key('monthly-calendar-type-sleep'));

    await tester.scrollUntilVisible(
      sleepFilter,
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    await tester.tap(sleepFilter);
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('records-timeline-count'))).data,
      '1 acontecimiento',
    );

    await tester.tap(find.byKey(const Key('records-view-calendar')));
    await tester.pumpAndSettle();

    expect(find.textContaining('1 registro en'), findsOneWidget);

    await tester.tap(find.byKey(const Key('records-view-timeline')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('records-timeline-count'))).data,
      '1 acontecimiento',
    );

    expect(repository.requests, 1);
    expect(tester.takeException(), isNull);
  });
}
