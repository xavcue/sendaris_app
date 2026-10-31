import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/period_comparison/presentation/widgets/period_comparison_bar_chart.dart';

Future<void> pumpChart(
  WidgetTester tester, {
  required double? a,
  required double? b,
  bool percentage = false,
  double width = 320,
}) async {
  tester.view.physicalSize = Size(width, 700);
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
            child: PeriodComparisonBarChart(
              metricKey: 'test',
              valueA: a,
              valueB: b,
              displayA: percentage ? '${a ?? 0} %' : '${a ?? 0} min',
              displayB: percentage ? '${b ?? 0} %' : '${b ?? 0} min',
              unit: percentage ? '%' : 'minutos',
              isPercentage: percentage,
            ),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('comparte escala entre A y B de la misma metrica', (
    tester,
  ) async {
    await pumpChart(tester, a: 480, b: 360);

    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('period-comparison-chart-bar-test-a')),
          )
          .value,
      1,
    );

    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('period-comparison-chart-bar-test-b')),
          )
          .value,
      0.75,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('porcentaje utiliza escala fija de 100', (tester) async {
    await pumpChart(tester, a: 50, b: 75, percentage: true);

    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('period-comparison-chart-bar-test-a')),
          )
          .value,
      0.5,
    );

    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('period-comparison-chart-bar-test-b')),
          )
          .value,
      0.75,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('sin datos no crea una barra numerica', (tester) async {
    await pumpChart(tester, a: null, b: 20);

    expect(
      find.byKey(const Key('period-comparison-chart-empty-test-a')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('period-comparison-chart-bar-test-a')),
      findsNothing,
    );

    expect(
      find.byKey(const Key('period-comparison-chart-bar-test-b')),
      findsOneWidget,
    );

    expect(find.text('Periodo A · Sin datos'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('cero valido se distingue de ausencia', (tester) async {
    await pumpChart(tester, a: 0, b: null);

    expect(
      tester
          .widget<LinearProgressIndicator>(
            find.byKey(const Key('period-comparison-chart-bar-test-a')),
          )
          .value,
      0,
    );

    expect(
      find.byKey(const Key('period-comparison-chart-empty-test-b')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('valores negativos o no finitos no se grafican', (tester) async {
    await pumpChart(tester, a: double.nan, b: -10);

    expect(
      find.byKey(const Key('period-comparison-chart-empty-test-a')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('period-comparison-chart-empty-test-b')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('respeta un ancho de pantalla reducido', (tester) async {
    await pumpChart(tester, a: 10, b: 5, width: 280);

    expect(
      find.byKey(const Key('period-comparison-chart-test')),
      findsOneWidget,
    );

    expect(tester.takeException(), isNull);
  });
}
