import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/app.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';
import 'package:sendaris/features/atypical_situation/domain/repositories/atypical_situation_repository.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_id_generator.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/repositories/behavior_repository.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_factory.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_id_generator.dart';
import 'package:sendaris/features/duration/data/repositories/composite_duration_repository.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';
import 'package:sendaris/features/dysregulation/domain/repositories/dysregulation_repository.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_factory.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_id_generator.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_record.dart';
import 'package:sendaris/features/feeding/domain/repositories/feeding_repository.dart';
import 'package:sendaris/features/feeding/domain/services/feeding_record_factory.dart';
import 'package:sendaris/features/feeding/domain/services/feeding_record_id_generator.dart';
import 'package:sendaris/features/frequency/data/repositories/composite_frequency_repository.dart';
import 'package:sendaris/features/history/domain/models/history_record.dart';
import 'package:sendaris/features/history/domain/repositories/history_repository.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine/domain/services/routine_factory.dart';
import 'package:sendaris/features/routine/domain/services/routine_id_generator.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';
import 'package:sendaris/features/routine_status/domain/repositories/routine_status_repository.dart';
import 'package:sendaris/features/routine_status/domain/services/routine_status_record_factory.dart';
import 'package:sendaris/features/routine_status/domain/services/routine_status_record_id_generator.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';
import 'package:sendaris/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:sendaris/features/sleep/domain/services/sleep_record_factory.dart';
import 'package:sendaris/features/sleep/domain/services/sleep_record_id_generator.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_record.dart';
import 'package:sendaris/features/social_interaction/domain/repositories/social_interaction_repository.dart';
import 'package:sendaris/features/social_interaction/domain/services/social_interaction_record_factory.dart';
import 'package:sendaris/features/social_interaction/domain/services/social_interaction_record_id_generator.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/repositories/tracking_repository.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_id_generator.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';

void main() {
  testWidgets('un usuario sin sesión es dirigido a la pantalla de acceso', (
    tester,
  ) async {
    final authRepository = FakeAuthRepository();

    final trackingRepository = FakeTrackingRepository();

    final profileFactory = AnonymousTrackingProfileFactory(
      FakeAnonymousIdGenerator(),
    );

    final behaviorRepository = FakeBehaviorRepository();

    const behaviorRecordFactory = BehaviorRecordFactory(
      FakeBehaviorRecordIdGenerator(),
    );

    final sleepRepository = FakeSleepRepository();

    const sleepRecordFactory = SleepRecordFactory(FakeSleepRecordIdGenerator());

    final feedingRepository = FakeFeedingRepository();

    const feedingRecordFactory = FeedingRecordFactory(
      FakeFeedingRecordIdGenerator(),
    );

    final socialInteractionRepository = FakeSocialInteractionRepository();

    const socialInteractionRecordFactory = SocialInteractionRecordFactory(
      FakeSocialInteractionRecordIdGenerator(),
    );

    final dysregulationRepository = FakeDysregulationRepository();

    const dysregulationRecordFactory = DysregulationRecordFactory(
      FakeDysregulationRecordIdGenerator(),
    );

    final historyRepository = FakeHistoryRepository();

    final routineRepository = FakeRoutineRepository();

    const routineFactory = RoutineFactory(FakeRoutineIdGenerator());

    final routineStatusRepository = FakeRoutineStatusRepository();

    const routineStatusRecordFactory = RoutineStatusRecordFactory(
      FakeRoutineStatusRecordIdGenerator(),
    );

    final atypicalSituationRepository = FakeAtypicalSituationRepository();

    const atypicalSituationRecordFactory = AtypicalSituationRecordFactory(
      FakeAtypicalSituationRecordIdGenerator(),
    );

    final frequencyRepository = CompositeFrequencyRepository(
      behaviorRepository: behaviorRepository,
      dysregulationRepository: dysregulationRepository,
      socialInteractionRepository: socialInteractionRepository,
      feedingRepository: feedingRepository,
      atypicalSituationRepository: atypicalSituationRepository,
    );

    final durationRepository = CompositeDurationRepository(
      sleepRepository: sleepRepository,
      behaviorRepository: behaviorRepository,
      dysregulationRepository: dysregulationRepository,
    );

    await tester.pumpWidget(
      SendarisApp(
        authRepository: authRepository,
        trackingRepository: trackingRepository,
        trackingProfileFactory: profileFactory,
        behaviorRepository: behaviorRepository,
        behaviorRecordFactory: behaviorRecordFactory,
        sleepRepository: sleepRepository,
        sleepRecordFactory: sleepRecordFactory,
        feedingRepository: feedingRepository,
        feedingRecordFactory: feedingRecordFactory,
        socialInteractionRepository: socialInteractionRepository,
        socialInteractionRecordFactory: socialInteractionRecordFactory,
        dysregulationRepository: dysregulationRepository,
        dysregulationRecordFactory: dysregulationRecordFactory,
        historyRepository: historyRepository,
        frequencyRepository: frequencyRepository,
        durationRepository: durationRepository,
        routineRepository: routineRepository,
        routineFactory: routineFactory,
        routineStatusRepository: routineStatusRepository,
        routineStatusRecordFactory: routineStatusRecordFactory,
        atypicalSituationRepository: atypicalSituationRepository,
        atypicalSituationRecordFactory: atypicalSituationRecordFactory,
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sendaris'), findsOneWidget);

    expect(
      find.text('Organiza registros y rutinas en un solo lugar.'),
      findsOneWidget,
    );

    expect(find.text('Accede a tu cuenta'), findsOneWidget);

    expect(find.text('Iniciar sesión'), findsOneWidget);

    expect(find.text('Acceso seguro'), findsNothing);

    expect(find.text('Resumen de hoy'), findsNothing);

    expect(find.text('Acciones rápidas'), findsNothing);

    await authRepository.dispose();
  });
}

class FakeAuthRepository implements AuthRepository {
  final StreamController<bool> _controller = StreamController<bool>.broadcast(
    sync: true,
  );

  @override
  bool get isAuthenticated => false;

  @override
  Stream<bool> get authStateChanges => _controller.stream;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}

  Future<void> dispose() {
    return _controller.close();
  }
}

class FakeTrackingRepository implements TrackingRepository {
  @override
  Future<void> persistProfile(AnonymousTrackingProfile profile) async {}

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    return [];
  }
}

