import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/domain/services/duration_overview_service.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/internal_reports/domain/models/internal_report.dart';
import 'package:sendaris/features/internal_reports/domain/services/internal_report_service.dart';
import 'package:sendaris/features/internal_reports/presentation/views/internal_report_view.dart';
import 'package:sendaris/features/period_comparison/domain/models/comparison_period.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/domain/services/routine_overview_service.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

class _FakeDurationRepository implements DurationRepository {
  _FakeDurationRepository({this.observations = const []});

  final List<DurationObservation> observations;
  final List<String> requests = [];

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    requests.add('$anonymousId:${metricType.name}');

    return observations
        .where(
          (record) =>
              record.anonymousId == anonymousId &&
              record.metricType == metricType,
        )
        .toList();
  }
}

class _FakeRoutineRepository implements RoutineComplianceRepository {
  _FakeRoutineRepository({this.entries = const []});

  final List<RoutineComplianceEntry> entries;
  final List<String> requests = [];

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    requests.add(anonymousId);

    return entries.where((entry) => entry.anonymousId == anonymousId).toList();
  }
}

class _FakeCalendarLoader {
  _FakeCalendarLoader(this.index);

  final MonthlyCalendarIndex index;
  final List<String> requestedIds = [];

  Future<MonthlyCalendarIndex> recover({required String anonymousId}) async {
    requestedIds.add(anonymousId);
    return index;
  }
}

class _DeferredReportService implements InternalReportService {
  final List<Completer<InternalReport>> pending = [];
  final List<String> requestedIds = [];

  @override
  Future<InternalReport> generate({
    required String anonymousId,
    required ComparisonPeriod period,
  }) {
    requestedIds.add(anonymousId);
    final completer = Completer<InternalReport>();
    pending.add(completer);
    return completer.future;
  }

  void complete(int index, InternalReport report) {
    pending[index].complete(report);
  }
}

MonthlyCalendarRecord _record({
  required String id,
  required int day,
  required CalendarRecordType type,
  String anonymousId = 'perfil-a',
}) {
  return MonthlyCalendarRecord(
    id: id,
    anonymousId: anonymousId,
    date: DateTime(2026, 10, day),
    type: type,
    description: type.label,
  );
}

DurationObservation _duration({
  required String id,
  required int day,
  required DurationMetricType type,
  required int minutes,
  String anonymousId = 'perfil-a',
}) {
  return DurationObservation(
    recordId: id,
    anonymousId: anonymousId,
    metricType: type,
    date: DateTime(2026, 10, day),
    durationMinutes: minutes,
  );
}

RoutineComplianceEntry _routine({
  required String id,
  required int day,
  required RoutineStatus status,
  String anonymousId = 'perfil-a',
}) {
  return RoutineComplianceEntry(
    recordId: id,
    anonymousId: anonymousId,
    routineId: 'rutina-ficticia',
    date: DateTime(2026, 10, day),
    status: status,
  );
}

InternalReportService _createService({
  required _FakeCalendarLoader calendar,
  required _FakeDurationRepository durations,
  required _FakeRoutineRepository routines,
}) {
  return InternalReportService(
    calendarLoader: calendar.recover,
    durationService: DurationOverviewService(durations),
    routineService: RoutineOverviewService(routines),
  );
}

Future<InternalReport> _makeReport({
  required String anonymousId,
  List<MonthlyCalendarRecord> records = const [],
}) {
  return InternalReportService(
    calendarLoader: ({required String anonymousId}) async {
      return MonthlyCalendarIndex(anonymousId: anonymousId, records: records);
    },
    durationService: DurationOverviewService(_FakeDurationRepository()),
    routineService: RoutineOverviewService(_FakeRoutineRepository()),
  ).generate(
    anonymousId: anonymousId,
    period: ComparisonPeriod(
      startDate: DateTime(2026, 9, 16),
      endDate: DateTime(2026, 10, 15),
    ),
  );
}

