import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../../features/atypical_situation/data/repositories/firebase_atypical_situation_repository.dart';
import '../../features/atypical_situation/data/services/firestore_atypical_situation_service.dart';
import '../../features/atypical_situation/data/services/uuid_atypical_situation_record_id_generator.dart';
import '../../features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import '../../features/auth/data/repositories/firebase_auth_repository.dart';
import '../../features/auth/data/services/firebase_auth_service.dart';
import '../../features/behavior/data/repositories/firebase_behavior_repository.dart';
import '../../features/behavior/data/services/firestore_behavior_service.dart';
import '../../features/behavior/data/services/uuid_behavior_record_id_generator.dart';
import '../../features/behavior/domain/services/behavior_record_factory.dart';
import '../../features/duration/data/repositories/composite_duration_repository.dart';
import '../../features/dysregulation/data/repositories/firebase_dysregulation_repository.dart';
import '../../features/dysregulation/data/services/firestore_dysregulation_service.dart';
import '../../features/dysregulation/data/services/uuid_dysregulation_record_id_generator.dart';
import '../../features/dysregulation/domain/services/dysregulation_record_factory.dart';
import '../../features/feeding/data/repositories/firebase_feeding_repository.dart';
import '../../features/feeding/data/services/firestore_feeding_service.dart';
import '../../features/feeding/data/services/uuid_feeding_record_id_generator.dart';
import '../../features/feeding/domain/services/feeding_record_factory.dart';
import '../../features/routine/data/repositories/firebase_routine_repository.dart';
import '../../features/routine/data/services/firestore_routine_service.dart';
import '../../features/routine/data/services/uuid_routine_id_generator.dart';
import '../../features/routine/domain/services/routine_factory.dart';
import '../../features/routine_compliance/data/repositories/composite_routine_compliance_repository.dart';
import '../../features/routine_status/data/repositories/firebase_routine_status_repository.dart';
import '../../features/routine_status/data/services/firestore_routine_status_service.dart';
import '../../features/routine_status/data/services/uuid_routine_status_record_id_generator.dart';
import '../../features/routine_status/domain/services/routine_status_record_factory.dart';
import '../../features/sleep/data/repositories/firebase_sleep_repository.dart';
import '../../features/sleep/data/services/firestore_sleep_service.dart';
import '../../features/sleep/data/services/uuid_sleep_record_id_generator.dart';
import '../../features/sleep/domain/services/sleep_record_factory.dart';
import '../../features/social_interaction/data/repositories/firebase_social_interaction_repository.dart';
import '../../features/social_interaction/data/services/firestore_social_interaction_service.dart';
import '../../features/social_interaction/data/services/uuid_social_interaction_record_id_generator.dart';
import '../../features/social_interaction/domain/services/social_interaction_record_factory.dart';
import '../../features/tracking/data/repositories/firebase_tracking_repository.dart';
import '../../features/tracking/data/services/firestore_tracking_service.dart';
import '../../features/tracking/data/services/uuid_anonymous_id_generator.dart';
import '../../features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import '../session/firebase_account_contexts.dart';

/// Agrupa las dependencias funcionales de una cuenta Firebase.
///
/// Todos los servicios Firestore se crean con las mismas
/// instancias FirebaseAuth y FirebaseFirestore.
///
/// La fábrica no inicia ni cierra sesiones.
/// Tampoco concede autorización para consultar datos privados.
///
/// La autorización y la selección del contexto activo
/// deben resolverse antes de construir SendarisApp.
final class SendarisAccountDependencies {
  SendarisAccountDependencies._({
    required this.app,
    required this.auth,
    required this.firestore,
  }) {
    if (auth.app.name != app.name || firestore.app.name != app.name) {
      throw StateError(
        'Authentication y Firestore deben pertenecer '
        'a la misma aplicación Firebase.',
      );
    }
  }

  /// Construye las dependencias de la aplicación principal.
  ///
  /// Mantiene la misma aplicación Firebase que ya utiliza
  /// Sendaris. No crea una aplicación secundaria.
  factory SendarisAccountDependencies.forPrimaryApp() {
    final app = Firebase.app();

    return SendarisAccountDependencies._(
      app: app,
      auth: FirebaseAuth.instanceFor(app: app),
      firestore: FirebaseFirestore.instanceFor(app: app),
    );
  }

