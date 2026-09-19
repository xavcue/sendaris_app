import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/repositories/behavior_repository.dart';
import 'package:sendaris/features/duration/data/repositories/composite_duration_repository.dart';
import 'package:sendaris/features/duration/domain/exceptions/duration_failure.dart';
import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';
import 'package:sendaris/features/dysregulation/domain/repositories/dysregulation_repository.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';
import 'package:sendaris/features/sleep/domain/repositories/sleep_repository.dart';

void main() {
  late _FakeSleepRepository sleepRepository;

  late _FakeBehaviorRepository behaviorRepository;

  late _FakeDysregulationRepository dysregulationRepository;

  late CompositeDurationRepository repository;

  setUp(() {
    sleepRepository = _FakeSleepRepository();

    behaviorRepository = _FakeBehaviorRepository();

    dysregulationRepository = _FakeDysregulationRepository();

    repository = CompositeDurationRepository(
      sleepRepository: sleepRepository,
      behaviorRepository: behaviorRepository,
      dysregulationRepository: dysregulationRepository,
    );
  });

  test('sueño recupera únicamente su fuente y recalcula la duración desde las horas', () async {
    sleepRepository.records = [
      _sleep(
        id: 'sueno-1',
        startTime: '22:30',
        endTime: '06:30',

        // Intencionalmente distinto:
        // HU13 debe volver a calcular
        // desde las horas fuente.
        durationMinutes: 1,
      ),
    ];

    final observations = await repository.recoverObservations(
      anonymousId: 'perfil-a',
      metricType: DurationMetricType.sleep,
    );

    expect(observations, hasLength(1));

    expect(observations.single.recordId, 'sueno-1');

    expect(observations.single.metricType, DurationMetricType.sleep);

    expect(observations.single.durationMinutes, 480);

    expect(sleepRepository.requestedIds, ['perfil-a']);

    expect(behaviorRepository.requestedIds, isEmpty);

    expect(dysregulationRepository.requestedIds, isEmpty);
  });

  test(
    'un horario de sueño inválido no produce una duración numérica engañosa',
    () async {
      sleepRepository.records = [
        _sleep(
          id: 'sueno-invalido',
          startTime: 'hora-invalida',
          endTime: '06:30',
          durationMinutes: 480,
        ),
      ];

      final observations = await repository.recoverObservations(
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.sleep,
      );

      expect(observations, hasLength(1));

      expect(observations.single.durationMinutes, isNull);
    },
  );

  test(
    'conducta conserva la duración temporal opcional de la fuente',
    () async {
      behaviorRepository.records = [
        _behavior(id: 'conducta-1', durationMinutes: 25),
        _behavior(id: 'conducta-2', durationMinutes: null),
      ];

      final observations = await repository.recoverObservations(
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.behavior,
      );

      expect(observations, hasLength(2));

      expect(observations[0].durationMinutes, 25);

      expect(observations[1].durationMinutes, isNull);

      expect(behaviorRepository.requestedIds, ['perfil-a']);

      expect(sleepRepository.requestedIds, isEmpty);

      expect(dysregulationRepository.requestedIds, isEmpty);
    },
  );

  test('desregulación conserva la duración registrada incluida la duración cero vigente', () async {
    dysregulationRepository.records = [
      _dysregulation(id: 'desregulacion-1', durationMinutes: 0),
      _dysregulation(id: 'desregulacion-2', durationMinutes: 15),
    ];

    final observations = await repository.recoverObservations(
      anonymousId: 'perfil-a',
      metricType: DurationMetricType.dysregulation,
    );

    expect(observations, hasLength(2));

    expect(observations[0].durationMinutes, 0);

    expect(observations[1].durationMinutes, 15);

    expect(dysregulationRepository.requestedIds, ['perfil-a']);

    expect(sleepRepository.requestedIds, isEmpty);

    expect(behaviorRepository.requestedIds, isEmpty);
  });

  test(
    'descarta registros pertenecientes a otro identificador anónimo',
    () async {
      behaviorRepository.records = [
        _behavior(
          id: 'perfil-a-1',
          anonymousId: 'perfil-a',
          durationMinutes: 10,
        ),
        _behavior(
          id: 'perfil-b-1',
          anonymousId: 'perfil-b',
          durationMinutes: 20,
        ),
      ];

      final observations = await repository.recoverObservations(
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.behavior,
      );

      expect(observations, hasLength(1));

      expect(observations.single.recordId, 'perfil-a-1');

      expect(observations.single.anonymousId, 'perfil-a');
    },
  );

  test('una fuente vacía produce una colección vacía sin error', () async {
    final observations = await repository.recoverObservations(
      anonymousId: 'perfil-a',
      metricType: DurationMetricType.sleep,
    );

    expect(observations, isEmpty);
  });

  test('cada recuperación utiliza los registros fuente actuales y no un promedio almacenado', () async {
    behaviorRepository.records = [
      _behavior(id: 'conducta-1', durationMinutes: 10),
    ];

    final first = await repository.recoverObservations(
      anonymousId: 'perfil-a',
      metricType: DurationMetricType.behavior,
    );

    behaviorRepository.records = [
      _behavior(id: 'conducta-1', durationMinutes: 10),
      _behavior(id: 'conducta-2', durationMinutes: 30),
    ];

    final second = await repository.recoverObservations(
      anonymousId: 'perfil-a',
      metricType: DurationMetricType.behavior,
    );

    expect(first, hasLength(1));

    expect(second, hasLength(2));

    expect(behaviorRepository.requestedIds, ['perfil-a', 'perfil-a']);
  });

  test(
    'rechaza un identificador anónimo inválido antes de consultar fuentes',
    () async {
      expect(
        () => repository.recoverObservations(
          anonymousId: 'perfil/invalido',
          metricType: DurationMetricType.sleep,
        ),
        throwsA(isA<DurationFailure>()),
      );

      expect(sleepRepository.requestedIds, isEmpty);

      expect(behaviorRepository.requestedIds, isEmpty);

      expect(dysregulationRepository.requestedIds, isEmpty);
    },
  );

  test('convierte errores de la fuente en un DurationFailure seguro', () async {
    sleepRepository.error = Exception('Internal repository details');

    await expectLater(
      repository.recoverObservations(
        anonymousId: 'perfil-a',
        metricType: DurationMetricType.sleep,
      ),
      throwsA(
        isA<DurationFailure>().having(
          (failure) => failure.message,
          'message',
          'No fue posible recuperar los registros '
              'para calcular las duraciones. '
              'Inténtalo nuevamente.',
        ),
      ),
    );
  });
}

