import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/period_comparison/domain/models/comparison_period.dart';
import 'package:sendaris/features/period_comparison/domain/services/period_comparison_service.dart';
import 'package:sendaris/features/period_comparison/presentation/viewmodels/period_comparison_view_model.dart';
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

    return observations.where((item) => item.metricType == metricType).toList();
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
  final Map<DurationMetricType, List<Completer<List<DurationObservation>>>>
  pending = {
    for (final type in DurationMetricType.values)
      type: <Completer<List<DurationObservation>>>[],
  };

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) {
    final completer = Completer<List<DurationObservation>>();
    pending[metricType]!.add(completer);
    return completer.future;
  }

  // Cada comparacion realiza dos consultas por tipo:
  // una para A y otra para B.
  void completeRound(
    int round, {
    List<DurationObservation> observations = const [],
  }) {
    for (final type in DurationMetricType.values) {
      final matching = observations
          .where((item) => item.metricType == type)
          .toList();

      for (var index = round * 2; index < round * 2 + 2; index++) {
        pending[type]![index].complete(matching);
      }
    }
  }
}

class _DeferredRoutineRepository implements RoutineComplianceRepository {
  final List<Completer<List<RoutineComplianceEntry>>> pending = [];

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) {
    final completer = Completer<List<RoutineComplianceEntry>>();
    pending.add(completer);
    return completer.future;
  }

  void completeRound(
    int round, {
    List<RoutineComplianceEntry> entries = const [],
  }) {
    for (var index = round * 2; index < round * 2 + 2; index++) {
      pending[index].complete(List<RoutineComplianceEntry>.of(entries));
    }
  }
}

DurationObservation _observation({
  required String id,
  required DurationMetricType type,
  required int day,
  required int? minutes,
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
    routineId: 'rutina-1',
    date: DateTime(2026, 10, day),
    status: status,
  );
}

PeriodComparisonViewModel _createViewModel(
  DurationRepository durationRepository,
  RoutineComplianceRepository routineRepository, {
  String anonymousId = 'perfil-a',
}) {
  return PeriodComparisonViewModel(
    PeriodComparisonService(
      durationRepository: durationRepository,
      routineComplianceRepository: routineRepository,
    ),
    anonymousId: anonymousId,
    clock: () => DateTime(2026, 10, 15, 14, 30),
  );
}

