import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/features/frequency/domain/exceptions/frequency_failure.dart';
import 'package:sendaris/features/frequency/domain/models/frequency_event.dart';
import 'package:sendaris/features/frequency/domain/models/frequency_metric_type.dart';
import 'package:sendaris/features/frequency/domain/repositories/frequency_repository.dart';
import 'package:sendaris/features/frequency/presentation/viewmodels/frequency_view_model.dart';
import 'package:sendaris/features/frequency/presentation/views/frequency_view.dart';

void main() {
  group('FrequencyView', () {
    testWidgets('muestra la pantalla inicial sin resultados', (tester) async {
      final repository = _FakeFrequencyRepository();

      await _pumpView(tester, repository);

      expect(find.text('Frecuencias descriptivas'), findsOneWidget);

      expect(find.text('Consulta frecuencias'), findsOneWidget);

      expect(find.text('Criterios de consulta'), findsOneWidget);

      expect(find.byKey(const Key('frequency-result-card')), findsNothing);

      for (final metric in FrequencyMetricType.values) {
        expect(
          find.byKey(Key('frequency-metric-${metric.code}')),
          findsOneWidget,
        );
      }
    });

    testWidgets('conducta muestra únicamente sus categorías permitidas', (
      tester,
    ) async {
      final repository = _FakeFrequencyRepository();

      await _pumpView(tester, repository);

      await tester.tap(find.byKey(const Key('frequency-metric-conducta')));

      await tester.pump();

      expect(
        find.byKey(const Key('frequency-category-selector')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('frequency-category-conducta_repetitiva')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('frequency-category-iniciativa_social')),
        findsOneWidget,
      );

      expect(find.byKey(const Key('frequency-category-all')), findsNothing);
    });

    testWidgets('desregulación no presenta selector de categoría', (
      tester,
    ) async {
      final repository = _FakeFrequencyRepository();

      await _pumpView(tester, repository);

      await tester.tap(find.byKey(const Key('frequency-metric-desregulacion')));

      await tester.pump();

      expect(
        find.byKey(const Key('frequency-category-selector')),
        findsNothing,
      );
    });

    testWidgets(
      'situaciones atípicas permiten dejar la categoría sin seleccionar',
      (tester) async {
        final repository = _FakeFrequencyRepository();

        await _pumpView(tester, repository);

        await tester.tap(
          find.byKey(const Key('frequency-metric-situacionAtipica')),
        );

        await tester.pump();

        final viewModel = _readViewModel(tester);

        expect(viewModel.selectedCategoryCode, isNull);

        expect(find.byKey(const Key('frequency-category-all')), findsNothing);

        final environmentChip = find.byKey(
          const Key('frequency-category-cambio_entorno'),
        );

        await tester.ensureVisible(environmentChip);

        await tester.pumpAndSettle();

        await tester.tap(environmentChip);

        await tester.pump();

        expect(viewModel.selectedCategoryCode, 'cambio_entorno');

        expect(tester.widget<ChoiceChip>(environmentChip).selected, isTrue);

        await tester.tap(environmentChip);

        await tester.pump();

        expect(viewModel.selectedCategoryCode, isNull);

        expect(tester.widget<ChoiceChip>(environmentChip).selected, isFalse);
      },
    );

    testWidgets('calcular sin seleccionar tipo muestra validación', (
      tester,
    ) async {
      final repository = _FakeFrequencyRepository();

      await _pumpView(tester, repository);

      await tester.tap(find.byKey(const Key('frequency-calculate-button')));

      await tester.pump();

      expect(find.byKey(const Key('frequency-metric-error')), findsOneWidget);

      expect(find.text('Selecciona un tipo de frecuencia.'), findsOneWidget);

      expect(repository.requests, isEmpty);
    });

    testWidgets(
      'calcular sin periodo muestra validación antes de consultar la fuente',
      (tester) async {
        final repository = _FakeFrequencyRepository();

        await _pumpView(tester, repository);

        await tester.tap(
          find.byKey(const Key('frequency-metric-desregulacion')),
        );

        await tester.pump();

        await tester.tap(find.byKey(const Key('frequency-calculate-button')));

        await tester.pump();

        expect(find.byKey(const Key('frequency-period-error')), findsOneWidget);

        expect(
          find.text('Selecciona una fecha inicial y una fecha final.'),
          findsOneWidget,
        );

        expect(repository.requests, isEmpty);
      },
    );

    testWidgets('el selector de fecha abre el calendario', (tester) async {
      final repository = _FakeFrequencyRepository();

      await _pumpView(tester, repository);

      await tester.tap(find.byKey(const Key('frequency-start-date-button')));

      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('Cancelar'));

      await tester.pumpAndSettle();
    });

    testWidgets('presenta un conteo descriptivo exacto', (tester) async {
      final repository = _FakeFrequencyRepository(
        events: [
          _event(
            id: 'conducta-1',
            metricType: FrequencyMetricType.behavior,
            date: DateTime(2026, 9, 5),
            categoryCode: 'conducta_repetitiva',
          ),
          _event(
            id: 'conducta-2',
            metricType: FrequencyMetricType.behavior,
            date: DateTime(2026, 9, 10),
            categoryCode: 'conducta_repetitiva',
          ),
          _event(
            id: 'otra-categoria',
            metricType: FrequencyMetricType.behavior,
            date: DateTime(2026, 9, 10),
            categoryCode: 'iniciativa_social',
          ),
        ],
      );

      await _pumpView(tester, repository);

      final viewModel = _readViewModel(tester);

      viewModel.setMetricType(FrequencyMetricType.behavior);

      viewModel.setStartDate(DateTime(2026, 9, 1));

      viewModel.setEndDate(DateTime(2026, 9, 15));

      viewModel.setCategoryCode('conducta_repetitiva');

      await tester.pump();

      await tester.tap(find.byKey(const Key('frequency-calculate-button')));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('frequency-result-card')), findsOneWidget);

      expect(find.text('Frecuencia descriptiva'), findsOneWidget);

      expect(find.text('2 registros'), findsOneWidget);

      expect(find.text('Conducta repetitiva'), findsOneWidget);

      expect(find.textContaining('severidad'), findsNothing);

      expect(find.textContaining('diagnóstico'), findsNothing);

      expect(find.textContaining('riesgo clínico'), findsNothing);
    });

    testWidgets('presenta cero como resultado válido sin error', (
      tester,
    ) async {
      final repository = _FakeFrequencyRepository();

      await _pumpView(tester, repository);

      final viewModel = _readViewModel(tester);

      viewModel.setMetricType(FrequencyMetricType.dysregulation);

      viewModel.setStartDate(DateTime(2026, 9, 1));

      viewModel.setEndDate(DateTime(2026, 9, 15));

      await tester.pump();

      await tester.tap(find.byKey(const Key('frequency-calculate-button')));

      await tester.pumpAndSettle();

      expect(find.text('0 registros'), findsOneWidget);

      expect(find.byKey(const Key('frequency-general-error')), findsNothing);
    });

    testWidgets('muestra un FrequencyFailure como error controlado', (
      tester,
    ) async {
      final repository = _FakeFrequencyRepository(
        error: const FrequencyFailure(
          'No fue posible recuperar los registros '
          'para calcular la frecuencia. '
          'Inténtalo nuevamente.',
        ),
      );

      await _pumpView(tester, repository);

      final viewModel = _readViewModel(tester);

      viewModel.setMetricType(FrequencyMetricType.dysregulation);

      viewModel.setStartDate(DateTime(2026, 9, 1));

      viewModel.setEndDate(DateTime(2026, 9, 15));

      await tester.pump();

      await tester.tap(find.byKey(const Key('frequency-calculate-button')));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('frequency-general-error')), findsOneWidget);

      expect(
        find.text(
          'No fue posible recuperar los registros '
          'para calcular la frecuencia. '
          'Inténtalo nuevamente.',
        ),
        findsOneWidget,
      );

      expect(find.byKey(const Key('frequency-result-card')), findsNothing);
    });

    testWidgets('después de calcular desplaza la pantalla hasta el resultado', (
      tester,
    ) async {
      final repository = _FakeFrequencyRepository(
        events: [
          _event(
            id: 'd1',
            metricType: FrequencyMetricType.dysregulation,
            date: DateTime(2026, 9, 5),
          ),
        ],
      );

      await _pumpView(tester, repository, size: const Size(500, 700));

      final viewModel = _readViewModel(tester);

      viewModel.setMetricType(FrequencyMetricType.dysregulation);

      viewModel.setStartDate(DateTime(2026, 9, 1));

      viewModel.setEndDate(DateTime(2026, 9, 15));

      await tester.pump();

      final calculateButton = find.byKey(
        const Key('frequency-calculate-button'),
      );

      await tester.ensureVisible(calculateButton);

      await tester.pumpAndSettle();

      expect(calculateButton.hitTestable(), findsOneWidget);

      await tester.tap(calculateButton);

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('frequency-result-card')).hitTestable(),
        findsOneWidget,
      );

      expect(find.text('1 registro'), findsOneWidget);
    });
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeFrequencyRepository repository, {
  Size size = const Size(1000, 1800),
}) async {
  tester.view.physicalSize = size;

  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();

    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: FrequencyView(repository: repository, anonymousId: 'perfil-a'),
    ),
  );

  await tester.pump();
}

