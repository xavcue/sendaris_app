import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/domain/services/duration_overview_service.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/internal_reports/domain/services/internal_report_service.dart';
import 'package:sendaris/features/internal_reports/presentation/views/internal_report_view.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/domain/services/routine_overview_service.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

class _EmptyDurationRepository implements DurationRepository {
  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    return [];
  }
}

class _RoutineRepository implements RoutineComplianceRepository {
  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    return [
      RoutineComplianceEntry(
        recordId: 'estado-1',
        anonymousId: anonymousId,
        routineId: 'rutina-1',
        routineName: 'Preparar mochila',
        date: DateTime(2026, 10, 14),
        status: RoutineStatus.completed,
      ),
    ];
  }
}

Future<void> _openReport(
  WidgetTester tester,
  void Function() onCalendarLoad,
) async {
  tester.view.physicalSize = const Size(390, 850);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final service = InternalReportService(
    calendarLoader: ({required String anonymousId}) async {
      onCalendarLoad();

      return MonthlyCalendarIndex(
        anonymousId: anonymousId,
        records: [
          MonthlyCalendarRecord(
            id: 'conducta-1',
            anonymousId: anonymousId,
            date: DateTime(2026, 10, 15),
            type: CalendarRecordType.behavior,
            description: 'Agresión o irritabilidad',
          ),
          MonthlyCalendarRecord(
            id: 'estado-1',
            anonymousId: anonymousId,
            date: DateTime(2026, 10, 14),
            type: CalendarRecordType.routineStatus,
            description: 'Completada',
          ),
        ],
      );
    },
    durationService: DurationOverviewService(_EmptyDurationRepository()),
    routineService: RoutineOverviewService(_RoutineRepository()),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: InternalReportView(
        service: service,
        anonymousId: 'perfil-a',
        clock: () => DateTime(2026, 10, 15),
      ),
    ),
  );

  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('internal-report-generate-button')));

  await tester.pumpAndSettle();
}

/// Localiza y pulsa el encabezado de una sección.
///
/// Permite desplazarse hacia abajo o hacia arriba porque, en un
/// CustomScrollView, los encabezados pueden quedar fuera del
/// área visible mientras se consulta el detalle de los registros.
Future<void> _tapHeader(
  WidgetTester tester,
  String section, {
  bool towardsTop = false,
}) async {
  final finder = find.byKey(Key('internal-report-toggle-$section'));

  final delta = towardsTop ? -160.0 : 160.0;

  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pumpAndSettle();

  expect(finder, findsOneWidget);

  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('HU-16 permite contraer y expandir todas las secciones', (
    tester,
  ) async {
    var calendarLoads = 0;

    await _openReport(tester, () => calendarLoads++);

    expect(
      find.byKey(const Key('internal-report-total-count')),
      findsOneWidget,
    );

    final collapseButton = find.byKey(
      const Key('internal-report-collapse-all'),
    );

    await tester.ensureVisible(collapseButton);
    await tester.pumpAndSettle();

    await tester.tap(collapseButton);
    await tester.pumpAndSettle();

    // Los encabezados permanecen disponibles,
    // pero no se construye el contenido plegado.
    expect(
      find.byKey(const Key('internal-report-section-summary')),
      findsOneWidget,
    );

    expect(find.byKey(const Key('internal-report-total-count')), findsNothing);

    expect(
      find.byKey(const Key('internal-report-coverage-card')),
      findsNothing,
    );

    expect(
      find.byKey(const Key('internal-report-record-behavior-conducta-1')),
      findsNothing,
    );

    final expandButton = find.byKey(const Key('internal-report-expand-all'));

    await tester.ensureVisible(expandButton);
    await tester.pumpAndSettle();

    await tester.tap(expandButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('internal-report-total-count')),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('internal-report-coverage-card')),
      findsOneWidget,
    );

    // Abrir y cerrar secciones no genera nuevas consultas.
    expect(calendarLoads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 permite abrir solamente la lista de eventos', (
    tester,
  ) async {
    var calendarLoads = 0;

    await _openReport(tester, () => calendarLoads++);

    final collapseButton = find.byKey(
      const Key('internal-report-collapse-all'),
    );

    await tester.ensureVisible(collapseButton);
    await tester.pumpAndSettle();

    await tester.tap(collapseButton);
    await tester.pumpAndSettle();

    // Se abre exclusivamente el detalle de eventos.
    await _tapHeader(tester, 'events');

    final event = find.byKey(
      const Key('internal-report-record-behavior-conducta-1'),
    );

    await tester.scrollUntilVisible(
      event,
      160,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(event, findsOneWidget);
    expect(find.text('Agresión o irritabilidad'), findsOneWidget);

    // La rutina permanece excluida del detalle de eventos.
    expect(
      find.byKey(const Key('internal-report-record-routineStatus-estado-1')),
      findsNothing,
    );

    // Las tarjetas individuales de rutina siguen plegadas.
    expect(
      find.byKey(const Key('internal-report-routine-detail-estado-1')),
      findsNothing,
    );

    // El encabezado está ARRIBA de la tarjeta.
    // Se regresa desplazándose hacia arriba y se cierra.
    await _tapHeader(tester, 'events', towardsTop: true);

    // Una sección cerrada no construye sus tarjetas.
    expect(event, findsNothing);

    // No se generan consultas adicionales al alternar la sección.
    expect(calendarLoads, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 pliega rutinas y duraciones de manera independiente', (
    tester,
  ) async {
    var calendarLoads = 0;

    await _openReport(tester, () => calendarLoads++);

    final collapseButton = find.byKey(
      const Key('internal-report-collapse-all'),
    );

    await tester.ensureVisible(collapseButton);
    await tester.pumpAndSettle();

    await tester.tap(collapseButton);
    await tester.pumpAndSettle();

    await _tapHeader(tester, 'compliance');

    final routinePercentage = find.byKey(
      const Key('internal-report-routine-percentage'),
    );

    await tester.scrollUntilVisible(
      routinePercentage,
      160,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(routinePercentage, findsOneWidget);

    // El detalle individual todavía está cerrado.
    expect(
      find.byKey(const Key('internal-report-routine-detail-estado-1')),
      findsNothing,
    );

    await _tapHeader(tester, 'routines');

    final routineCard = find.byKey(
      const Key('internal-report-routine-detail-estado-1'),
    );

    await tester.scrollUntilVisible(
      routineCard,
      160,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(routineCard, findsOneWidget);
    expect(find.text('Preparar mochila'), findsOneWidget);

    // Las duraciones permanecen cerradas.
    expect(
      find.byKey(const Key('internal-report-duration-sleep')),
      findsNothing,
    );

    await _tapHeader(tester, 'durations');

    final sleepDuration = find.byKey(
      const Key('internal-report-duration-sleep'),
    );

    await tester.scrollUntilVisible(
      sleepDuration,
      160,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(sleepDuration, findsOneWidget);

    // Las interacciones no provocan nuevas consultas.
    expect(calendarLoads, 1);
    expect(tester.takeException(), isNull);
  });
}