class FakeBehaviorRepository implements BehaviorRepository {
  @override
  Future<void> saveBehavior(BehaviorRecord record) async {}

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    return [];
  }
}

class FakeSleepRepository implements SleepRepository {
  @override
  Future<void> saveSleep(SleepRecord record) async {}

  @override
  Future<List<SleepRecord>> recoverSleepRecords({
    required String anonymousId,
  }) async {
    return [];
  }
}

class FakeFeedingRepository implements FeedingRepository {
  @override
  Future<void> saveFeeding(FeedingRecord record) async {}

  @override
  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  }) async {
    return [];
  }
}

class FakeSocialInteractionRepository implements SocialInteractionRepository {
  @override
  Future<void> saveSocialInteraction(SocialInteractionRecord record) async {}

  @override
  Future<List<SocialInteractionRecord>> recoverSocialInteractions({
    required String anonymousId,
  }) async {
    return [];
  }
}

class FakeDysregulationRepository implements DysregulationRepository {
  @override
  Future<void> saveDysregulation(DysregulationRecord record) async {}

  @override
  Future<List<DysregulationRecord>> recoverDysregulations({
    required String anonymousId,
  }) async {
    return [];
  }
}

class FakeHistoryRepository implements HistoryRepository {
  @override
  Future<List<HistoryRecord>> recoverHistory({
    required String anonymousId,
  }) async {
    return [];
  }
}

class FakeRoutineRepository implements RoutineRepository {
  @override
  Future<void> createRoutine(Routine routine) async {}

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    return [];
  }

  @override
  Future<void> updateRoutine(Routine routine) async {}

  @override
  Future<void> deactivateRoutine({
    required String anonymousId,
    required String routineId,
  }) async {}
}

class FakeRoutineStatusRepository implements RoutineStatusRepository {
  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {}

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    return [];
  }
}

class FakeAtypicalSituationRepository implements AtypicalSituationRepository {
  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {}

  @override
  Future<List<AtypicalSituationRecord>> recoverAtypicalSituations({
    required String anonymousId,
  }) async {
    return [];
  }
}

class FakeAnonymousIdGenerator implements AnonymousIdGenerator {
  @override
  String generate() {
    return '550e8400-e29b-41d4-a716-446655440000';
  }
}

class FakeBehaviorRecordIdGenerator implements BehaviorRecordIdGenerator {
  const FakeBehaviorRecordIdGenerator();

  @override
  String generate() {
    return 'registro-widget-test';
  }
}

class FakeSleepRecordIdGenerator implements SleepRecordIdGenerator {
  const FakeSleepRecordIdGenerator();

  @override
  String generate() {
    return 'registro-sueno-widget-test';
  }
}

class FakeFeedingRecordIdGenerator implements FeedingRecordIdGenerator {
  const FakeFeedingRecordIdGenerator();

  @override
  String generate() {
    return 'registro-alimentacion-widget-test';
  }
}

class FakeSocialInteractionRecordIdGenerator
    implements SocialInteractionRecordIdGenerator {
  const FakeSocialInteractionRecordIdGenerator();

  @override
  String generate() {
    return 'registro-interaccion-social-widget-test';
  }
}

class FakeDysregulationRecordIdGenerator
    implements DysregulationRecordIdGenerator {
  const FakeDysregulationRecordIdGenerator();

  @override
  String generate() {
    return 'registro-desregulacion-widget-test';
  }
}

class FakeRoutineIdGenerator implements RoutineIdGenerator {
  const FakeRoutineIdGenerator();

  @override
  String generate() {
    return 'rutina-widget-test';
  }
}

class FakeRoutineStatusRecordIdGenerator
    implements RoutineStatusRecordIdGenerator {
  const FakeRoutineStatusRecordIdGenerator();

  @override
  String generate() {
    return 'estado-rutina-widget-test';
  }
}

class FakeAtypicalSituationRecordIdGenerator
    implements AtypicalSituationRecordIdGenerator {
  const FakeAtypicalSituationRecordIdGenerator();

  @override
  String generate() {
    return 'situacion-widget-test';
  }
}
