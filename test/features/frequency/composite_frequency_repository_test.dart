import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';
import 'package:sendaris/features/atypical_situation/domain/repositories/atypical_situation_repository.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/repositories/behavior_repository.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';
import 'package:sendaris/features/dysregulation/domain/repositories/dysregulation_repository.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_record.dart';
import 'package:sendaris/features/feeding/domain/repositories/feeding_repository.dart';
import 'package:sendaris/features/frequency/data/repositories/composite_frequency_repository.dart';
import 'package:sendaris/features/frequency/domain/exceptions/frequency_failure.dart';
import 'package:sendaris/features/frequency/domain/models/frequency_metric_type.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_record.dart';
import 'package:sendaris/features/social_interaction/domain/repositories/social_interaction_repository.dart';

void main() {
  late _FakeBehaviorRepository behaviorRepository;

  late _FakeDysregulationRepository dysregulationRepository;

  late _FakeSocialInteractionRepository socialInteractionRepository;

  late _FakeFeedingRepository feedingRepository;

  late _FakeAtypicalSituationRepository atypicalSituationRepository;

  late CompositeFrequencyRepository repository;

  setUp(() {
    behaviorRepository = _FakeBehaviorRepository();

    dysregulationRepository = _FakeDysregulationRepository();

    socialInteractionRepository = _FakeSocialInteractionRepository();

    feedingRepository = _FakeFeedingRepository();

    atypicalSituationRepository = _FakeAtypicalSituationRepository();

    repository = CompositeFrequencyRepository(
      behaviorRepository: behaviorRepository,
      dysregulationRepository: dysregulationRepository,
      socialInteractionRepository: socialInteractionRepository,
      feedingRepository: feedingRepository,
      atypicalSituationRepository: atypicalSituationRepository,
    );
  });

  test('conducta recupera únicamente la fuente de conducta y conserva su categoría', () async {
    behaviorRepository.records = [
      _behavior(
        id: 'conducta-1',
        category: BehaviorCategory.repetitiveBehavior,
      ),
    ];

    final events = await repository.recoverEvents(
      anonymousId: 'perfil-a',
      metricType: FrequencyMetricType.behavior,
    );

    expect(events, hasLength(1));

    expect(events.single.recordId, 'conducta-1');

    expect(events.single.metricType, FrequencyMetricType.behavior);

    expect(events.single.categoryCode, 'conducta_repetitiva');

    expect(behaviorRepository.requestedIds, ['perfil-a']);

    expect(dysregulationRepository.requestedIds, isEmpty);

    expect(socialInteractionRepository.requestedIds, isEmpty);

    expect(feedingRepository.requestedIds, isEmpty);

    expect(atypicalSituationRepository.requestedIds, isEmpty);
  });

  test('desregulación recupera episodios sin categoría', () async {
    dysregulationRepository.records = [_dysregulation(id: 'desregulacion-1')];

    final events = await repository.recoverEvents(
      anonymousId: 'perfil-a',
      metricType: FrequencyMetricType.dysregulation,
    );

    expect(events, hasLength(1));

    expect(events.single.metricType, FrequencyMetricType.dysregulation);

    expect(events.single.categoryCode, isNull);

    expect(dysregulationRepository.requestedIds, ['perfil-a']);
  });

  test('interacción social conserva la categoría fuente', () async {
    socialInteractionRepository.records = [
      _socialInteraction(
        id: 'social-1',
        category: SocialInteractionCategory.sharedActivity,
      ),
    ];

    final events = await repository.recoverEvents(
      anonymousId: 'perfil-a',
      metricType: FrequencyMetricType.socialInteraction,
    );

    expect(events.single.categoryCode, 'actividad_compartida');

    expect(socialInteractionRepository.requestedIds, ['perfil-a']);
  });

  test('alimentación conserva la categoría fuente', () async {
    feedingRepository.records = [
      _feeding(id: 'alimentacion-1', category: FeedingCategory.lunch),
    ];

    final events = await repository.recoverEvents(
      anonymousId: 'perfil-a',
      metricType: FrequencyMetricType.feeding,
    );

    expect(events.single.categoryCode, 'almuerzo');

    expect(feedingRepository.requestedIds, ['perfil-a']);
  });

  test('situación atípica conserva la categoría fuente', () async {
    atypicalSituationRepository.records = [
      _atypicalSituation(
        id: 'situacion-1',
        category: AtypicalSituationCategory.unexpectedEvent,
      ),
    ];

    final events = await repository.recoverEvents(
      anonymousId: 'perfil-a',
      metricType: FrequencyMetricType.atypicalSituation,
    );

    expect(events.single.categoryCode, 'evento_inesperado');

    expect(atypicalSituationRepository.requestedIds, ['perfil-a']);
  });

  test(
    'descarta registros pertenecientes a otro identificador anónimo',
    () async {
      behaviorRepository.records = [
        _behavior(
          id: 'perfil-a-1',
          anonymousId: 'perfil-a',
          category: BehaviorCategory.repetitiveBehavior,
        ),
        _behavior(
          id: 'perfil-b-1',
          anonymousId: 'perfil-b',
          category: BehaviorCategory.repetitiveBehavior,
        ),
      ];

      final events = await repository.recoverEvents(
        anonymousId: 'perfil-a',
        metricType: FrequencyMetricType.behavior,
      );

      expect(events, hasLength(1));

      expect(events.single.recordId, 'perfil-a-1');

      expect(events.single.anonymousId, 'perfil-a');
    },
  );

  test('una fuente vacía produce una colección vacía sin error', () async {
    final events = await repository.recoverEvents(
      anonymousId: 'perfil-a',
      metricType: FrequencyMetricType.feeding,
    );

    expect(events, isEmpty);
  });

  test('cada recuperación utiliza los registros fuente actuales y no un valor en caché', () async {
    behaviorRepository.records = [
      _behavior(
        id: 'conducta-1',
        category: BehaviorCategory.repetitiveBehavior,
      ),
    ];

    final first = await repository.recoverEvents(
      anonymousId: 'perfil-a',
      metricType: FrequencyMetricType.behavior,
    );

    behaviorRepository.records = [
      _behavior(
        id: 'conducta-1',
        category: BehaviorCategory.repetitiveBehavior,
      ),
      _behavior(
        id: 'conducta-2',
        category: BehaviorCategory.repetitiveBehavior,
      ),
    ];

    final second = await repository.recoverEvents(
      anonymousId: 'perfil-a',
      metricType: FrequencyMetricType.behavior,
    );

    expect(first, hasLength(1));

    expect(second, hasLength(2));

    expect(behaviorRepository.requestedIds, ['perfil-a', 'perfil-a']);
  });

  test(
    'rechaza un identificador anónimo inválido antes de consultar fuentes',
    () async {
      expect(
        () => repository.recoverEvents(
          anonymousId: 'perfil/invalido',
          metricType: FrequencyMetricType.behavior,
        ),
        throwsA(isA<FrequencyFailure>()),
      );

      expect(behaviorRepository.requestedIds, isEmpty);
    },
  );

  test(
    'convierte errores de la fuente en un FrequencyFailure seguro',
    () async {
      behaviorRepository.error = Exception('Internal repository details');

      await expectLater(
        repository.recoverEvents(
          anonymousId: 'perfil-a',
          metricType: FrequencyMetricType.behavior,
        ),
        throwsA(
          isA<FrequencyFailure>().having(
            (failure) => failure.message,
            'message',
            'No fue posible recuperar los registros '
                'para calcular la frecuencia. '
                'Inténtalo nuevamente.',
          ),
        ),
      );
    },
  );
}

