import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/features/duration/domain/exceptions/duration_failure.dart';
import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/presentation/viewmodels/duration_view_model.dart';
import 'package:sendaris/features/duration/presentation/views/duration_view.dart';

void main() {
  group('DurationView', () {
    testWidgets('muestra únicamente los tres tipos con duración aplicable', (
      tester,
    ) async {
      final repository = _FakeDurationRepository();

      await _pumpView(tester, repository);

      expect(find.text('Duraciones y promedios'), findsOneWidget);

      expect(find.text('Consulta datos temporales'), findsOneWidget);

      expect(DurationMetricType.values, hasLength(3));

      for (final metric in DurationMetricType.values) {
        expect(
          find.byKey(Key('duration-metric-${metric.code}')),
          findsOneWidget,
        );
      }

      expect(find.text('Alimentación'), findsNothing);

      expect(find.text('Interacción social'), findsNothing);

      expect(find.text('Situaciones atípicas'), findsNothing);
    });

    testWidgets('calcular sin seleccionar tipo muestra validación', (
      tester,
    ) async {
      final repository = _FakeDurationRepository();

      await _pumpView(tester, repository);

      await tester.tap(find.byKey(const Key('duration-calculate-button')));

      await tester.pump();

      expect(find.byKey(const Key('duration-metric-error')), findsOneWidget);

      expect(find.text('Selecciona un tipo de duración.'), findsOneWidget);

      expect(repository.requests, isEmpty);
    });

    testWidgets(
      'calcular sin periodo muestra validación antes de consultar la fuente',
      (tester) async {
        final repository = _FakeDurationRepository();

        await _pumpView(tester, repository);

        await tester.tap(find.byKey(const Key('duration-metric-sueno')));

        await tester.pump();

        await tester.tap(find.byKey(const Key('duration-calculate-button')));

        await tester.pump();

        expect(find.byKey(const Key('duration-period-error')), findsOneWidget);

        expect(
          find.text('Selecciona una fecha inicial y una fecha final.'),
          findsOneWidget,
        );

        expect(repository.requests, isEmpty);
      },
    );

    testWidgets('el selector de fecha abre el calendario', (tester) async {
      final repository = _FakeDurationRepository();

      await _pumpView(tester, repository);

      await tester.tap(find.byKey(const Key('duration-start-date-button')));

      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('Cancelar'));

      await tester.pumpAndSettle();
    });

    testWidgets(
      'sueño presenta promedio y duraciones individuales en horas y minutos',
      (tester) async {
        final repository = _FakeDurationRepository(
          observations: [
            _observation(
              id: 'sueno-1',
              metricType: DurationMetricType.sleep,
              date: DateTime(2026, 9, 5),
              durationMinutes: 420,
            ),
            _observation(
              id: 'sueno-2',
              metricType: DurationMetricType.sleep,
              date: DateTime(2026, 9, 6),
              durationMinutes: 480,
            ),
          ],
        );

        await _pumpView(tester, repository);

        final viewModel = _readViewModel(tester);

        _selectValidCriteria(viewModel, DurationMetricType.sleep);

        await tester.pump();

        await tester.tap(find.byKey(const Key('duration-calculate-button')));

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('duration-result-card')), findsOneWidget);

        expect(find.text('Promedio descriptivo'), findsOneWidget);

        expect(find.byKey(const Key('duration-average-value')), findsOneWidget);

        expect(find.text('7 h 30 min'), findsOneWidget);

        expect(
          find.byKey(const Key('duration-observation-sueno-1')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('duration-observation-sueno-2')),
          findsOneWidget,
        );

        expect(find.text('7 h'), findsOneWidget);

        expect(find.text('8 h'), findsOneWidget);

        expect(find.text('450 min'), findsNothing);

        expect(find.text('480 min'), findsNothing);
      },
    );

    testWidgets('conductas conserva la presentación de duración en minutos', (
      tester,
    ) async {
      final repository = _FakeDurationRepository(
        observations: [
          _observation(
            id: 'conducta-1',
            metricType: DurationMetricType.behavior,
            date: DateTime(2026, 9, 5),
            durationMinutes: 20,
          ),
        ],
      );

      await _pumpView(tester, repository);

      final viewModel = _readViewModel(tester);

      _selectValidCriteria(viewModel, DurationMetricType.behavior);

      await tester.pump();

      await tester.tap(find.byKey(const Key('duration-calculate-button')));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('duration-result-card')), findsOneWidget);

      expect(find.text('20 min'), findsNWidgets(2));

      expect(find.text('0 h 20 min'), findsNothing);
    });

    testWidgets('no inventa un promedio cuando no existen duraciones válidas', (
      tester,
    ) async {
      final repository = _FakeDurationRepository(
        observations: [
          _observation(
            id: 'conducta-sin-duracion',
            metricType: DurationMetricType.behavior,
            date: DateTime(2026, 9, 5),
            durationMinutes: null,
          ),
        ],
      );

      await _pumpView(tester, repository);

      final viewModel = _readViewModel(tester);

      _selectValidCriteria(viewModel, DurationMetricType.behavior);

      await tester.pump();

      await tester.tap(find.byKey(const Key('duration-calculate-button')));

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('duration-insufficient-data-card')),
        findsOneWidget,
      );

      expect(find.text('No hay datos temporales suficientes'), findsOneWidget);

      expect(find.byKey(const Key('duration-average-value')), findsNothing);

      expect(find.text('0 min'), findsNothing);

      expect(
        find.byKey(const Key('duration-no-invented-average-message')),
        findsOneWidget,
      );
    });

    testWidgets('desregulación presenta promedio decimal en minutos', (
      tester,
    ) async {
      final repository = _FakeDurationRepository(
        observations: [
          _observation(
            id: 'd1',
            metricType: DurationMetricType.dysregulation,
            date: DateTime(2026, 9, 5),
            durationMinutes: 10,
          ),
          _observation(
            id: 'd2',
            metricType: DurationMetricType.dysregulation,
            date: DateTime(2026, 9, 6),
            durationMinutes: 15,
          ),
        ],
      );

      await _pumpView(tester, repository);

      final viewModel = _readViewModel(tester);

      _selectValidCriteria(viewModel, DurationMetricType.dysregulation);

      await tester.pump();

      await tester.tap(find.byKey(const Key('duration-calculate-button')));

      await tester.pumpAndSettle();

      expect(find.text('12.5 min'), findsOneWidget);

      expect(find.text('10 min'), findsOneWidget);

      expect(find.text('15 min'), findsOneWidget);
    });

    testWidgets('muestra un DurationFailure como error controlado', (
      tester,
    ) async {
      final repository = _FakeDurationRepository(
        error: const DurationFailure(
          'No fue posible recuperar los registros '
          'para calcular las duraciones. '
          'Inténtalo nuevamente.',
        ),
      );

      await _pumpView(tester, repository);

      final viewModel = _readViewModel(tester);

      _selectValidCriteria(viewModel, DurationMetricType.sleep);

      await tester.pump();

      await tester.tap(find.byKey(const Key('duration-calculate-button')));

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('duration-general-error')), findsOneWidget);

      expect(
        find.text(
          'No fue posible recuperar los registros '
          'para calcular las duraciones. '
          'Inténtalo nuevamente.',
        ),
        findsOneWidget,
      );

      expect(find.byKey(const Key('duration-result-card')), findsNothing);
    });

    testWidgets('la presentación mantiene lenguaje descriptivo y no clínico', (
      tester,
    ) async {
      final repository = _FakeDurationRepository(
        observations: [
          _observation(
            id: 'conducta-1',
            metricType: DurationMetricType.behavior,
            date: DateTime(2026, 9, 5),
            durationMinutes: 20,
          ),
        ],
      );

      await _pumpView(tester, repository);

      final viewModel = _readViewModel(tester);

      _selectValidCriteria(viewModel, DurationMetricType.behavior);

      await tester.pump();

      await tester.tap(find.byKey(const Key('duration-calculate-button')));

      await tester.pumpAndSettle();

      expect(find.text('Promedio descriptivo'), findsOneWidget);

      expect(find.textContaining('severidad clínica'), findsNothing);

      expect(find.textContaining('diagnóstico'), findsNothing);

      expect(find.textContaining('riesgo clínico'), findsNothing);

      expect(find.textContaining('tratamiento'), findsNothing);
    });

    testWidgets('después de calcular desplaza la pantalla hasta el resultado', (
      tester,
    ) async {
      final repository = _FakeDurationRepository(
        observations: [
          _observation(
            id: 'sueno-1',
            metricType: DurationMetricType.sleep,
            date: DateTime(2026, 9, 5),
            durationMinutes: 420,
          ),
        ],
      );

      await _pumpView(tester, repository, size: const Size(500, 700));

      final viewModel = _readViewModel(tester);

      _selectValidCriteria(viewModel, DurationMetricType.sleep);

      await tester.pump();

      final calculateButton = find.byKey(
        const Key('duration-calculate-button'),
      );

      await tester.ensureVisible(calculateButton);

      await tester.pumpAndSettle();

      expect(calculateButton.hitTestable(), findsOneWidget);

      await tester.tap(calculateButton);

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('duration-result-card')).hitTestable(),
        findsOneWidget,
      );

      expect(find.text('7 h'), findsWidgets);
    });
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeDurationRepository repository, {
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
      home: DurationView(repository: repository, anonymousId: 'perfil-a'),
    ),
  );

  await tester.pump();
}

