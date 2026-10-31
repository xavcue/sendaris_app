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

void main() {
  testWidgets('HU-16 conserva el total general y separa eventos de rutinas', (
    tester,
  ) async {
    final service = InternalReportService(
      calendarLoader: ({required String anonymousId}) async {
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

    // PRIMERA COMPROBACIÓN:
    // El panorama general conserva ambos registros.
    expect(
      tester
          .widget<Text>(find.byKey(const Key('internal-report-total-count')))
          .data,
      '2',
    );

    // SEGUNDA COMPROBACIÓN:
    // El resumen identifica exactamente un acontecimiento.
    expect(
      tester
          .widget<Text>(find.byKey(const Key('internal-report-events-count')))
          .data,
      '1 evento en el periodo',
    );

    // TERCERA COMPROBACIÓN:
    // Verificar el estado de rutina mientras el resumen
    // sigue montado en el árbol de widgets.
    //
    // Esta comprobación se realiza ANTES del desplazamiento
    // hacia el detalle de eventos.
    final routineChip = find.byKey(
      const Key('internal-report-count-routineStatus'),
    );

    expect(routineChip, findsOneWidget);

    expect(
      find.descendant(
        of: routineChip,
        matching: find.text('Estado de rutina: 1'),
      ),
      findsOneWidget,
    );

    // CUARTA COMPROBACIÓN:
    // Desplazarse hasta el detalle del acontecimiento.
    final eventCard = find.byKey(
      const Key('internal-report-record-behavior-conducta-1'),
    );

    await tester.scrollUntilVisible(
      eventCard,
      180,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pumpAndSettle();

    expect(eventCard, findsOneWidget);

    expect(find.text('Agresión o irritabilidad'), findsOneWidget);

    // QUINTA COMPROBACIÓN:
    // El estado de rutina no se representa como tarjeta
    // dentro del listado de acontecimientos.
    expect(
      find.byKey(const Key('internal-report-record-routineStatus-estado-1')),
      findsNothing,
    );

    // No deben existir excepciones de renderizado.
    expect(tester.takeException(), isNull);
  });
}