void main() {
  group('HU-20 - PeriodComparisonViewModel', () {
    test('inicializa dos periodos consecutivos de siete dias', () {
      final durations = _FakeDurationRepository();
      final routines = _FakeRoutineRepository();

      final viewModel = _createViewModel(durations, routines);
      addTearDown(viewModel.dispose);

      expect(viewModel.periodA.startDate, DateTime(2026, 10, 2));
      expect(viewModel.periodA.endDate, DateTime(2026, 10, 8));

      expect(viewModel.periodB.startDate, DateTime(2026, 10, 9));
      expect(viewModel.periodB.endDate, DateTime(2026, 10, 15));

      expect(viewModel.result, isNull);
      expect(viewModel.hasComparison, isFalse);
      expect(viewModel.hasData, isFalse);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);

      expect(durations.requests, isEmpty);
      expect(routines.requests, isEmpty);
    });

    test('carga valores A/B utilizando el servicio original', () async {
      final durations = _FakeDurationRepository(
        observations: [
          _observation(
            id: 'sleep-a1',
            type: DurationMetricType.sleep,
            day: 2,
            minutes: 480,
          ),
          _observation(
            id: 'sleep-a2',
            type: DurationMetricType.sleep,
            day: 8,
            minutes: 600,
          ),
          _observation(
            id: 'sleep-b',
            type: DurationMetricType.sleep,
            day: 15,
            minutes: 360,
          ),
          _observation(
            id: 'behavior-a',
            type: DurationMetricType.behavior,
            day: 5,
            minutes: 12,
          ),
          _observation(
            id: 'dysregulation-a',
            type: DurationMetricType.dysregulation,
            day: 3,
            minutes: 0,
          ),
          _observation(
            id: 'otro-seguimiento',
            type: DurationMetricType.sleep,
            day: 15,
            minutes: 900,
            anonymousId: 'perfil-b',
          ),
        ],
      );

      final routines = _FakeRoutineRepository(
        entries: [
          _routine(id: 'completed-a', day: 2, status: RoutineStatus.completed),
          _routine(id: 'modified-a', day: 8, status: RoutineStatus.modified),
          _routine(id: 'modified-b', day: 15, status: RoutineStatus.modified),
          _routine(
            id: 'otro-seguimiento',
            day: 15,
            status: RoutineStatus.completed,
            anonymousId: 'perfil-b',
          ),
        ],
      );

      final viewModel = _createViewModel(durations, routines);
      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.hasComparison, isTrue);
      expect(viewModel.hasData, isTrue);

      final result = viewModel.result!;

      expect(result.anonymousId, 'perfil-a');

      expect(result.periodA.averageMinutesFor(DurationMetricType.sleep), 540);
      expect(result.periodB.averageMinutesFor(DurationMetricType.sleep), 360);

      expect(result.periodA.averageMinutesFor(DurationMetricType.behavior), 12);
      expect(
        result.periodB.averageMinutesFor(DurationMetricType.behavior),
        isNull,
      );

      expect(
        result.periodA.averageMinutesFor(DurationMetricType.dysregulation),
        0,
      );

      expect(result.periodA.routineCompliancePercentage, 50);
      expect(result.periodB.routineCompliancePercentage, 0);

      expect(durations.requests, hasLength(6));
      expect(routines.requests, ['perfil-a', 'perfil-a']);

      expect(
        durations.requests.every((request) => request.startsWith('perfil-a:')),
        isTrue,
      );
    });

    test('distingue sin datos de cumplimiento cero', () async {
      final viewModel = _createViewModel(
        _FakeDurationRepository(),
        _FakeRoutineRepository(
          entries: [
            _routine(id: 'modified-b', day: 12, status: RoutineStatus.modified),
          ],
        ),
      );

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.result, isNotNull);
      expect(viewModel.result!.periodA.routineCompliancePercentage, isNull);
      expect(viewModel.result!.periodB.routineCompliancePercentage, 0);

      for (final type in DurationMetricType.values) {
        expect(viewModel.result!.periodA.averageMinutesFor(type), isNull);
      }
    });

    test('ambos periodos sin datos mantienen resultado descriptivo', () async {
      final viewModel = _createViewModel(
        _FakeDurationRepository(),
        _FakeRoutineRepository(),
      );

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.hasComparison, isTrue);
      expect(viewModel.hasData, isFalse);
      expect(viewModel.errorMessage, isNull);

      expect(viewModel.result!.periodA.routineCompliancePercentage, isNull);
      expect(viewModel.result!.periodB.routineCompliancePercentage, isNull);
    });

    test('edita cada periodo y no consulta hasta comparar', () async {
      final durations = _FakeDurationRepository();
      final routines = _FakeRoutineRepository();

      final viewModel = _createViewModel(durations, routines);
      addTearDown(viewModel.dispose);

      await viewModel.load();
      expect(viewModel.hasComparison, isTrue);

      viewModel.setDate(
        slot: ComparisonPeriodSlot.a,
        isStartDate: true,
        date: DateTime(2026, 10, 12, 23),
      );

      expect(viewModel.periodA.startDate, DateTime(2026, 10, 12));
      expect(viewModel.periodA.endDate, DateTime(2026, 10, 12));

      expect(viewModel.periodB.startDate, DateTime(2026, 10, 9));
      expect(viewModel.periodB.endDate, DateTime(2026, 10, 15));

      expect(viewModel.hasComparison, isFalse);
      expect(viewModel.errorMessage, isNull);

      viewModel.setDate(
        slot: ComparisonPeriodSlot.a,
        isStartDate: false,
        date: DateTime(2026, 10, 14, 8),
      );

      expect(viewModel.periodA.startDate, DateTime(2026, 10, 12));
      expect(viewModel.periodA.endDate, DateTime(2026, 10, 14));

      // Modificar fechas no genera consultas adicionales.
      expect(durations.requests, hasLength(6));
      expect(routines.requests, hasLength(2));
    });

    test('seleccionar el mismo periodo conserva los resultados', () async {
      final viewModel = _createViewModel(
        _FakeDurationRepository(),
        _FakeRoutineRepository(),
      );

      addTearDown(viewModel.dispose);

      await viewModel.load();

      final previousResult = viewModel.result;

      viewModel.setPeriod(
        slot: ComparisonPeriodSlot.a,
        period: ComparisonPeriod(
          startDate: DateTime(2026, 10, 2),
          endDate: DateTime(2026, 10, 8),
        ),
      );

      expect(identical(viewModel.result, previousResult), isTrue);
      expect(viewModel.hasComparison, isTrue);
    });

    test('rechaza seguimiento invalido sin recuperar registros', () async {
      final durations = _FakeDurationRepository();
      final routines = _FakeRoutineRepository();

      final viewModel = _createViewModel(
        durations,
        routines,
        anonymousId: 'perfil/incorrecto',
      );

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.result, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNotNull);

      expect(durations.requests, isEmpty);
      expect(routines.requests, isEmpty);
    });

    test('presenta errores controlados sin fabricar resultados', () async {
      const failureMessage = 'No fue posible recuperar los estados.';

      final viewModel = _createViewModel(
        _FakeDurationRepository(),
        _FakeRoutineRepository(
          failure: const RoutineComplianceFailure(failureMessage),
        ),
      );

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.result, isNull);
      expect(viewModel.hasComparison, isFalse);
      expect(viewModel.errorMessage, failureMessage);
    });

    test('una consulta nueva prevalece sobre una anterior', () async {
      final durations = _DeferredDurationRepository();
      final routines = _DeferredRoutineRepository();

      final viewModel = _createViewModel(durations, routines);
      addTearDown(viewModel.dispose);

      final firstRequest = viewModel.load();
      final secondRequest = viewModel.load();

      durations.completeRound(
        1,
        observations: [
          _observation(
            id: 'nuevo-a',
            type: DurationMetricType.sleep,
            day: 4,
            minutes: 480,
          ),
          _observation(
            id: 'nuevo-b',
            type: DurationMetricType.sleep,
            day: 12,
            minutes: 600,
          ),
        ],
      );
      routines.completeRound(1);

      await secondRequest;

      expect(viewModel.result, isNotNull);
      expect(
        viewModel.result!.periodB.averageMinutesFor(DurationMetricType.sleep),
        600,
      );

      durations.completeRound(
        0,
        observations: [
          _observation(
            id: 'antiguo-b',
            type: DurationMetricType.sleep,
            day: 12,
            minutes: 300,
          ),
        ],
      );
      routines.completeRound(0);

      await firstRequest;

      expect(
        viewModel.result!.periodB.averageMinutesFor(DurationMetricType.sleep),
        600,
      );
      expect(viewModel.isLoading, isFalse);
    });

    test('cambiar fechas invalida una consulta pendiente', () async {
      final durations = _DeferredDurationRepository();
      final routines = _DeferredRoutineRepository();

      final viewModel = _createViewModel(durations, routines);
      addTearDown(viewModel.dispose);

      final pendingRequest = viewModel.load();

      expect(viewModel.isLoading, isTrue);

      viewModel.setDate(
        slot: ComparisonPeriodSlot.b,
        isStartDate: false,
        date: DateTime(2026, 10, 14),
      );

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.result, isNull);

      durations.completeRound(0);
      routines.completeRound(0);

      await pendingRequest;

      expect(viewModel.result, isNull);
      expect(viewModel.hasComparison, isFalse);
      expect(viewModel.periodB.endDate, DateTime(2026, 10, 14));
    });

    test('ignora respuestas que llegan despues de dispose', () async {
      final durations = _DeferredDurationRepository();
      final routines = _DeferredRoutineRepository();

      final viewModel = _createViewModel(durations, routines);

      final pendingRequest = viewModel.load();

      expect(viewModel.isLoading, isTrue);

      viewModel.dispose();

      durations.completeRound(0);
      routines.completeRound(0);

      await pendingRequest;

      expect(viewModel.isDisposed, isTrue);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.result, isNull);
    });
  });
}