DurationViewModel _readViewModel(WidgetTester tester) {
  final context = tester.element(find.byKey(const Key('duration-screen')));

  return Provider.of<DurationViewModel>(context, listen: false);
}

void _selectValidCriteria(
  DurationViewModel viewModel,
  DurationMetricType metricType,
) {
  viewModel.setMetricType(metricType);

  viewModel.setStartDate(DateTime(2026, 9, 1));

  viewModel.setEndDate(DateTime(2026, 9, 15));
}

DurationObservation _observation({
  required String id,
  required DurationMetricType metricType,
  required DateTime date,
  required int? durationMinutes,
  String anonymousId = 'perfil-a',
}) {
  return DurationObservation(
    recordId: id,
    anonymousId: anonymousId,
    metricType: metricType,
    date: date,
    durationMinutes: durationMinutes,
  );
}

class _FakeDurationRepository implements DurationRepository {
  _FakeDurationRepository({
    List<DurationObservation> observations = const [],
    this.error,
  }) : observations = List<DurationObservation>.from(observations);

  List<DurationObservation> observations;

  Object? error;

  final List<_DurationRequest> requests = [];

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    requests.add(
      _DurationRequest(anonymousId: anonymousId, metricType: metricType),
    );

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(observations);
  }
}

class _DurationRequest {
  const _DurationRequest({required this.anonymousId, required this.metricType});

  final String anonymousId;

  final DurationMetricType metricType;
}
