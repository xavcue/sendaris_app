import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/period_comparison/presentation/views/period_comparison_view.dart';
import 'package:sendaris/features/routine_compliance/domain/exceptions/routine_compliance_failure.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
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
        .where((record) => record.metricType == metricType)
        .toList();
  }
}

class _FakeRoutineRepository implements RoutineComplianceRepository {
  _FakeRoutineRepository({this.entries = const [], this.failure});

  final List<RoutineComplianceEntry> entries;
  final Object? failure;
  final List<String> requests = [];

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    requests.add(anonymousId);

    if (failure != null) {
      throw failure!;
    }

    return List<RoutineComplianceEntry>.of(entries);
  }
}

class _DeferredDurationRepository implements DurationRepository {
  final Map<String, List<Completer<List<DurationObservation>>>> pending = {};

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) {
    final key = '$anonymousId:${metricType.name}';
    final completer = Completer<List<DurationObservation>>();

    pending.putIfAbsent(key, () => []).add(completer);

    return completer.future;
  }

  void completeProfile(
    String anonymousId,
    List<DurationObservation> observations,
  ) {
    for (final type in DurationMetricType.values) {
      final key = '$anonymousId:${type.name}';
      final matching = observations
          .where((item) => item.metricType == type)
          .toList();

      for (final completer in pending[key]!) {
        if (!completer.isCompleted) {
          completer.complete(matching);
        }
      }
    }
  }
}

class _DeferredRoutineRepository implements RoutineComplianceRepository {
  final Map<String, List<Completer<List<RoutineComplianceEntry>>>> pending = {};

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) {
    final completer = Completer<List<RoutineComplianceEntry>>();

    pending.putIfAbsent(anonymousId, () => []).add(completer);

    return completer.future;
  }

  void completeProfile(
    String anonymousId,
    List<RoutineComplianceEntry> entries,
  ) {
    for (final completer in pending[anonymousId]!) {
      if (!completer.isCompleted) {
        completer.complete(List<RoutineComplianceEntry>.of(entries));
      }
    }
  }
}

