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
import 'package:sendaris/features/home/data/repositories/composite_home_overview_repository.dart';
import 'package:sendaris/features/home/domain/exceptions/home_overview_failure.dart';
import 'package:sendaris/features/home/domain/models/home_activity_area.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';
import 'package:sendaris/features/routine_status/domain/repositories/routine_status_repository.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';
import 'package:sendaris/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_record.dart';
import 'package:sendaris/features/social_interaction/domain/repositories/social_interaction_repository.dart';

void main() {
  late _FakeBehaviorRepository behaviorRepository;

  late _FakeSleepRepository sleepRepository;

  late _FakeFeedingRepository feedingRepository;

  late _FakeSocialInteractionRepository socialInteractionRepository;

  late _FakeDysregulationRepository dysregulationRepository;

  late _FakeAtypicalSituationRepository atypicalSituationRepository;

  late _FakeRoutineStatusRepository routineStatusRepository;

  late CompositeHomeOverviewRepository repository;

  setUp(() {
    behaviorRepository = _FakeBehaviorRepository();

    sleepRepository = _FakeSleepRepository();

    feedingRepository = _FakeFeedingRepository();

    socialInteractionRepository = _FakeSocialInteractionRepository();

    dysregulationRepository = _FakeDysregulationRepository();

    atypicalSituationRepository = _FakeAtypicalSituationRepository();

    routineStatusRepository = _FakeRoutineStatusRepository();

    repository = CompositeHomeOverviewRepository(
      behaviorRepository: behaviorRepository,
      sleepRepository: sleepRepository,
      feedingRepository: feedingRepository,
      socialInteractionRepository: socialInteractionRepository,
      dysregulationRepository: dysregulationRepository,
      atypicalSituationRepository: atypicalSituationRepository,
      routineStatusRepository: routineStatusRepository,
    );
  });

  test('consolida las siete áreas registradas durante el día', () async {
    behaviorRepository.records = [_behavior(id: 'conducta-1')];

    sleepRepository.records = [_sleep(id: 'sueno-1')];

    feedingRepository.records = [_feeding(id: 'alimentacion-1')];

    socialInteractionRepository.records = [_socialInteraction(id: 'social-1')];

    dysregulationRepository.records = [_dysregulation(id: 'desregulacion-1')];

    atypicalSituationRepository.records = [
      _atypicalSituation(id: 'situacion-1'),
    ];

    routineStatusRepository.records = [_routineStatus(id: 'rutina-1')];

    final overview = await repository.recoverDayOverview(
      anonymousId: 'seguimiento-a',
      localDate: DateTime(2026, 10, 12, 18, 30),
    );

    expect(overview.orderedAreas, [
      HomeActivityArea.behavior,
      HomeActivityArea.sleep,
      HomeActivityArea.feeding,
      HomeActivityArea.socialInteraction,
      HomeActivityArea.dysregulation,
      HomeActivityArea.otherSituation,
      HomeActivityArea.routines,
    ]);

    expect(overview.date, DateTime(2026, 10, 12));

    expect(overview.hasActivity, isTrue);

    for (final area in HomeActivityArea.values) {
      expect(overview.countFor(area), 1);
    }

    expect(behaviorRepository.requestedIds, ['seguimiento-a']);

    expect(sleepRepository.requestedIds, ['seguimiento-a']);

    expect(feedingRepository.requestedIds, ['seguimiento-a']);

    expect(socialInteractionRepository.requestedIds, ['seguimiento-a']);

    expect(dysregulationRepository.requestedIds, ['seguimiento-a']);

    expect(atypicalSituationRepository.requestedIds, ['seguimiento-a']);

    expect(routineStatusRepository.requestedIds, ['seguimiento-a']);
  });

  test('varios registros de una misma fuente producen una sola área y conservan su conteo', () async {
    behaviorRepository.records = [
      _behavior(id: 'conducta-1'),
      _behavior(id: 'conducta-2'),
      _behavior(id: 'conducta-3'),
    ];

    final overview = await repository.recoverDayOverview(
      anonymousId: 'seguimiento-a',
      localDate: DateTime(2026, 10, 12),
    );

    expect(overview.orderedAreas, [HomeActivityArea.behavior]);

    expect(overview.areas, hasLength(1));

    expect(overview.countFor(HomeActivityArea.behavior), 3);
  });

  test('cuenta cada área de forma independiente', () async {
    behaviorRepository.records = [
      _behavior(id: 'conducta-1'),
      _behavior(id: 'conducta-2'),
    ];

    sleepRepository.records = [_sleep(id: 'sueno-1')];

    feedingRepository.records = [
      _feeding(id: 'alimentacion-1'),
      _feeding(id: 'alimentacion-2'),
      _feeding(id: 'alimentacion-3'),
    ];

    final overview = await repository.recoverDayOverview(
      anonymousId: 'seguimiento-a',
      localDate: DateTime(2026, 10, 12),
    );

    expect(overview.countFor(HomeActivityArea.behavior), 2);

    expect(overview.countFor(HomeActivityArea.sleep), 1);

    expect(overview.countFor(HomeActivityArea.feeding), 3);

    expect(overview.countFor(HomeActivityArea.socialInteraction), 0);
  });

  test('ignora registros de otras fechas y de otros seguimientos', () async {
    behaviorRepository.records = [
      _behavior(id: 'conducta-anterior', date: DateTime(2026, 10, 11)),
      _behavior(
        id: 'conducta-otro-seguimiento',
        anonymousId: 'seguimiento-b',
        date: DateTime(2026, 10, 12),
      ),
    ];

    sleepRepository.records = [
      _sleep(id: 'sueno-actual', date: DateTime(2026, 10, 12)),
    ];

    final overview = await repository.recoverDayOverview(
      anonymousId: 'seguimiento-a',
      localDate: DateTime(2026, 10, 12, 23, 55),
    );

    expect(overview.orderedAreas, [HomeActivityArea.sleep]);

    expect(overview.contains(HomeActivityArea.behavior), isFalse);

    expect(overview.contains(HomeActivityArea.sleep), isTrue);

    expect(overview.countFor(HomeActivityArea.behavior), 0);

    expect(overview.countFor(HomeActivityArea.sleep), 1);
  });

  test('una fecha con hora se normaliza al día local solicitado', () async {
    feedingRepository.records = [
      _feeding(id: 'alimentacion-1', date: DateTime(2026, 10, 12, 7, 30)),
    ];

    final overview = await repository.recoverDayOverview(
      anonymousId: 'seguimiento-a',
      localDate: DateTime(2026, 10, 12, 21, 45),
    );

    expect(overview.date, DateTime(2026, 10, 12));

    expect(overview.orderedAreas, [HomeActivityArea.feeding]);

    expect(overview.countFor(HomeActivityArea.feeding), 1);
  });

  test('sin registros produce un panorama vacío', () async {
    final overview = await repository.recoverDayOverview(
      anonymousId: 'seguimiento-a',
      localDate: DateTime(2026, 10, 12),
    );

    expect(overview.hasActivity, isFalse);

    expect(overview.isEmpty, isTrue);

    expect(overview.areas, isEmpty);

    expect(overview.orderedAreas, isEmpty);

    expect(overview.recordCounts, isEmpty);
  });

  test(
    'rechaza un identificador inválido antes de consultar las fuentes',
    () async {
      await expectLater(
        repository.recoverDayOverview(
          anonymousId: 'seguimiento/invalido',
          localDate: DateTime(2026, 10, 12),
        ),
        throwsA(
          isA<HomeOverviewFailure>().having(
            (failure) => failure.message,
            'message',
            'El seguimiento seleccionado no es válido.',
          ),
        ),
      );

      expect(behaviorRepository.requestedIds, isEmpty);

      expect(sleepRepository.requestedIds, isEmpty);

      expect(feedingRepository.requestedIds, isEmpty);

      expect(socialInteractionRepository.requestedIds, isEmpty);

      expect(dysregulationRepository.requestedIds, isEmpty);

      expect(atypicalSituationRepository.requestedIds, isEmpty);

      expect(routineStatusRepository.requestedIds, isEmpty);
    },
  );

  test('convierte errores internos en un mensaje seguro de Inicio', () async {
    behaviorRepository.error = Exception(
      'Detalle interno que no debe '
      'mostrarse al usuario.',
    );

    await expectLater(
      repository.recoverDayOverview(
        anonymousId: 'seguimiento-a',
        localDate: DateTime(2026, 10, 12),
      ),
      throwsA(
        isA<HomeOverviewFailure>().having(
          (failure) => failure.message,
          'message',
          'No fue posible actualizar el panorama de hoy. '
              'Inténtalo nuevamente.',
        ),
      ),
    );
  });
}

