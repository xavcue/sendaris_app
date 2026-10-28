import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/frequency/presentation/widgets/monthly_coverage_summary.dart';

void main() {
  MonthlyCalendarRecord record({
    required String id,
    required int day,
    required CalendarRecordType type,
    String anonymousId = 'perfil-a',
  }) {
    return MonthlyCalendarRecord(
      id: id,
      anonymousId: anonymousId,
      date: DateTime(2026, 10, day),
      type: type,
      description: type.label,
    );
  }

  MonthlyCalendarIndex indexFor(
    List<MonthlyCalendarRecord> records, {
    String anonymousId = 'perfil-a',
  }) {
    return MonthlyCalendarIndex(anonymousId: anonymousId, records: records);
  }

  Future<void> showCoverage(
    WidgetTester tester, {
    required MonthlyCalendarIndex? index,
    DateTime? visibleMonth,
    DateTime? startDate,
    DateTime? endDate,
    bool isLoading = false,
    bool hasError = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: MonthlyCoverageSummary(
              index: index,
              visibleMonth: visibleMonth ?? DateTime(2026, 10),
              startDate: startDate,
              endDate: endDate,
              isLoading: isLoading,
              hasError: hasError,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('muestra cobertura mensual con días distintos', (tester) async {
    final index = indexFor([
      record(id: 'conducta', day: 1, type: CalendarRecordType.behavior),
      record(id: 'sueno', day: 1, type: CalendarRecordType.sleep),
      record(id: 'rutina', day: 5, type: CalendarRecordType.routineStatus),
    ]);

    await showCoverage(tester, index: index);

    expect(find.text('Cobertura de registros'), findsOneWidget);
    expect(find.text('6.5 %'), findsOneWidget);
    expect(find.text('2 de 31 días con registros'), findsOneWidget);
    expect(find.text('Período: 01/10/2026 – 31/10/2026'), findsOneWidget);

    final progress = tester.widget<LinearProgressIndicator>(
      find.byKey(const Key('monthly-calendar-coverage-progress')),
    );

    expect(progress.value, closeTo(2 / 31, 0.00001));
  });

  testWidgets('muestra cero cuando no hay registros', (tester) async {
    await showCoverage(tester, index: indexFor([]));

    expect(find.text('0 %'), findsOneWidget);
    expect(find.text('0 de 31 días con registros'), findsOneWidget);
  });

  testWidgets('calcula únicamente los días del intervalo visible', (
    tester,
  ) async {
    final index = indexFor([
      record(id: 'diez', day: 10, type: CalendarRecordType.behavior),
      record(id: 'quince', day: 15, type: CalendarRecordType.sleep),
      record(id: 'fuera', day: 16, type: CalendarRecordType.feeding),
    ]);

    await showCoverage(
      tester,
      index: index,
      startDate: DateTime(2026, 10, 10),
      endDate: DateTime(2026, 10, 15),
    );

    expect(find.text('33.3 %'), findsOneWidget);
    expect(find.text('2 de 6 días con registros'), findsOneWidget);
    expect(find.text('Período: 10/10/2026 – 15/10/2026'), findsOneWidget);
  });

  testWidgets('respeta los límites del mes seleccionado', (tester) async {
    final index = indexFor([
      record(id: 'veinte', day: 20, type: CalendarRecordType.behavior),
    ]);

    await showCoverage(
      tester,
      index: index,
      startDate: DateTime(2026, 9, 20),
      endDate: DateTime(2026, 10, 20),
    );

    expect(find.text('1 de 20 días con registros'), findsOneWidget);
    expect(find.text('5 %'), findsOneWidget);
    expect(find.text('Período: 01/10/2026 – 20/10/2026'), findsOneWidget);
  });

  testWidgets('no inventa cobertura fuera del período', (tester) async {
    await showCoverage(
      tester,
      index: indexFor([]),
      visibleMonth: DateTime(2026, 10),
      startDate: DateTime(2026, 11, 1),
      endDate: DateTime(2026, 11, 30),
    );

    expect(
      find.byKey(const Key('monthly-calendar-coverage-outside-range')),
      findsOneWidget,
    );

    expect(
      find.text('El mes visible está fuera del período seleccionado.'),
      findsOneWidget,
    );

    expect(find.text('0 %'), findsNothing);
  });

  testWidgets('oculta valores durante una carga', (tester) async {
    await showCoverage(tester, index: indexFor([]), isLoading: true);

    expect(
      find.byKey(const Key('monthly-calendar-coverage-card')),
      findsNothing,
    );
  });

  testWidgets('no presenta cero ante un error remoto', (tester) async {
    await showCoverage(tester, index: indexFor([]), hasError: true);

    expect(find.text('0 %'), findsNothing);

    expect(
      find.byKey(const Key('monthly-calendar-coverage-card')),
      findsNothing,
    );
  });

  testWidgets('respeta el seguimiento activo', (tester) async {
    final index = indexFor([
      record(
        id: 'registro-b',
        day: 2,
        type: CalendarRecordType.sleep,
        anonymousId: 'perfil-b',
      ),
      record(id: 'registro-a', day: 3, type: CalendarRecordType.behavior),
    ], anonymousId: 'perfil-b');

    await showCoverage(tester, index: index);

    expect(find.text('1 de 31 días con registros'), findsOneWidget);
    expect(find.text('3.2 %'), findsOneWidget);
  });
}
