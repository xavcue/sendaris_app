import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/duration/domain/exceptions/duration_failure.dart';
import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/presentation/views/duration_view.dart';

DurationObservation _observation({
  required String id,
  required DurationMetricType type,
  required int? minutes,
  String anonymousId = 'perfil-a',
}) {
  return DurationObservation(
    recordId: id,
    anonymousId: anonymousId,
    metricType: type,
    date: DateTime.now(),
    durationMinutes: minutes,
  );
}

class _FakeDurationRepository implements DurationRepository {
  _FakeDurationRepository({this.observations = const [], this.error});

  final List<DurationObservation> observations;
  final Object? error;

  final List<String> requests = [];

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    requests.add('$anonymousId:${metricType.name}');

    if (error != null) {
      throw error!;
    }

    return observations
        .where((record) => record.metricType == metricType)
        .toList();
  }
}

class _DeferredDurationRepository implements DurationRepository {
  final Map<String, Completer<List<DurationObservation>>> completers = {};

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) {
    final key = '$anonymousId:${metricType.name}';

    return completers
        .putIfAbsent(key, () => Completer<List<DurationObservation>>())
        .future;
  }

  void completeProfile(String anonymousId, List<DurationObservation> records) {
    for (final type in DurationMetricType.values) {
      final key = '$anonymousId:${type.name}';

      completers[key]!.complete(
        records.where((record) => record.metricType == type).toList(),
      );
    }
  }
}

Future<void> _pumpView(
  WidgetTester tester,
  DurationRepository repository, {
  String anonymousId = 'perfil-a',
}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: DurationView(repository: repository, anonymousId: anonymousId),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('carga automáticamente las tres métricas del mes actual', (
    tester,
  ) async {
    final repository = _FakeDurationRepository();

    await _pumpView(tester, repository);

    expect(find.text('Duraciones y promedios'), findsOneWidget);

    expect(find.text('Resumen de duraciones'), findsOneWidget);

    expect(find.byKey(const Key('duration-summary-sleep')), findsOneWidget);

    expect(find.byKey(const Key('duration-summary-behavior')), findsOneWidget);

    expect(
      find.byKey(const Key('duration-summary-dysregulation')),
      findsOneWidget,
    );

    expect(repository.requests, hasLength(3));

    expect(find.byKey(const Key('duration-calculate-button')), findsNothing);

    expect(find.byKey(const Key('duration-period-this-month')), findsOneWidget);
  });

  testWidgets('muestra promedios correctos con unidades apropiadas', (
    tester,
  ) async {
    final repository = _FakeDurationRepository(
      observations: [
        _observation(id: 's1', type: DurationMetricType.sleep, minutes: 420),
        _observation(id: 's2', type: DurationMetricType.sleep, minutes: 480),
        _observation(id: 'b1', type: DurationMetricType.behavior, minutes: 10),
        _observation(id: 'b2', type: DurationMetricType.behavior, minutes: 20),
        _observation(
          id: 'd1',
          type: DurationMetricType.dysregulation,
          minutes: 10,
        ),
        _observation(
          id: 'd2',
          type: DurationMetricType.dysregulation,
          minutes: 15,
        ),
      ],
    );

    await _pumpView(tester, repository);

    expect(find.text('7 h 30 min'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
    expect(find.text('12.5 min'), findsOneWidget);

    expect(
      find.byKey(const Key('duration-summary-count-sleep')),
      findsOneWidget,
    );

    expect(find.text('2 registros válidos'), findsNWidgets(3));
  });

  testWidgets(
    'sin registros muestra ausencia de datos sin inventar promedios',
    (tester) async {
      await _pumpView(tester, _FakeDurationRepository());

      expect(find.text('Sin datos'), findsNWidgets(3));

      expect(find.text('0 registros válidos'), findsNWidgets(3));

      expect(find.text('0 min'), findsNothing);
    },
  );

  testWidgets('conserva el cero válido de Desregulación', (tester) async {
    final repository = _FakeDurationRepository(
      observations: [
        _observation(
          id: 'd-zero',
          type: DurationMetricType.dysregulation,
          minutes: 0,
        ),
        _observation(id: 's-zero', type: DurationMetricType.sleep, minutes: 0),
        _observation(
          id: 'b-invalid',
          type: DurationMetricType.behavior,
          minutes: -1,
        ),
      ],
    );

    await _pumpView(tester, repository);

    expect(
      find.descendant(
        of: find.byKey(const Key('duration-summary-dysregulation')),
        matching: find.text('0 min'),
      ),
      findsOneWidget,
    );

    expect(find.text('Sin datos'), findsNWidgets(2));
  });

  testWidgets('las duraciones individuales se muestran al expandir', (
    tester,
  ) async {
    final repository = _FakeDurationRepository(
      observations: [
        _observation(
          id: 'sueno-1',
          type: DurationMetricType.sleep,
          minutes: 480,
        ),
      ],
    );

    await _pumpView(tester, repository);

    final expansion = find.byKey(const Key('duration-summary-expansion-sleep'));

    await tester.ensureVisible(expansion);
    await tester.pumpAndSettle();

    await tester.tap(expansion);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('duration-observation-sueno-1')),
      findsOneWidget,
    );

    expect(find.text('8 h'), findsNWidgets(2));
  });

  testWidgets('el filtro rápido actualiza automáticamente las consultas', (
    tester,
  ) async {
    final repository = _FakeDurationRepository();

    await _pumpView(tester, repository);

    expect(repository.requests, hasLength(3));

    await tester.tap(find.byKey(const Key('duration-period-seven-days')));

    await tester.pumpAndSettle();

    expect(repository.requests, hasLength(6));

    expect(find.byKey(const Key('duration-selected-period')), findsOneWidget);
  });

  testWidgets('el filtro personalizado permite abrir el selector de fecha', (
    tester,
  ) async {
    await _pumpView(tester, _FakeDurationRepository());

    await tester.tap(find.byKey(const Key('duration-period-custom')));

    await tester.pumpAndSettle();

    final dateButton = find.byKey(const Key('duration-start-date-button'));

    expect(dateButton, findsOneWidget);

    await tester.tap(dateButton);
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
  });

  testWidgets('presenta errores controlados sin resultados parciales', (
    tester,
  ) async {
    const message = 'No fue posible recuperar las duraciones.';

    final repository = _FakeDurationRepository(
      error: const DurationFailure(message),
    );

    await _pumpView(tester, repository);

    expect(find.byKey(const Key('duration-general-error')), findsOneWidget);

    expect(find.text(message), findsOneWidget);

    expect(find.byKey(const Key('duration-summary-sleep')), findsNothing);
  });

  testWidgets('descarta respuestas de un seguimiento anterior', (tester) async {
    final repository = _DeferredDurationRepository();

    tester.view.physicalSize = const Size(1000, 1800);
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

    await tester.pumpWidget(
      MaterialApp(
        home: DurationView(repository: repository, anonymousId: 'perfil-b'),
      ),
    );

    repository.completeProfile('perfil-b', [
      _observation(
        id: 'registro-b',
        type: DurationMetricType.behavior,
        minutes: 9,
        anonymousId: 'perfil-b',
      ),
    ]);

    await tester.pumpAndSettle();

    expect(find.text('9 min'), findsOneWidget);

    repository.completeProfile('perfil-a', [
      _observation(
        id: 'registro-a',
        type: DurationMetricType.behavior,
        minutes: 30,
        anonymousId: 'perfil-a',
      ),
    ]);

    await tester.pumpAndSettle();

    expect(find.text('30 min'), findsNothing);
    expect(find.text('9 min'), findsOneWidget);
  });
}
