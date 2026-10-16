import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:sendaris/app/app.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';
import 'package:sendaris/features/auth/presentation/viewmodels/auth_view_model.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_factory.dart';
import 'package:sendaris/features/duration/data/repositories/composite_duration_repository.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_factory.dart';
import 'package:sendaris/features/feeding/domain/services/feeding_record_factory.dart';
import 'package:sendaris/features/routine/domain/services/routine_factory.dart';
import 'package:sendaris/features/routine_compliance/data/repositories/composite_routine_compliance_repository.dart';
import 'package:sendaris/features/routine_status/domain/services/routine_status_record_factory.dart';
import 'package:sendaris/features/sleep/domain/services/sleep_record_factory.dart';
import 'package:sendaris/features/social_interaction/domain/services/social_interaction_record_factory.dart';
import 'package:sendaris/features/tracking/domain/models/anonymous_tracking_profile.dart';
import 'package:sendaris/features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import 'package:sendaris/features/tracking/presentation/viewmodels/tracking_view_model.dart';

import '../widget_test.dart' as fixtures;

void main() {
  group('SendarisApp - integración del contexto autenticado', () {
    testWidgets('al cambiar directamente de A a B, inicia '
        'la recuperación de los seguimientos de B', (tester) async {
      final authRepository = _IdentityAuthRepository(
        initialUserId: 'uid-a',
        verified: true,
      );

      addTearDown(authRepository.dispose);

      final trackingRepository = _CountingTrackingRepository();

      await tester.pumpWidget(_buildApp(authRepository, trackingRepository));

      await tester.pumpAndSettle();

      final context = tester.element(find.byKey(const Key('home-view')));

      final authViewModel = context.read<AuthViewModel>();
      final trackingViewModel = context.read<TrackingViewModel>();

      expect(authViewModel.currentUserId, 'uid-a');
      expect(authViewModel.isAuthenticatedAppReady, isTrue);
      expect(trackingViewModel.isInitialized, isTrue);

      final created = await trackingViewModel.createAndPersistProfile();

      expect(created, isTrue);
      expect(trackingViewModel.activeAnonymousId, isNotNull);

      authRepository.setSession(userId: 'uid-b', verified: true);

      await tester.pumpAndSettle();

      expect(authViewModel.currentUserId, 'uid-b');

      expect(trackingViewModel.activeAnonymousId, isNull);
      expect(trackingViewModel.profiles, isEmpty);

      expect(
        trackingViewModel.isInitialized,
        isTrue,
        reason:
            'La aplicación debe recuperar los seguimientos '
            'de B sin reiniciar la pantalla Inicio.',
      );
    });

    testWidgets('una cuenta sin verificar no habilita seguimientos '
        'y el cierre de sesión limpia el contexto', (tester) async {
      final authRepository = _IdentityAuthRepository(
        initialUserId: 'uid-a',
        verified: false,
      );

      addTearDown(authRepository.dispose);

      final trackingRepository = _CountingTrackingRepository();

      await tester.pumpWidget(_buildApp(authRepository, trackingRepository));

      await tester.pumpAndSettle();

      final context = tester.element(find.byType(MaterialApp));

      final authViewModel = context.read<AuthViewModel>();
      final trackingViewModel = context.read<TrackingViewModel>();

      expect(authViewModel.isAuthenticated, isTrue);
      expect(authViewModel.isAuthenticatedAppReady, isFalse);
      expect(trackingViewModel.isInitialized, isFalse);

      expect(await trackingViewModel.createAndPersistProfile(), isFalse);

      authRepository.setSession(userId: 'uid-a', verified: true);

      await tester.pumpAndSettle();

      expect(authViewModel.isAuthenticatedAppReady, isTrue);
      expect(trackingViewModel.isInitialized, isTrue);

      authRepository.setSession(userId: null, verified: false);

      await tester.pumpAndSettle();

      expect(authViewModel.isAuthenticated, isFalse);
      expect(authViewModel.currentUserId, isNull);

      expect(trackingViewModel.isInitialized, isFalse);
      expect(trackingViewModel.activeAnonymousId, isNull);
      expect(trackingViewModel.profiles, isEmpty);
    });

    testWidgets('A cierra sesión y B inicia sin conservar seguimientos de A', (
      tester,
    ) async {
      final authRepository = _IdentityAuthRepository(
        initialUserId: 'uid-a',
        verified: true,
      );

      addTearDown(authRepository.dispose);

      final trackingRepository = _CountingTrackingRepository();

      await tester.pumpWidget(_buildApp(authRepository, trackingRepository));

      await tester.pumpAndSettle();

      final context = tester.element(find.byKey(const Key('home-view')));

      final authViewModel = context.read<AuthViewModel>();
      final trackingViewModel = context.read<TrackingViewModel>();

      expect(trackingViewModel.isInitialized, isTrue);

      expect(await trackingViewModel.createAndPersistProfile(), isTrue);

      expect(trackingViewModel.hasProfiles, isTrue);

      authRepository.setSession(userId: null, verified: false);

      await tester.pumpAndSettle();

      expect(authViewModel.isAuthenticated, isFalse);
      expect(trackingViewModel.profiles, isEmpty);
      expect(trackingViewModel.isInitialized, isFalse);

      authRepository.setSession(userId: 'uid-b', verified: true);

      await tester.pumpAndSettle();

      expect(authViewModel.currentUserId, 'uid-b');
      expect(authViewModel.isAuthenticatedAppReady, isTrue);

      expect(find.byKey(const Key('home-view')), findsOneWidget);

      expect(trackingViewModel.isInitialized, isTrue);
      expect(trackingViewModel.profiles, isEmpty);
      expect(trackingViewModel.activeAnonymousId, isNull);
    });

    testWidgets('A vuelve después de B sin recuperar el estado local antiguo', (
      tester,
    ) async {
      final authRepository = _IdentityAuthRepository(
        initialUserId: 'uid-a',
        verified: true,
      );

      addTearDown(authRepository.dispose);

      final trackingRepository = _CountingTrackingRepository();

      await tester.pumpWidget(_buildApp(authRepository, trackingRepository));

      await tester.pumpAndSettle();

      final context = tester.element(find.byKey(const Key('home-view')));

      final trackingViewModel = context.read<TrackingViewModel>();

      expect(await trackingViewModel.createAndPersistProfile(), isTrue);

      expect(trackingViewModel.hasProfiles, isTrue);

      authRepository.setSession(userId: 'uid-b', verified: true);

      await tester.pumpAndSettle();

      expect(trackingViewModel.isInitialized, isTrue);
      expect(trackingViewModel.profiles, isEmpty);

      authRepository.setSession(userId: 'uid-a', verified: true);

      await tester.pumpAndSettle();

      expect(trackingViewModel.isInitialized, isTrue);

      // El repositorio simulado no contiene perfiles remotos.
      // Por ello, ningún dato antiguo debe reaparecer
      // únicamente desde la memoria del ViewModel.
      expect(trackingViewModel.profiles, isEmpty);
      expect(trackingViewModel.activeAnonymousId, isNull);
    });

    testWidgets('eventos repetidos del mismo UID no reinician seguimientos', (
      tester,
    ) async {
      final authRepository = _IdentityAuthRepository(
        initialUserId: 'uid-a',
        verified: true,
      );

      addTearDown(authRepository.dispose);

      final trackingRepository = _CountingTrackingRepository();

      await tester.pumpWidget(_buildApp(authRepository, trackingRepository));

      await tester.pumpAndSettle();

      final context = tester.element(find.byKey(const Key('home-view')));

      final trackingViewModel = context.read<TrackingViewModel>();

      expect(trackingViewModel.isInitialized, isTrue);

      expect(await trackingViewModel.createAndPersistProfile(), isTrue);

      final activeId = trackingViewModel.activeAnonymousId;
      final previousRecoveries = trackingRepository.recoverCalls;

      authRepository.setSession(userId: 'uid-a', verified: true);

      authRepository.setSession(userId: 'uid-a', verified: true);

      await tester.pumpAndSettle();

      expect(trackingViewModel.isInitialized, isTrue);
      expect(trackingViewModel.activeAnonymousId, activeId);

      expect(
        trackingRepository.recoverCalls,
        previousRecoveries,
        reason:
            'Un evento repetido de la misma identidad '
            'no debe iniciar otra recuperación.',
      );
    });
  });
}