void _setScreen(
  WidgetTester tester, {
  double width = 360,
  double height = 800,
}) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Widget _buildView(
  InternalReportService service, {
  String anonymousId = 'perfil-a',
}) {
  return MaterialApp(
    home: InternalReportView(
      service: service,
      anonymousId: anonymousId,
      clock: () => DateTime(2026, 10, 15),
    ),
  );
}

Future<void> _pumpView(
  WidgetTester tester,
  InternalReportService service, {
  double width = 360,
  double height = 800,
}) async {
  _setScreen(tester, width: width, height: height);

  await tester.pumpWidget(_buildView(service));
  await tester.pumpAndSettle();
}

/// Desplaza la pantalla hasta un widget, incluso si pertenece
/// a un sliver que aún no ha sido construido.
///
/// Esto evita asumir que todos los indicadores de un
/// CustomScrollView están montados simultáneamente.
Future<void> _scrollTo(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));

  await tester.scrollUntilVisible(
    finder,
    180,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pumpAndSettle();

  expect(finder, findsOneWidget);
}

/// Comprueba valores de indicadores después de hacerlos visibles.
Future<void> _expectIndicator(
  WidgetTester tester,
  String key,
  String expected,
) async {
  await _scrollTo(tester, key);

  final text = tester.widget<Text>(find.byKey(Key(key)));

  expect(text.data, expected);
}