BehaviorRecord _behavior({
  required String id,
  required BehaviorCategory category,
  String anonymousId = 'perfil-a',
}) {
  return BehaviorRecord(
    recordId: id,
    anonymousId: anonymousId,
    date: DateTime(2026, 9, 10),
    category: category,
    createdAt: DateTime.utc(2026, 9, 10),
    updatedAt: DateTime.utc(2026, 9, 10),
  );
}

DysregulationRecord _dysregulation({
  required String id,
  String anonymousId = 'perfil-a',
}) {
  return DysregulationRecord(
    recordId: id,
    anonymousId: anonymousId,
    date: DateTime(2026, 9, 10),
    createdAt: DateTime.utc(2026, 9, 10),
    updatedAt: DateTime.utc(2026, 9, 10),
  );
}

SocialInteractionRecord _socialInteraction({
  required String id,
  required SocialInteractionCategory category,
  String anonymousId = 'perfil-a',
}) {
  return SocialInteractionRecord(
    recordId: id,
    anonymousId: anonymousId,
    date: DateTime(2026, 9, 10),
    category: category,
    createdAt: DateTime.utc(2026, 9, 10),
    updatedAt: DateTime.utc(2026, 9, 10),
  );
}

FeedingRecord _feeding({
  required String id,
  required FeedingCategory category,
  String anonymousId = 'perfil-a',
}) {
  return FeedingRecord(
    recordId: id,
    anonymousId: anonymousId,
    date: DateTime(2026, 9, 10),
    category: category,
    createdAt: DateTime.utc(2026, 9, 10),
    updatedAt: DateTime.utc(2026, 9, 10),
  );
}

AtypicalSituationRecord _atypicalSituation({
  required String id,
  required AtypicalSituationCategory category,
  String anonymousId = 'perfil-a',
}) {
  return AtypicalSituationRecord(
    recordId: id,
    anonymousId: anonymousId,
    date: DateTime(2026, 9, 10),
    category: category,
    observation: 'Situación ficticia para pruebas.',
    createdAt: DateTime.utc(2026, 9, 10),
    updatedAt: DateTime.utc(2026, 9, 10),
  );
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

    if (error != null) {
      throw error!;
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

    if (error != null) {
      throw error!;
    }

    return List.unmodifiable(records);
  }

  @override
  Future<void> saveDysregulation(DysregulationRecord record) async {}
}

class _FakeSocialInteractionRepository implements SocialInteractionRepository {
  List<SocialInteractionRecord> records = [];

  Object? error;

  final List<String> requestedIds = [];

  @override
  Future<List<SocialInteractionRecord>> recoverSocialInteractions({
    required String anonymousId,
  }) async {
    requestedIds.add(anonymousId);

    if (error != null) {
      throw error!;
    }

    return List.unmodifiable(records);
  }

  @override
  Future<void> saveSocialInteraction(SocialInteractionRecord record) async {}
}

class _FakeFeedingRepository implements FeedingRepository {
  List<FeedingRecord> records = [];

  Object? error;

  final List<String> requestedIds = [];

  @override
  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  }) async {
    requestedIds.add(anonymousId);

    if (error != null) {
      throw error!;
    }

    return List.unmodifiable(records);
  }

  @override
  Future<void> saveFeeding(FeedingRecord record) async {}
}

class _FakeAtypicalSituationRepository implements AtypicalSituationRepository {
  List<AtypicalSituationRecord> records = [];

  Object? error;

  final List<String> requestedIds = [];

  @override
  Future<List<AtypicalSituationRecord>> recoverAtypicalSituations({
    required String anonymousId,
  }) async {
    requestedIds.add(anonymousId);

    if (error != null) {
      throw error!;
    }

    return List.unmodifiable(records);
  }

  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {}
}
