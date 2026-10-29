import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/period_comparison/presentation/views/period_comparison_view.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';

class _FakeDurationRepository implements DurationRepository {
  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    final samples = [
      DurationObservation(
        recordId: 'sueno-a',
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.sleep,
        date: DateTime(2026, 10, 4),
        durationMinutes: 480,
      ),
      DurationObservation(
        recordId: 'sueno-b',
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.sleep,
        date: DateTime(2026, 10, 12),
        durationMinutes: 600,
      ),
    ];

    return samples
        .where(
          (record) =>
              record.anonymousId == anonymousId &&
              record.metricType == metricType,
        )
        .toList();
  }
}

class _FakeRoutineRepository implements RoutineComplianceRepository {
  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    return <RoutineComplianceEntry>[];
  }
}

void _configureScreen(
  WidgetTester tester, {
  required double width,
  required double height,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  const screenSizes = [
    (label: 'movil', width: 360.0, height: 800.0),
    (label: 'tablet', width: 800.0, height: 1280.0),
  ];

  for (final screen in screenSizes) {
    testWidgets('HU-20 presenta valores legibles en ${screen.label}', (
      tester,
    ) async {
      _configureScreen(tester, width: screen.width, height: screen.height);

      await tester.pumpWidget(
        MaterialApp(
          home: PeriodComparisonView(
            durationRepository: _FakeDurationRepository(),
            routineComplianceRepository: _FakeRoutineRepository(),
            anonymousId: 'perfil-a',
            clock: () => DateTime(2026, 10, 15),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('period-comparison-results')), findsNothing);

      await tester.tap(
        find.byKey(const Key('period-comparison-compare-button')),
      );

      await tester.pumpAndSettle();

      final valueA = find.byKey(const Key('period-comparison-value-sleep-a'));

      await tester.scrollUntilVisible(
        valueA,
        180,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('period-comparison-results-heading')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('period-comparison-result-periods')),
        findsOneWidget,
      );

      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('period-comparison-result-dates-a')),
            )
            .data,
        '02/10/2026 – 08/10/2026',
      );

      expect(
        tester
            .widget<Text>(
              find.byKey(const Key('period-comparison-result-dates-b')),
            )
            .data,
        '09/10/2026 – 15/10/2026',
      );

      expect(tester.widget<Text>(valueA).data, '8 h');

      expect(tester.widget<Text>(valueA).style?.fontSize, 21);

      expect(tester.takeException(), isNull);
    });
  }
}
