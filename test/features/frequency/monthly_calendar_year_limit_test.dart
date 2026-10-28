import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/frequency/data/repositories/composite_monthly_calendar_repository.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/frequency/presentation/viewmodels/monthly_calendar_view_model.dart';
import 'package:sendaris/features/frequency/presentation/views/monthly_calendar_view.dart';

class _FakeCalendarRepository implements MonthlyCalendarRepository {
  int requests = 0;

  @override
  Future<MonthlyCalendarIndex> recover({required String anonymousId}) async {
    requests++;

    return MonthlyCalendarIndex(anonymousId: anonymousId, records: const []);
  }
}

void main() {
  group('Límite anual del calendario - HU-21', () {
    test('permite diciembre, pero impide avanzar al año siguiente', () {
      final repository = _FakeCalendarRepository();

      final viewModel = MonthlyCalendarViewModel(
        repository,
        anonymousId: 'perfil-a',
        clock: () => DateTime(2026, 10, 28),
      );

      addTearDown(viewModel.dispose);

      expect(viewModel.canGoToNextMonth, isTrue);

      viewModel.changeMonth(2);

      expect(viewModel.visibleMonth, DateTime(2026, 12));
      expect(viewModel.selectedDate, DateTime(2026, 12, 1));
      expect(viewModel.canGoToNextMonth, isFalse);

      viewModel.changeMonth(1);

      expect(viewModel.visibleMonth, DateTime(2026, 12));
      expect(viewModel.selectedDate, DateTime(2026, 12, 1));
    });

    test('rechaza seleccionar directamente un año futuro', () {
      final repository = _FakeCalendarRepository();

      final viewModel = MonthlyCalendarViewModel(
        repository,
        anonymousId: 'perfil-a',
        clock: () => DateTime(2026, 10, 28),
      );

      addTearDown(viewModel.dispose);

      viewModel.selectDate(DateTime(2027, 1, 15));

      expect(viewModel.visibleMonth, DateTime(2026, 10));
      expect(viewModel.selectedDate, DateTime(2026, 10, 28));

      viewModel.selectDate(DateTime(2026, 12, 15));

      expect(viewModel.visibleMonth, DateTime(2026, 12));
      expect(viewModel.selectedDate, DateTime(2026, 12, 15));
    });

    test('habilita el siguiente año cuando el reloj avanza', () {
      final repository = _FakeCalendarRepository();
      var currentYear = 2026;

      final viewModel = MonthlyCalendarViewModel(
        repository,
        anonymousId: 'perfil-a',
        clock: () => DateTime(currentYear, 10, 28),
      );

      addTearDown(viewModel.dispose);

      viewModel.changeMonth(2);

      expect(viewModel.visibleMonth, DateTime(2026, 12));
      expect(viewModel.canGoToNextMonth, isFalse);

      currentYear = 2027;

      expect(viewModel.canGoToNextMonth, isTrue);

      viewModel.changeMonth(1);

      expect(viewModel.visibleMonth, DateTime(2027, 1));
      expect(viewModel.selectedDate, DateTime(2027, 1, 1));
    });

    testWidgets('deshabilita visualmente la flecha en diciembre', (
      tester,
    ) async {
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

      final monthButton = find.byKey(
        const Key('monthly-calendar-open-month-picker'),
      );

      await tester.tap(monthButton);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('month-year-picker-month-12')));

      await tester.pumpAndSettle();

      expect(find.text('diciembre $currentYear'), findsOneWidget);

      final nextButton = tester.widget<IconButton>(
        find.byKey(const Key('monthly-calendar-next')),
      );

      expect(nextButton.onPressed, isNull);

      final previous = find.byKey(const Key('monthly-calendar-previous'));

      await tester.tap(previous);
      await tester.pumpAndSettle();

      expect(find.text('noviembre $currentYear'), findsOneWidget);

      final enabledNextButton = tester.widget<IconButton>(
        find.byKey(const Key('monthly-calendar-next')),
      );

      expect(enabledNextButton.onPressed, isNotNull);

      expect(repository.requests, 1);
    });
  });
}
