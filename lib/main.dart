import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app/app.dart';
import 'features/atypical_situation/data/repositories/firebase_atypical_situation_repository.dart';
import 'features/atypical_situation/data/services/firestore_atypical_situation_service.dart';
import 'features/atypical_situation/data/services/uuid_atypical_situation_record_id_generator.dart';
import 'features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import 'features/auth/data/repositories/firebase_auth_repository.dart';
import 'features/auth/data/services/firebase_auth_service.dart';
import 'features/behavior/data/repositories/firebase_behavior_repository.dart';
import 'features/behavior/data/services/firestore_behavior_service.dart';
import 'features/behavior/data/services/uuid_behavior_record_id_generator.dart';
import 'features/behavior/domain/services/behavior_record_factory.dart';
import 'features/duration/data/repositories/composite_duration_repository.dart';
import 'features/dysregulation/data/repositories/firebase_dysregulation_repository.dart';
import 'features/dysregulation/data/services/firestore_dysregulation_service.dart';
import 'features/dysregulation/data/services/uuid_dysregulation_record_id_generator.dart';
import 'features/dysregulation/domain/services/dysregulation_record_factory.dart';
import 'features/feeding/data/repositories/firebase_feeding_repository.dart';
import 'features/feeding/data/services/firestore_feeding_service.dart';
import 'features/feeding/data/services/uuid_feeding_record_id_generator.dart';
import 'features/feeding/domain/services/feeding_record_factory.dart';
import 'features/frequency/data/repositories/composite_frequency_repository.dart';
import 'features/history/data/repositories/firebase_history_repository.dart';
import 'features/history/data/services/firestore_history_service.dart';
import 'features/routine/data/repositories/firebase_routine_repository.dart';
import 'features/routine/data/services/firestore_routine_service.dart';
import 'features/routine/data/services/uuid_routine_id_generator.dart';
import 'features/routine/domain/services/routine_factory.dart';
import 'features/routine_status/data/repositories/firebase_routine_status_repository.dart';
import 'features/routine_status/data/services/firestore_routine_status_service.dart';
import 'features/routine_status/data/services/uuid_routine_status_record_id_generator.dart';
import 'features/routine_status/domain/services/routine_status_record_factory.dart';
import 'features/sleep/data/repositories/firebase_sleep_repository.dart';
import 'features/sleep/data/services/firestore_sleep_service.dart';
import 'features/sleep/data/services/uuid_sleep_record_id_generator.dart';
import 'features/sleep/domain/services/sleep_record_factory.dart';
import 'features/social_interaction/data/repositories/firebase_social_interaction_repository.dart';
import 'features/social_interaction/data/services/firestore_social_interaction_service.dart';
import 'features/social_interaction/data/services/uuid_social_interaction_record_id_generator.dart';
import 'features/social_interaction/domain/services/social_interaction_record_factory.dart';
import 'features/tracking/data/repositories/firebase_tracking_repository.dart';
import 'features/tracking/data/services/firestore_tracking_service.dart';
import 'features/tracking/data/services/uuid_anonymous_id_generator.dart';
import 'features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? const AndroidDebugProvider()
        : const AndroidPlayIntegrityProvider(),
    providerApple: kDebugMode
        ? const AppleDebugProvider()
        : const AppleAppAttestWithDeviceCheckFallbackProvider(),
  );

  final firebaseAuth = FirebaseAuth.instance;

  final firestore = FirebaseFirestore.instance;

  firestore.settings = const Settings(persistenceEnabled: true);

  final authService = FirebaseAuthService(firebaseAuth);

  final authRepository = FirebaseAuthRepository(authService);

  final trackingService = FirestoreTrackingService(firestore, firebaseAuth);

  final trackingRepository = FirebaseTrackingRepository(trackingService);

  final trackingProfileFactory = AnonymousTrackingProfileFactory(
    UuidAnonymousIdGenerator(),
  );

  final behaviorService = FirestoreBehaviorService(firestore, firebaseAuth);

  final behaviorRepository = FirebaseBehaviorRepository(behaviorService);

  final behaviorRecordFactory = BehaviorRecordFactory(
    UuidBehaviorRecordIdGenerator(),
  );

  final sleepService = FirestoreSleepService(firestore, firebaseAuth);

  final sleepRepository = FirebaseSleepRepository(sleepService);

  final sleepRecordFactory = SleepRecordFactory(UuidSleepRecordIdGenerator());

  final feedingService = FirestoreFeedingService(firestore, firebaseAuth);

  final feedingRepository = FirebaseFeedingRepository(feedingService);

  final feedingRecordFactory = FeedingRecordFactory(
    UuidFeedingRecordIdGenerator(),
  );

  final socialInteractionService = FirestoreSocialInteractionService(
    firestore,
    firebaseAuth,
  );

  final socialInteractionRepository = FirebaseSocialInteractionRepository(
    socialInteractionService,
  );

  final socialInteractionRecordFactory = SocialInteractionRecordFactory(
    UuidSocialInteractionRecordIdGenerator(),
  );

  final dysregulationService = FirestoreDysregulationService(
    firestore,
    firebaseAuth,
  );

  final dysregulationRepository = FirebaseDysregulationRepository(
    dysregulationService,
  );

  final dysregulationRecordFactory = DysregulationRecordFactory(
    UuidDysregulationRecordIdGenerator(),
  );

  final historyService = FirestoreHistoryService(firestore, firebaseAuth);

  final historyRepository = FirebaseHistoryRepository(historyService);

  final routineService = FirestoreRoutineService(firestore, firebaseAuth);

  final routineRepository = FirebaseRoutineRepository(routineService);

  final routineFactory = RoutineFactory(UuidRoutineIdGenerator());

  final routineStatusService = FirestoreRoutineStatusService(
    firestore,
    firebaseAuth,
  );

  final routineStatusRepository = FirebaseRoutineStatusRepository(
    routineStatusService,
  );

  final routineStatusRecordFactory = RoutineStatusRecordFactory(
    UuidRoutineStatusRecordIdGenerator(),
  );

  final atypicalSituationService = FirestoreAtypicalSituationService(
    firestore,
    firebaseAuth,
  );

  final atypicalSituationRepository = FirebaseAtypicalSituationRepository(
    atypicalSituationService,
  );

  final atypicalSituationRecordFactory = AtypicalSituationRecordFactory(
    UuidAtypicalSituationRecordIdGenerator(),
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

  runApp(
    SendarisApp(
      authRepository: authRepository,
      trackingRepository: trackingRepository,
      trackingProfileFactory: trackingProfileFactory,
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
}
