import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/domain/services/duration_overview_service.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/internal_reports/domain/models/internal_report.dart';
import 'package:sendaris/features/internal_reports/domain/services/internal_report_service.dart';
import 'package:sendaris/features/internal_reports/presentation/widgets/internal_report_category_chart.dart';
import 'package:sendaris/features/period_comparison/domain/models/comparison_period.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/domain/services/routine_overview_service.dart';

class _EmptyDurations implements DurationRepository {
  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    return [];
  }
}

class _EmptyRoutines implements RoutineComplianceRepository {
  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    return [];
  }
}

Future<InternalReport> _buildReport({
  required List<CalendarRecordType> categories,
}) {
  const anonymousId = 'perfil-ficticio';

  final records = [
    for (var index = 0; index < categories.length; index++)
      MonthlyCalendarRecord(
        id: 'registro-$index',
        anonymousId: anonymousId,
        date: DateTime(2026, 10, index + 1),
        type: categories[index],
        description: categories[index].label,
      ),
  ];

  return InternalReportService(
    calendarLoader: ({required String anonymousId}) async {
      return MonthlyCalendarIndex(anonymousId: anonymousId, records: records);
    },
    durationService: DurationOverviewService(_EmptyDurations()),
    routineService: RoutineOverviewService(_EmptyRoutines()),
  ).generate(
    anonymousId: anonymousId,
    period: ComparisonPeriod(
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 31),
    ),
  );
}

Future<void> _pumpChart(WidgetTester tester, InternalReport report) async {
  tester.view.physicalSize = const Size(420, 1000);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: InternalReportCategoryChart(report: report),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('HU-16 grafico presenta conteos y porcentajes correctos', (
    tester,
  ) async {
    final report = await _buildReport(
      categories: [
        CalendarRecordType.behavior,
        CalendarRecordType.behavior,
        CalendarRecordType.sleep,
        CalendarRecordType.routineStatus,
      ],
    );

    await _pumpChart(tester, report);

    expect(
      find.byKey(const Key('internal-report-category-chart')),
      findsOneWidget,
    );

    expect(find.text('Conducta'), findsOneWidget);

    expect(find.text('2 · 50.0 %'), findsOneWidget);

    expect(find.text('1 · 25.0 %'), findsNWidgets(2));

    expect(
      find.byKey(const Key('internal-report-chart-bar-behavior')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('internal-report-chart-bar-sleep')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('internal-report-chart-bar-feeding')),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 grafico presenta ausencia de registros', (tester) async {
    final report = await _buildReport(categories: []);

    await _pumpChart(tester, report);

    expect(
      find.byKey(const Key('internal-report-chart-empty')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('internal-report-chart-bar-behavior')),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });
}