SendarisApp _buildApp(
  AuthRepository authRepository,
  fixtures.FakeTrackingRepository trackingRepository,
) {
  final behaviorRepository = fixtures.FakeBehaviorRepository();
  final sleepRepository = fixtures.FakeSleepRepository();
  final feedingRepository = fixtures.FakeFeedingRepository();

  final socialInteractionRepository =
      fixtures.FakeSocialInteractionRepository();

  final dysregulationRepository = fixtures.FakeDysregulationRepository();

  final routineRepository = fixtures.FakeRoutineRepository();

  final routineStatusRepository = fixtures.FakeRoutineStatusRepository();

  final atypicalSituationRepository =
      fixtures.FakeAtypicalSituationRepository();

  return SendarisApp(
    authRepository: authRepository,
    trackingRepository: trackingRepository,
    trackingProfileFactory: AnonymousTrackingProfileFactory(
      fixtures.FakeAnonymousIdGenerator(),
    ),
    behaviorRepository: behaviorRepository,
    behaviorRecordFactory: const BehaviorRecordFactory(
      fixtures.FakeBehaviorRecordIdGenerator(),
    ),
    sleepRepository: sleepRepository,
    sleepRecordFactory: const SleepRecordFactory(
      fixtures.FakeSleepRecordIdGenerator(),
    ),
    feedingRepository: feedingRepository,
    feedingRecordFactory: const FeedingRecordFactory(
      fixtures.FakeFeedingRecordIdGenerator(),
    ),
    socialInteractionRepository: socialInteractionRepository,
    socialInteractionRecordFactory: const SocialInteractionRecordFactory(
      fixtures.FakeSocialInteractionRecordIdGenerator(),
    ),
    dysregulationRepository: dysregulationRepository,
    dysregulationRecordFactory: const DysregulationRecordFactory(
      fixtures.FakeDysregulationRecordIdGenerator(),
    ),
    durationRepository: CompositeDurationRepository(
      sleepRepository: sleepRepository,
      behaviorRepository: behaviorRepository,
      dysregulationRepository: dysregulationRepository,
    ),
    routineRepository: routineRepository,
    routineFactory: RoutineFactory(fixtures.FakeRoutineIdGenerator()),
    routineStatusRepository: routineStatusRepository,
    routineStatusRecordFactory: const RoutineStatusRecordFactory(
      fixtures.FakeRoutineStatusRecordIdGenerator(),
    ),
    routineComplianceRepository: CompositeRoutineComplianceRepository(
      routineRepository: routineRepository,
      routineStatusRepository: routineStatusRepository,
    ),
    atypicalSituationRepository: atypicalSituationRepository,
    atypicalSituationRecordFactory: const AtypicalSituationRecordFactory(
      fixtures.FakeAtypicalSituationRecordIdGenerator(),
    ),
  );
}