BehaviorRecord _behavior({
  required String id,
  String anonymousId = 'seguimiento-a',
  DateTime? date,
}) {
  return BehaviorRecord(
    recordId: id,
    anonymousId: anonymousId,
    date: date ?? DateTime(2026, 10, 12),
    category: BehaviorCategory.repetitiveBehavior,
    createdAt: DateTime.utc(2026, 10, 12),
    updatedAt: DateTime.utc(2026, 10, 12),
  );
}

SleepRecord _sleep({
  required String id,
  String anonymousId = 'seguimiento-a',
  DateTime? date,
}) {
  return SleepRecord(
    recordId: id,
    anonymousId: anonymousId,
    date: date ?? DateTime(2026, 10, 12),
    startTime: '21:30',
    endTime: '06:30',
    durationMinutes: 540,
    createdAt: DateTime.utc(2026, 10, 12),
    updatedAt: DateTime.utc(2026, 10, 12),
  );
}

FeedingRecord _feeding({
  required String id,
  String anonymousId = 'seguimiento-a',
  DateTime? date,
}) {
  return FeedingRecord(
    recordId: id,
    anonymousId: anonymousId,
    date: date ?? DateTime(2026, 10, 12),
    category: FeedingCategory.lunch,
    createdAt: DateTime.utc(2026, 10, 12),
    updatedAt: DateTime.utc(2026, 10, 12),
  );
}