SleepRecord _sleep({
  required String id,
  required String startTime,
  required String endTime,
  required int durationMinutes,
  String anonymousId = 'perfil-a',
}) {
  return SleepRecord(
    recordId: id,
    anonymousId: anonymousId,
    date: DateTime(2026, 9, 10),
    startTime: startTime,
    endTime: endTime,
    durationMinutes: durationMinutes,
    createdAt: DateTime.utc(2026, 9, 10),
    updatedAt: DateTime.utc(2026, 9, 10),
  );
}

BehaviorRecord _behavior({
  required String id,
  required int? durationMinutes,
  String anonymousId = 'perfil-a',
}) {
  return BehaviorRecord(
    recordId: id,
    anonymousId: anonymousId,
    date: DateTime(2026, 9, 10),
    category: BehaviorCategory.repetitiveBehavior,
    durationMinutes: durationMinutes,
    createdAt: DateTime.utc(2026, 9, 10),
    updatedAt: DateTime.utc(2026, 9, 10),
  );
}

DysregulationRecord _dysregulation({
  required String id,
  required int? durationMinutes,
  String anonymousId = 'perfil-a',
}) {
  return DysregulationRecord(
    recordId: id,
    anonymousId: anonymousId,
    date: DateTime(2026, 9, 10),
    durationMinutes: durationMinutes,
    createdAt: DateTime.utc(2026, 9, 10),
    updatedAt: DateTime.utc(2026, 9, 10),
  );
}

class _FakeSleepRepository implements SleepRepository {
  List<SleepRecord> records = [];

  Object? error;

  final List<String> requestedIds = [];

  @override
  Future<List<SleepRecord>> recoverSleepRecords({
    required String anonymousId,
  }) async {
    requestedIds.add(anonymousId);

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(records);
  }

  @override
  Future<void> saveSleep(SleepRecord record) async {}
}

class _FakeBehaviorRepository implements BehaviorRepository {
  List<BehaviorRecord> records = [];

  Object? error;

  final List<String> requestedIds = [];

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    requestedIds.add(anonymousId);

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(records);
  }

  @override
  Future<void> saveBehavior(BehaviorRecord record) async {}
}

class _FakeDysregulationRepository implements DysregulationRepository {
  List<DysregulationRecord> records = [];

  Object? error;

  final List<String> requestedIds = [];

  @override
  Future<List<DysregulationRecord>> recoverDysregulations({
    required String anonymousId,
  }) async {
    requestedIds.add(anonymousId);

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(records);
  }

  @override
  Future<void> saveDysregulation(DysregulationRecord record) async {}
}