  /// Construye dependencias desde un contexto ya verificado.
  ///
  /// Este constructor no activa el contexto ni concede
  /// acceso privado. El componente superior deberá
  /// comprobar la identidad y la autorización.
  factory SendarisAccountDependencies.forContext(
    FirebaseAccountContext context,
  ) {
    return SendarisAccountDependencies._(
      app: context.app,
      auth: context.auth,
      firestore: context.firestore,
    );
  }

  final FirebaseApp app;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  String get applicationName => app.name;

  String? get currentUserId => auth.currentUser?.uid;

  /// Repositorio de autenticación perteneciente al contexto.
  late final authRepository = FirebaseAuthRepository(FirebaseAuthService(auth));

  /// Seguimientos.
  late final trackingService = FirestoreTrackingService(firestore, auth);

  late final trackingRepository = FirebaseTrackingRepository(trackingService);

  late final trackingProfileFactory = AnonymousTrackingProfileFactory(
    UuidAnonymousIdGenerator(),
  );

  /// Conducta.
  late final behaviorService = FirestoreBehaviorService(firestore, auth);

  late final behaviorRepository = FirebaseBehaviorRepository(behaviorService);

  late final behaviorRecordFactory = BehaviorRecordFactory(
    UuidBehaviorRecordIdGenerator(),
  );

  /// Sueño.
  late final sleepService = FirestoreSleepService(firestore, auth);

  late final sleepRepository = FirebaseSleepRepository(sleepService);

  late final sleepRecordFactory = SleepRecordFactory(
    UuidSleepRecordIdGenerator(),
  );

  /// Alimentación.
  late final feedingService = FirestoreFeedingService(firestore, auth);

  late final feedingRepository = FirebaseFeedingRepository(feedingService);

  late final feedingRecordFactory = FeedingRecordFactory(
    UuidFeedingRecordIdGenerator(),
  );

  /// Interacción social.
  late final socialInteractionService = FirestoreSocialInteractionService(
    firestore,
    auth,
  );

  late final socialInteractionRepository = FirebaseSocialInteractionRepository(
    socialInteractionService,
  );

  late final socialInteractionRecordFactory = SocialInteractionRecordFactory(
    UuidSocialInteractionRecordIdGenerator(),
  );

  /// Desregulación.
  late final dysregulationService = FirestoreDysregulationService(
    firestore,
    auth,
  );

  late final dysregulationRepository = FirebaseDysregulationRepository(
    dysregulationService,
  );

  late final dysregulationRecordFactory = DysregulationRecordFactory(
    UuidDysregulationRecordIdGenerator(),
  );

  /// Rutinas.
  late final routineService = FirestoreRoutineService(firestore, auth);

  late final routineRepository = FirebaseRoutineRepository(routineService);

  late final routineFactory = RoutineFactory(UuidRoutineIdGenerator());

  /// Estados de rutina.
  late final routineStatusService = FirestoreRoutineStatusService(
    firestore,
    auth,
  );

  late final routineStatusRepository = FirebaseRoutineStatusRepository(
    routineStatusService,
  );

  late final routineStatusRecordFactory = RoutineStatusRecordFactory(
    UuidRoutineStatusRecordIdGenerator(),
  );

  /// Otras situaciones.
  late final atypicalSituationService = FirestoreAtypicalSituationService(
    firestore,
    auth,
  );

  late final atypicalSituationRepository = FirebaseAtypicalSituationRepository(
    atypicalSituationService,
  );

  late final atypicalSituationRecordFactory = AtypicalSituationRecordFactory(
    UuidAtypicalSituationRecordIdGenerator(),
  );

  /// Indicadores de duraciones y promedios.
  late final durationRepository = CompositeDurationRepository(
    sleepRepository: sleepRepository,
    behaviorRepository: behaviorRepository,
    dysregulationRepository: dysregulationRepository,
  );

  /// Indicadores de cumplimiento de rutinas.
  late final routineComplianceRepository = CompositeRoutineComplianceRepository(
    routineRepository: routineRepository,
    routineStatusRepository: routineStatusRepository,
  );
}
