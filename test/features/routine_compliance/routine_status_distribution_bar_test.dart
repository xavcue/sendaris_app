import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/domain/services/routine_overview_service.dart';
import 'package:sendaris/features/routine_compliance/presentation/views/routine_compliance_view.dart';
import 'package:sendaris/features/routine_compliance/presentation/widgets/routine_status_distribution_bar.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

class _FakeRoutineRepository implements RoutineComplianceRepository {
  _FakeRoutineRepository(this.records);

  final List<RoutineComplianceEntry> records;

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    return records
        .where((record) => record.anonymousId == anonymousId)
        .toList();
  }
}

List<RoutineComplianceEntry> _entries(
  List<RoutineStatus> statuses, {
  DateTime? date,
}) {
  final day = date ?? DateTime(2026, 10, 15);

  return [
    for (var index = 0; index < statuses.length; index++)
      RoutineComplianceEntry(
        recordId: 'registro-$index',
        anonymousId: 'perfil-ficticio',
        routineId: 'rutina-1',
        date: day,
        status: statuses[index],
      ),
  ];
}

Future<RoutineOverview> _overview(List<RoutineStatus> statuses) {
  return RoutineOverviewService(_FakeRoutineRepository(_entries(statuses)))
      .load(
        anonymousId: 'perfil-ficticio',
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 31),
      );
}

Future<void> _pumpChart(
  WidgetTester tester,
  RoutineOverview overview, {
  double width = 360,
  double height = 800,
}) async {
  tester.view.physicalSize = Size(width, height);
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
            child: RoutineStatusDistributionBar(overview: overview),
          ),
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('HU-16 representa 2 completadas y 1 interrumpida', (
    tester,
  ) async {
    final overview = await _overview([
      RoutineStatus.completed,
      RoutineStatus.completed,
      RoutineStatus.interrupted,
    ]);

    await _pumpChart(tester, overview);

    expect(overview.totalRecords, 3);
    expect(overview.completedCount, 2);
    expect(overview.compliancePercentage, closeTo(66.6667, 0.001));

    expect(
      find.byKey(const Key('routine-status-distribution-card')),
      findsOneWidget,
    );

    expect(find.text('Completada: 2 (66.7 %)'), findsOneWidget);

    expect(find.text('Interrumpida: 1 (33.3 %)'), findsOneWidget);

    expect(find.text('Modificada: 0 (0.0 %)'), findsOneWidget);

    expect(find.text('No realizada: 0 (0.0 %)'), findsOneWidget);

    expect(
      tester
          .widget<Expanded>(
            find.byKey(const Key('routine-status-segment-completed')),
          )
          .flex,
      2,
    );

    expect(
      tester
          .widget<Expanded>(
            find.byKey(const Key('routine-status-segment-interrupted')),
          )
          .flex,
      1,
    );

    expect(
      find.byKey(const Key('routine-status-segment-modified')),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 sin datos omite segmentos y porcentajes', (tester) async {
    final overview = await _overview([]);

    await _pumpChart(tester, overview);

    expect(overview.totalRecords, 0);
    expect(overview.compliancePercentage, isNull);

    expect(
      find.byKey(const Key('routine-status-distribution-empty')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('routine-status-distribution-track')),
      findsNothing,
    );

    for (final status in RoutineStatus.values) {
      expect(
        find.byKey(Key('routine-status-segment-${status.name}')),
        findsNothing,
      );
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 conserva cero valido con estados no completados', (
    tester,
  ) async {
    final overview = await _overview([
      RoutineStatus.modified,
      RoutineStatus.notCompleted,
    ]);

    await _pumpChart(tester, overview);

    expect(overview.totalRecords, 2);
    expect(overview.completedCount, 0);
    expect(overview.compliancePercentage, 0);

    expect(find.text('Modificada: 1 (50.0 %)'), findsOneWidget);

    expect(find.text('No realizada: 1 (50.0 %)'), findsOneWidget);

    expect(find.text('Completada: 0 (0.0 %)'), findsOneWidget);

    expect(
      find.byKey(const Key('routine-status-distribution-empty')),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 muestra el grafico en la pantalla real de rutinas', (
    tester,
  ) async {
    final today = DateTime.now();

    final repository = _FakeRoutineRepository(
      _entries([
        RoutineStatus.completed,
        RoutineStatus.interrupted,
      ], date: DateTime(today.year, today.month, today.day)),
    );

    tester.view.physicalSize = const Size(420, 1100);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: RoutineComplianceView(
          repository: repository,
          anonymousId: 'perfil-ficticio',
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('routine-status-distribution-card')),
      findsOneWidget,
    );

    expect(find.text('Completada: 1 (50.0 %)'), findsOneWidget);

    expect(find.text('Interrumpida: 1 (50.0 %)'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
