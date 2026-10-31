import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/domain/services/duration_overview_service.dart';
import 'package:sendaris/features/duration/presentation/widgets/duration_observation_chart.dart';

class _FakeRepository implements DurationRepository {
  const _FakeRepository(this.observations);

  final List<DurationObservation> observations;

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    return observations
        .where(
          (observation) =>
              observation.anonymousId == anonymousId &&
              observation.metricType == metricType,
        )
        .toList();
  }
}

DurationObservation _observation({
  required String id,
  required int day,
  required int? minutes,
  DurationMetricType type = DurationMetricType.behavior,
}) {
  return DurationObservation(
    recordId: id,
    anonymousId: 'seguimiento-ficticio',
    metricType: type,
    date: DateTime(2026, 10, day),
    durationMinutes: minutes,
  );
}

Future<DurationOverview> _createOverview(
  List<DurationObservation> observations,
) {
  return DurationOverviewService(_FakeRepository(observations)).load(
    anonymousId: 'seguimiento-ficticio',
    startDate: DateTime(2026, 10, 1),
    endDate: DateTime(2026, 10, 31),
  );
}

Future<void> _pump(
  WidgetTester tester,
  DurationOverview overview,
  DurationMetricType type, {
  double width = 360,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DurationObservationChart(
              type: type,
              result: overview.resultFor(type),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('HU-16 ordena duraciones y utiliza escala por categoria', (
    tester,
  ) async {
    final overview = await _createOverview([
      _observation(id: 'a', day: 1, minutes: 10),
      _observation(id: 'b', day: 15, minutes: 20),
      _observation(id: 'c', day: 8, minutes: 5),
    ]);

    await _pump(tester, overview, DurationMetricType.behavior);

    expect(
      find.byKey(const Key('duration-observation-chart-behavior')),
      findsOneWidget,
    );

    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('duration-chart-value-behavior-0')),
          )
          .data,
      '20 min · registro',
    );

    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('duration-chart-bar-behavior-0')),
          )
          .value,
      1,
    );

    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('duration-chart-bar-behavior-1')),
          )
          .value,
      0.25,
    );

    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('duration-chart-bar-behavior-2')),
          )
          .value,
      0.5,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 limita el grafico a cinco duraciones validas', (
    tester,
  ) async {
    final overview = await _createOverview([
      for (var day = 1; day <= 8; day++)
        _observation(id: 'registro-$day', day: day, minutes: day * 2),
    ]);

    await _pump(tester, overview, DurationMetricType.behavior);

    for (var index = 0; index < 5; index++) {
      expect(
        find.byKey(Key('duration-chart-bar-behavior-$index')),
        findsOneWidget,
      );
    }

    expect(
      find.byKey(const Key('duration-chart-bar-behavior-5')),
      findsNothing,
    );

    expect(find.text('Se muestran 5 de 8 duraciones válidas.'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 distingue cero valido de ausencia de datos', (
    tester,
  ) async {
    final overview = await _createOverview([
      _observation(
        id: 'cero',
        day: 5,
        minutes: 0,
        type: DurationMetricType.dysregulation,
      ),
    ]);

    await _pump(tester, overview, DurationMetricType.dysregulation);

    expect(find.text('0 min · registro'), findsOneWidget);

    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('duration-chart-bar-dysregulation-0')),
          )
          .value,
      0,
    );

    expect(
      find.byKey(const Key('duration-chart-empty-dysregulation')),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 representa periodos sin duraciones validas', (
    tester,
  ) async {
    final overview = await _createOverview([]);

    await _pump(tester, overview, DurationMetricType.sleep);

    expect(find.byKey(const Key('duration-chart-empty-sleep')), findsOneWidget);

    expect(find.byKey(const Key('duration-chart-bar-sleep-0')), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 mantiene las barras en pantalla estrecha', (tester) async {
    final overview = await _createOverview([
      _observation(id: 'a', day: 12, minutes: 15),
    ]);

    await _pump(tester, overview, DurationMetricType.behavior, width: 320);

    expect(
      find.byKey(const Key('duration-chart-bar-behavior-0')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });
}