FrequencyViewModel _readViewModel(WidgetTester tester) {
  final context = tester.element(find.byKey(const Key('frequency-screen')));

  return Provider.of<FrequencyViewModel>(context, listen: false);
}

FrequencyEvent _event({
  required String id,
  required FrequencyMetricType metricType,
  required DateTime date,
  String anonymousId = 'perfil-a',
  String? categoryCode,
}) {
  return FrequencyEvent(
    recordId: id,
    anonymousId: anonymousId,
    metricType: metricType,
    date: date,
    categoryCode: categoryCode,
  );
}

class _FakeFrequencyRepository implements FrequencyRepository {
  _FakeFrequencyRepository({List<FrequencyEvent> events = const [], this.error})
    : events = List<FrequencyEvent>.from(events);

  List<FrequencyEvent> events;

  Object? error;

  final List<_FrequencyRequest> requests = [];

  @override
  Future<List<FrequencyEvent>> recoverEvents({
    required String anonymousId,
    required FrequencyMetricType metricType,
  }) async {
    requests.add(
      _FrequencyRequest(anonymousId: anonymousId, metricType: metricType),
    );

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(events);
  }
}

class _FrequencyRequest {
  const _FrequencyRequest({
    required this.anonymousId,
    required this.metricType,
  });

  final String anonymousId;

  final FrequencyMetricType metricType;
}