class _CountingTrackingRepository extends fixtures.FakeTrackingRepository {
  int recoverCalls = 0;

  @override
  Future<List<AnonymousTrackingProfile>> recoverProfiles() async {
    recoverCalls++;

    return super.recoverProfiles();
  }
}

class _IdentityAuthRepository
    implements
        AuthRepository,
        AuthIdentityRepository,
        AuthEmailVerificationRepository {
  _IdentityAuthRepository({
    required String? initialUserId,
    required this.verified,
  }) : _userId = initialUserId;

  final StreamController<bool> _authenticationController =
      StreamController<bool>.broadcast(sync: true);

  final StreamController<String?> _identityController =
      StreamController<String?>.broadcast(sync: true);

  String? _userId;

  bool verified;

  @override
  bool get isAuthenticated => _userId != null;

  @override
  String? get currentUserId => _userId;

  @override
  String? get currentUserEmail =>
      _userId == null ? null : 'usuario@example.test';

  @override
  bool get isCurrentUserEmailVerified => verified;

  @override
  Stream<bool> get authStateChanges => _authenticationController.stream;

  @override
  Stream<String?> get userIdChanges => _identityController.stream;

  void setSession({required String? userId, required bool verified}) {
    _userId = userId;
    this.verified = verified;

    _identityController.add(userId);
    _authenticationController.add(userId != null);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    setSession(userId: 'uid-login-test', verified: true);
  }

  @override
  Future<void> signOut() async {
    setSession(userId: null, verified: false);
  }

  @override
  Future<void> sendEmailVerification() async {}

  @override
  Future<bool> refreshEmailVerificationStatus() async {
    return verified;
  }

  Future<void> dispose() async {
    await _identityController.close();
    await _authenticationController.close();
  }
}