SocialInteractionRecord _socialInteraction({
  required String id,
  String anonymousId = 'seguimiento-a',
  DateTime? date,
}) {
  return SocialInteractionRecord(
    recordId: id,
    anonymousId: anonymousId,
    date: date ?? DateTime(2026, 10, 12),
    category: SocialInteractionCategory.sharedActivity,
    createdAt: DateTime.utc(2026, 10, 12),
    updatedAt: DateTime.utc(2026, 10, 12),
  );
}

DysregulationRecord _dysregulation({
  required String id,
  String anonymousId = 'seguimiento-a',
  DateTime? date,
}) {
  return DysregulationRecord(
    recordId: id,
    anonymousId: anonymousId,
    date: date ?? DateTime(2026, 10, 12),
    createdAt: DateTime.utc(2026, 10, 12),
    updatedAt: DateTime.utc(2026, 10, 12),
  );
}

AtypicalSituationRecord _atypicalSituation({
  required String id,
  String anonymousId = 'seguimiento-a',
  DateTime? date,
}) {
  return AtypicalSituationRecord(
    recordId: id,
    anonymousId: anonymousId,
    date: date ?? DateTime(2026, 10, 12),
    category: AtypicalSituationCategory.unexpectedEvent,
    observation: 'Situación ficticia para pruebas.',
    createdAt: DateTime.utc(2026, 10, 12),
    updatedAt: DateTime.utc(2026, 10, 12),
  );
}

RoutineStatusRecord _routineStatus({
  required String id,
  String anonymousId = 'seguimiento-a',
  DateTime? date,
}) {
  return RoutineStatusRecord(
    recordId: id,
    anonymousId: anonymousId,
    routineId: 'rutina-ficticia',
    date: date ?? DateTime(2026, 10, 12),
    status: RoutineStatus.completed,
    createdAt: DateTime.utc(2026, 10, 12),
    updatedAt: DateTime.utc(2026, 10, 12),
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

    return List<BehaviorRecord>.unmodifiable(records);
  }

  @override
  Future<void> saveBehavior(BehaviorRecord record) async {}
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

    if (error != null) {
      throw error!;
    }

    return List<SleepRecord>.unmodifiable(records);
  }

  @override
  Future<void> saveSleep(SleepRecord record) async {}
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

    return List<FeedingRecord>.unmodifiable(records);
  }

  @override
  Future<void> saveFeeding(FeedingRecord record) async {}
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

    return List<SocialInteractionRecord>.unmodifiable(records);
  }

  @override
  Future<void> saveSocialInteraction(SocialInteractionRecord record) async {}
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

    return List<DysregulationRecord>.unmodifiable(records);
  }

  @override
  Future<void> saveDysregulation(DysregulationRecord record) async {}
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

    return List<AtypicalSituationRecord>.unmodifiable(records);
  }

  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {}
}

class _FakeRoutineStatusRepository implements RoutineStatusRepository {
  List<RoutineStatusRecord> records = [];

  Object? error;

  final List<String> requestedIds = [];

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    requestedIds.add(anonymousId);

    if (error != null) {
      throw error!;
    }

    return List<RoutineStatusRecord>.unmodifiable(records);
  }

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {}
}