void main() {
  testWidgets('HU-16 inicia con fechas y sin consultas automaticas', (
    tester,
  ) async {
    final durations = _FakeDurationRepository();
    final routines = _FakeRoutineRepository();

    final calendar = _FakeCalendarLoader(
      MonthlyCalendarIndex(anonymousId: 'perfil-a', records: []),
    );

    await _pumpView(
      tester,
      _createService(
        calendar: calendar,
        durations: durations,
        routines: routines,
      ),
    );

    expect(find.byKey(const Key('internal-report-screen')), findsOneWidget);

    expect(find.text('Reportes internos'), findsOneWidget);
    expect(find.text('Reporte del seguimiento'), findsOneWidget);

    expect(find.text('16/09/2026 – 15/10/2026'), findsOneWidget);

    expect(find.byKey(const Key('internal-report-start-date')), findsOneWidget);

    expect(find.byKey(const Key('internal-report-end-date')), findsOneWidget);

    expect(find.byKey(const Key('internal-report-prompt')), findsOneWidget);

    expect(find.byKey(const Key('internal-report-results')), findsNothing);

    expect(calendar.requestedIds, isEmpty);
    expect(durations.requests, isEmpty);
    expect(routines.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 muestra registros, cobertura e indicadores conocidos', (
    tester,
  ) async {
    final calendar = _FakeCalendarLoader(
      MonthlyCalendarIndex(
        anonymousId: 'perfil-a',
        records: [
          _record(id: 'sueno-1', day: 1, type: CalendarRecordType.sleep),
          _record(id: 'conducta-1', day: 14, type: CalendarRecordType.behavior),
          _record(
            id: 'fuera-del-periodo',
            day: 16,
            type: CalendarRecordType.feeding,
          ),
          _record(
            id: 'otro-perfil',
            day: 12,
            type: CalendarRecordType.behavior,
            anonymousId: 'perfil-b',
          ),
        ],
      ),
    );

    final durations = _FakeDurationRepository(
      observations: [
        _duration(
          id: 'sueno-1',
          day: 1,
          type: DurationMetricType.sleep,
          minutes: 480,
        ),
        _duration(
          id: 'sueno-2',
          day: 14,
          type: DurationMetricType.sleep,
          minutes: 600,
        ),
        _duration(
          id: 'conducta-1',
          day: 14,
          type: DurationMetricType.behavior,
          minutes: 12,
        ),
      ],
    );

    final routines = _FakeRoutineRepository(
      entries: [
        _routine(id: 'completada', day: 1, status: RoutineStatus.completed),
        _routine(id: 'modificada', day: 14, status: RoutineStatus.modified),
      ],
    );

    await _pumpView(
      tester,
      _createService(
        calendar: calendar,
        durations: durations,
        routines: routines,
      ),
    );

    await tester.tap(find.byKey(const Key('internal-report-generate-button')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('internal-report-results')), findsOneWidget);

    // Panorama: se comprueban los registros y la cobertura.
    expect(
      tester
          .widget<Text>(find.byKey(const Key('internal-report-total-count')))
          .data,
      '2',
    );

    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('internal-report-coverage-percentage')),
          )
          .data,
      '6.7 %',
    );

    // Detalle de eventos: antes de rutinas y duraciones.
    final recentRecord = find.byKey(
      const Key('internal-report-record-behavior-conducta-1'),
    );

    await _scrollTo(tester, 'internal-report-record-behavior-conducta-1');

    expect(recentRecord, findsOneWidget);

    // Un registro ajeno o fuera del periodo no debe aparecer.
    expect(
      find.byKey(const Key('internal-report-record-behavior-otro-perfil')),
      findsNothing,
    );

    expect(
      find.byKey(const Key('internal-report-record-feeding-fuera-del-periodo')),
      findsNothing,
    );

    // Cumplimiento de rutinas, después del detalle de eventos.
    await _expectIndicator(
      tester,
      'internal-report-routine-percentage',
      '50 %',
    );

    await _scrollTo(tester, 'routine-status-distribution-card');

    expect(find.text('Completada: 1 (50.0 %)'), findsOneWidget);

    expect(find.text('Modificada: 1 (50.0 %)'), findsOneWidget);

    // Duraciones: cada valor se comprueba después de desplazarse
    // hasta su sección, respetando la construcción diferida.
    await _expectIndicator(
      tester,
      'internal-report-duration-value-sleep',
      '9 h',
    );

    await _expectIndicator(
      tester,
      'internal-report-duration-value-behavior',
      '12 min',
    );

    await _expectIndicator(
      tester,
      'internal-report-duration-value-dysregulation',
      'Sin datos',
    );

    // La generación del reporte se realiza una única vez.
    expect(calendar.requestedIds, ['perfil-a']);
    expect(durations.requests, hasLength(3));
    expect(routines.requests, ['perfil-a']);

    // Ninguna sección permite compartir o descargar información.
    expect(find.byIcon(Icons.share_outlined), findsNothing);

    expect(find.byIcon(Icons.download_outlined), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 presenta ausencia de datos sin inventar valores', (
    tester,
  ) async {
    final calendar = _FakeCalendarLoader(
      MonthlyCalendarIndex(anonymousId: 'perfil-a', records: []),
    );

    await _pumpView(
      tester,
      _createService(
        calendar: calendar,
        durations: _FakeDurationRepository(),
        routines: _FakeRoutineRepository(),
      ),
    );

    await tester.tap(find.byKey(const Key('internal-report-generate-button')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('internal-report-no-data')), findsOneWidget);

    expect(
      tester
          .widget<Text>(find.byKey(const Key('internal-report-total-count')))
          .data,
      '0',
    );

    expect(
      tester
          .widget<Text>(
            find.byKey(const Key('internal-report-coverage-percentage')),
          )
          .data,
      '0 %',
    );

    // El cumplimiento se encuentra después del panorama.
    await _expectIndicator(
      tester,
      'internal-report-routine-percentage',
      'Sin datos',
    );

    // Las tres categorías deben representar ausencia de datos.
    for (final type in DurationMetricType.values) {
      await _expectIndicator(
        tester,
        'internal-report-duration-value-${type.name}',
        'Sin datos',
      );
    }

    // No deben existir tarjetas ni encabezados de eventos.
    expect(
      find.byKey(const Key('internal-report-records-title')),
      findsNothing,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 abre fechas sin consultar y permite cancelar', (
    tester,
  ) async {
    final calendar = _FakeCalendarLoader(
      MonthlyCalendarIndex(anonymousId: 'perfil-a', records: []),
    );

    final durations = _FakeDurationRepository();
    final routines = _FakeRoutineRepository();

    await _pumpView(
      tester,
      _createService(
        calendar: calendar,
        durations: durations,
        routines: routines,
      ),
    );

    await tester.tap(find.byKey(const Key('internal-report-start-date')));

    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(calendar.requestedIds, isEmpty);
    expect(durations.requests, isEmpty);
    expect(routines.requests, isEmpty);

    expect(find.byKey(const Key('internal-report-results')), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 controla errores sin mostrar resultados parciales', (
    tester,
  ) async {
    final service = InternalReportService(
      calendarLoader: ({required String anonymousId}) async {
        throw StateError('Error simulado de recuperación');
      },
      durationService: DurationOverviewService(_FakeDurationRepository()),
      routineService: RoutineOverviewService(_FakeRoutineRepository()),
    );

    await _pumpView(tester, service);

    await tester.tap(find.byKey(const Key('internal-report-generate-button')));

    await tester.pumpAndSettle();

    expect(find.byKey(const Key('internal-report-error')), findsOneWidget);

    expect(find.byKey(const Key('internal-report-results')), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('HU-16 no muestra resultados antiguos al cambiar seguimiento', (
    tester,
  ) async {
    final service = _DeferredReportService();

    final reportA = await _makeReport(
      anonymousId: 'perfil-a',
      records: [
        _record(id: 'registro-a1', day: 4, type: CalendarRecordType.behavior),
        _record(id: 'registro-a2', day: 5, type: CalendarRecordType.sleep),
      ],
    );

    final reportB = await _makeReport(
      anonymousId: 'perfil-b',
      records: [
        _record(
          id: 'registro-b',
          day: 12,
          type: CalendarRecordType.feeding,
          anonymousId: 'perfil-b',
        ),
      ],
    );

    _setScreen(tester);

    await tester.pumpWidget(_buildView(service));

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('internal-report-generate-button')));

    await tester.pump();

    expect(find.byKey(const Key('internal-report-loading')), findsOneWidget);

    // El usuario cambia al seguimiento B durante la carga de A.
    await tester.pumpWidget(_buildView(service, anonymousId: 'perfil-b'));

    await tester.pump();

    expect(find.byKey(const Key('internal-report-prompt')), findsOneWidget);

    expect(find.byKey(const Key('internal-report-results')), findsNothing);

    await tester.tap(find.byKey(const Key('internal-report-generate-button')));

    await tester.pump();

    expect(service.requestedIds, ['perfil-a', 'perfil-b']);

    // Finaliza primero B y se muestra únicamente su información.
    service.complete(1, reportB);

    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('internal-report-total-count')))
          .data,
      '1',
    );

    // La respuesta tardía de A no puede sustituir a B.
    service.complete(0, reportA);

    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Text>(find.byKey(const Key('internal-report-total-count')))
          .data,
      '1',
    );

    expect(tester.takeException(), isNull);
  });

  for (final size in [
    (name: 'movil', width: 360.0, height: 800.0),
    (name: 'tablet', width: 800.0, height: 1280.0),
  ]) {
    testWidgets('HU-16 conserva el diseño en ${size.name}', (tester) async {
      final calendar = _FakeCalendarLoader(
        MonthlyCalendarIndex(anonymousId: 'perfil-a', records: []),
      );

      final service = _createService(
        calendar: calendar,
        durations: _FakeDurationRepository(),
        routines: _FakeRoutineRepository(),
      );

      await _pumpView(tester, service, width: size.width, height: size.height);

      await tester.tap(
        find.byKey(const Key('internal-report-generate-button')),
      );

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('internal-report-results')), findsOneWidget);

      expect(
        find.byKey(const Key('internal-report-coverage-card')),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });
  }
}