DurationObservation _duration({
  required String id,
  required DurationMetricType type,
  required int day,
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

Future<void> _pumpView(
  WidgetTester tester, {
  required DurationRepository durationRepository,
  required RoutineComplianceRepository routineRepository,
  String anonymousId = 'perfil-a',
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: PeriodComparisonView(
        durationRepository: durationRepository,
        routineComplianceRepository: routineRepository,
        anonymousId: anonymousId,
        clock: () => DateTime(2026, 10, 15),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('inicia con periodos A/B y sin consultas automaticas', (
    tester,
  ) async {
    final durations = _FakeDurationRepository();
    final routines = _FakeRoutineRepository();

    await _pumpView(
      tester,
      durationRepository: durations,
      routineRepository: routines,
    );

    expect(find.byKey(const Key('period-comparison-screen')), findsOneWidget);

    expect(find.text('Comparar periodos'), findsNWidgets(2));
    expect(find.text('Comparación descriptiva'), findsOneWidget);

    expect(find.byKey(const Key('period-comparison-period-a')), findsOneWidget);
    expect(find.byKey(const Key('period-comparison-period-b')), findsOneWidget);

    expect(find.text('02/10/2026 – 08/10/2026'), findsOneWidget);
    expect(find.text('09/10/2026 – 15/10/2026'), findsOneWidget);

    expect(find.byKey(const Key('period-comparison-prompt')), findsOneWidget);
    expect(find.byKey(const Key('period-comparison-results')), findsNothing);

    expect(durations.requests, isEmpty);
    expect(routines.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra correctamente las cuatro metricas de A y B', (
    tester,
  ) async {
    final durations = _FakeDurationRepository(
      observations: [
        _duration(
          id: 'sleep-a',
          type: DurationMetricType.sleep,
          day: 2,
          minutes: 480,
        ),
        _duration(
          id: 'sleep-b',
          type: DurationMetricType.sleep,
          day: 12,
          minutes: 360,
        ),
        _duration(
          id: 'behavior-a',
          type: DurationMetricType.behavior,
          day: 5,
          minutes: 12,
        ),
        _duration(
          id: 'dysregulation-a',
          type: DurationMetricType.dysregulation,
          day: 6,
          minutes: 0,
        ),
      ],
    );

    final routines = _FakeRoutineRepository(
      entries: [
        _routine(id: 'completed-a', day: 2, status: RoutineStatus.completed),
        _routine(id: 'modified-a', day: 8, status: RoutineStatus.modified),
        _routine(id: 'modified-b', day: 12, status: RoutineStatus.modified),
      ],
    );

    await _pumpView(
      tester,
      durationRepository: durations,
      routineRepository: routines,
    );

    await tester.tap(find.byKey(const Key('period-comparison-compare-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('period-comparison-results')), findsOneWidget);

    expect(find.text('8 h'), findsOneWidget);
    expect(find.text('6 h'), findsOneWidget);

    expect(find.text('12 min'), findsOneWidget);
    expect(find.text('0 min'), findsOneWidget);

    expect(find.text('50 %'), findsOneWidget);
    expect(find.text('0 %'), findsOneWidget);

    expect(
      find.descendant(
        of: find.byKey(const Key('period-comparison-metric-behavior')),
        matching: find.text('Sin datos'),
      ),
      findsOneWidget,
    );

    expect(
      find.byKey(const Key('period-comparison-disclaimer')),
      findsOneWidget,
    );

    expect(durations.requests, hasLength(6));
    expect(routines.requests, hasLength(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dos periodos sin datos muestran ausencia de informacion', (
    tester,
  ) async {
    await _pumpView(
      tester,
      durationRepository: _FakeDurationRepository(),
      routineRepository: _FakeRoutineRepository(),
    );

    await tester.tap(find.byKey(const Key('period-comparison-compare-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('period-comparison-no-data')), findsOneWidget);

    expect(find.byKey(const Key('period-comparison-results')), findsOneWidget);

    expect(find.text('0 min'), findsNothing);
    expect(find.text('0 %'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('abre el selector de fechas sin hacer consultas', (tester) async {
    final durations = _FakeDurationRepository();
    final routines = _FakeRoutineRepository();

    await _pumpView(
      tester,
      durationRepository: durations,
      routineRepository: routines,
    );

    await tester.tap(find.byKey(const Key('period-comparison-start-a')));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(durations.requests, isEmpty);
    expect(routines.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('muestra errores del repositorio sin valores parciales', (
    tester,
  ) async {
    const message = 'No fue posible recuperar los estados.';

    await _pumpView(
      tester,
      durationRepository: _FakeDurationRepository(),
      routineRepository: _FakeRoutineRepository(
        failure: const RoutineComplianceFailure(message),
      ),
    );

    await tester.tap(find.byKey(const Key('period-comparison-compare-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('period-comparison-error')), findsOneWidget);
    expect(find.text(message), findsOneWidget);

    expect(find.byKey(const Key('period-comparison-results')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no muestra respuestas del seguimiento anterior', (tester) async {
    final durations = _DeferredDurationRepository();
    final routines = _DeferredRoutineRepository();

    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    Widget buildFor(String anonymousId) {
      return MaterialApp(
        home: PeriodComparisonView(
          durationRepository: durations,
          routineComplianceRepository: routines,
          anonymousId: anonymousId,
          clock: () => DateTime(2026, 10, 15),
        ),
      );
    }

    await tester.pumpWidget(buildFor('perfil-a'));

    await tester.tap(find.byKey(const Key('period-comparison-compare-button')));
    await tester.pump();

    expect(find.byKey(const Key('period-comparison-loading')), findsOneWidget);

    await tester.pumpWidget(buildFor('perfil-b'));
    await tester.pump();

    expect(find.byKey(const Key('period-comparison-prompt')), findsOneWidget);

    await tester.tap(find.byKey(const Key('period-comparison-compare-button')));
    await tester.pump();

    durations.completeProfile('perfil-b', [
      _duration(
        id: 'sleep-b',
        type: DurationMetricType.sleep,
        day: 12,
        minutes: 420,
        anonymousId: 'perfil-b',
      ),
    ]);
    routines.completeProfile('perfil-b', []);

    await tester.pumpAndSettle();

    expect(find.text('7 h'), findsOneWidget);

    durations.completeProfile('perfil-a', [
      _duration(
        id: 'sleep-a',
        type: DurationMetricType.sleep,
        day: 12,
        minutes: 600,
        anonymousId: 'perfil-a',
      ),
    ]);
    routines.completeProfile('perfil-a', []);

    await tester.pumpAndSettle();

    expect(find.text('7 h'), findsOneWidget);
    expect(find.text('10 h'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
