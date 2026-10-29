import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/frequency/data/repositories/composite_monthly_calendar_repository.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/frequency/presentation/views/monthly_calendar_view.dart';
import 'package:sendaris/features/frequency/presentation/widgets/month_year_picker.dart';

class _FakeCalendarRepository implements MonthlyCalendarRepository {
  int requests = 0;

  @override
  Future<MonthlyCalendarIndex> recover({required String anonymousId}) async {
    requests++;

    return MonthlyCalendarIndex(
      anonymousId: anonymousId,
      records: [
        MonthlyCalendarRecord(
          id: 'registro-prueba',
          anonymousId: anonymousId,
          date: DateTime.now(),
          type: CalendarRecordType.behavior,
          description: 'Registro de prueba',
        ),
      ],
    );
  }
}

void main() {
  testWidgets('impide avanzar más allá del año actual', (tester) async {
    final currentYear = DateTime.now().year;
    DateTime? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showMonthYearPicker(
                    context: context,
                    initialMonth: DateTime(currentYear, 10),
                  );
                },
                child: const Text('Abrir selector'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir selector'));
    await tester.pumpAndSettle();

    expect(find.text('$currentYear'), findsOneWidget);

    final nextYearButton = tester.widget<IconButton>(
      find.byKey(const Key('month-year-picker-next-year')),
    );

    expect(nextYearButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('month-year-picker-previous-year')));

    await tester.pumpAndSettle();

    expect(find.text('${currentYear - 1}'), findsOneWidget);

    await tester.tap(find.byKey(const Key('month-year-picker-month-3')));

    await tester.pumpAndSettle();

    expect(result, DateTime(currentYear - 1, 3));
  });

  testWidgets('permite elegir años anteriores desde YearPicker', (
    tester,
  ) async {
    final currentYear = DateTime.now().year;
    final previousYear = currentYear - 1;

    DateTime? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showMonthYearPicker(
                    context: context,
                    initialMonth: DateTime(currentYear, 10),
                  );
                },
                child: const Text('Abrir selector'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir selector'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('month-year-picker-select-year')));

    await tester.pumpAndSettle();

    expect(find.byType(YearPicker), findsOneWidget);

    final yearPicker = tester.widget<YearPicker>(find.byType(YearPicker));

    expect(yearPicker.lastDate.year, currentYear);

    await tester.tap(find.text('$previousYear'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('month-year-picker-month-grid')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('month-year-picker-month-12')));

    await tester.pumpAndSettle();

    expect(result, DateTime(previousYear, 12));
  });

  testWidgets('normaliza un año inicial futuro al año actual', (tester) async {
    final currentYear = DateTime.now().year;
    DateTime? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showMonthYearPicker(
                    context: context,
                    initialMonth: DateTime(currentYear + 10, 6),
                  );
                },
                child: const Text('Abrir selector'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir selector'));
    await tester.pumpAndSettle();

    expect(find.text('$currentYear'), findsOneWidget);

    final nextYearButton = tester.widget<IconButton>(
      find.byKey(const Key('month-year-picker-next-year')),
    );

    expect(nextYearButton.onPressed, isNull);

    await tester.tap(find.byKey(const Key('month-year-picker-month-6')));

    await tester.pumpAndSettle();

    expect(result, DateTime(currentYear, 6));
  });

  testWidgets('cancelar no selecciona ninguna fecha', (tester) async {
    DateTime? result = DateTime(2026, 10);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await showMonthYearPicker(
                    context: context,
                    initialMonth: DateTime(2026, 10),
                  );
                },
                child: const Text('Abrir selector'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir selector'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('month-year-picker-cancel')));

    await tester.pumpAndSettle();

    expect(result, isNull);
  });

  testWidgets('la cobertura precede al calendario y conserva los filtros', (
    tester,
  ) async {
    final repository = _FakeCalendarRepository();

    tester.view.physicalSize = const Size(440, 1500);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyCalendarView(
          repository: repository,
          anonymousId: 'perfil-a',
        ),
      ),
    );

    await tester.pumpAndSettle();

    final selectedDay = find.byKey(const Key('monthly-calendar-selected-day'));

    final coverage = find.byKey(const Key('monthly-calendar-coverage-card'));

    final filters = find.byKey(const Key('monthly-calendar-filter-toggle'));

    expect(selectedDay, findsOneWidget);
    expect(coverage, findsOneWidget);
    expect(filters, findsOneWidget);

    expect(
      tester.getTopLeft(coverage).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const Key('monthly-calendar-grid'))).dy,
      ),
    );

    expect(
      tester.getTopLeft(find.byKey(const Key('monthly-calendar-grid'))).dy,
      lessThan(tester.getTopLeft(selectedDay).dy),
    );

    expect(
      tester.getTopLeft(coverage).dy,
      lessThan(tester.getTopLeft(filters).dy),
    );

    expect(find.textContaining('valoración clínica'), findsNothing);
  });

  testWidgets('cambiar de mes no consulta nuevamente Firebase', (tester) async {
    final repository = _FakeCalendarRepository();
    final now = DateTime.now();

    final targetMonth = now.month == 1 ? 12 : now.month - 1;

    const monthNames = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];

    tester.view.physicalSize = const Size(440, 1500);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

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

    await tester.tap(
      find.byKey(const Key('monthly-calendar-open-month-picker')),
    );

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('month-year-picker-dialog')), findsOneWidget);

    await tester.tap(find.byKey(Key('month-year-picker-month-$targetMonth')));

    await tester.pumpAndSettle();

    expect(
      find.text('${monthNames[targetMonth - 1]} ${now.year}'),
      findsOneWidget,
    );

    expect(repository.requests, 1);
  });

  testWidgets('el filtro de fechas termina en el año actual', (tester) async {
    final repository = _FakeCalendarRepository();
    final currentYear = DateTime.now().year;

    tester.view.physicalSize = const Size(440, 1500);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MonthlyCalendarView(
          repository: repository,
          anonymousId: 'perfil-a',
        ),
      ),
    );

    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;
    final toggle = find.byKey(const Key('monthly-calendar-filter-toggle'));

    await tester.scrollUntilVisible(toggle, 200, scrollable: scrollable);

    await tester.tap(toggle);
    await tester.pumpAndSettle();

    final startButton = find.byKey(
      const Key('monthly-calendar-start-date-button'),
    );

    await tester.scrollUntilVisible(startButton, 200, scrollable: scrollable);

    await tester.tap(startButton);
    await tester.pumpAndSettle();

    final datePicker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );

    expect(datePicker.lastDate.year, currentYear);
    expect(datePicker.lastDate.month, 12);
    expect(datePicker.lastDate.day, 31);
  });
}
