import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/atypical_situation/domain/repositories/atypical_situation_repository.dart';
import '../../features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import '../../features/atypical_situation/presentation/views/atypical_situation_form_view.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/behavior/domain/repositories/behavior_repository.dart';
import '../../features/behavior/domain/services/behavior_record_factory.dart';
import '../../features/behavior/presentation/views/behavior_form_view.dart';
import '../../features/feeding/domain/repositories/feeding_repository.dart';
import '../../features/feeding/domain/services/feeding_record_factory.dart';
import '../../features/feeding/presentation/views/feeding_form_view.dart';
import '../../features/home/presentation/views/home_placeholder_view.dart';
import '../../features/register/presentation/views/register_view.dart';
import '../../features/routine/domain/models/routine.dart';
import '../../features/routine/domain/repositories/routine_repository.dart';
import '../../features/routine/domain/services/routine_factory.dart';
import '../../features/routine/presentation/views/routine_form_view.dart';
import '../../features/routine/presentation/views/routine_management_view.dart';
import '../../features/routine_status/domain/repositories/routine_status_repository.dart';
import '../../features/routine_status/domain/services/routine_status_record_factory.dart';
import '../../features/routine_status/presentation/views/routine_status_form_view.dart';
import '../../features/sleep/domain/repositories/sleep_repository.dart';
import '../../features/sleep/domain/services/sleep_record_factory.dart';
import '../../features/sleep/presentation/views/sleep_form_view.dart';
import '../../features/tracking/presentation/viewmodels/tracking_view_model.dart';
import '../animation/app_motion.dart';
import '../theme/ambient_background.dart';

abstract final class AppRouter {
  static GoRouter create(
    AuthViewModel authViewModel, {
    required TrackingViewModel trackingViewModel,
    required BehaviorRepository behaviorRepository,
    required BehaviorRecordFactory behaviorRecordFactory,
    required SleepRepository sleepRepository,
    required SleepRecordFactory sleepRecordFactory,
    required FeedingRepository feedingRepository,
    required FeedingRecordFactory feedingRecordFactory,
    required RoutineRepository routineRepository,
    required RoutineFactory routineFactory,
    required RoutineStatusRepository routineStatusRepository,
    required RoutineStatusRecordFactory routineStatusRecordFactory,
    required AtypicalSituationRepository atypicalSituationRepository,
    required AtypicalSituationRecordFactory atypicalSituationRecordFactory,
  }) {
    return GoRouter(
      initialLocation: '/',
      refreshListenable: authViewModel,
      redirect: (context, state) {
        final isAuthenticated = authViewModel.isAuthenticated;

        final isGoingToLogin = state.matchedLocation == '/login';

        if (!isAuthenticated) {
          return isGoingToLogin ? null : '/login';
        }

        if (isGoingToLogin) {
          return '/';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          name: 'login',
          pageBuilder: (context, state) {
            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                compact: false,
                child: const LoginView(),
              ),
            );
          },
        ),

        // Home ya contiene su AmbientBackground propio.
        GoRoute(
          path: '/',
          name: 'home',
          pageBuilder: (context, state) {
            return _animatedPage(
              state: state,
              child: HomePlaceholderView(trackingViewModel: trackingViewModel),
            );
          },
        ),

        GoRoute(
          path: '/register',
          name: 'register',
          pageBuilder: (context, state) {
            return _animatedPage(
              state: state,
              child: _ambientScreen(state: state, child: const RegisterView()),
            );
          },
        ),

        GoRoute(
          path: '/register/behavior',
          name: 'register-behavior',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final child = anonymousId == null
                ? const RegisterView()
                : BehaviorFormView(
                    repository: behaviorRepository,
                    recordFactory: behaviorRecordFactory,
                    anonymousId: anonymousId,
                  );

            return _animatedPage(
              state: state,
              child: _ambientScreen(state: state, child: child),
            );
          },
        ),

        GoRoute(
          path: '/register/sleep',
          name: 'register-sleep',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final child = anonymousId == null
                ? const RegisterView()
                : SleepFormView(
                    repository: sleepRepository,
                    recordFactory: sleepRecordFactory,
                    anonymousId: anonymousId,
                  );

            return _animatedPage(
              state: state,
              child: _ambientScreen(state: state, child: child),
            );
          },
        ),

        GoRoute(
          path: '/register/feeding',
          name: 'register-feeding',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final child = anonymousId == null
                ? const RegisterView()
                : FeedingFormView(
                    repository: feedingRepository,
                    recordFactory: feedingRecordFactory,
                    anonymousId: anonymousId,
                  );

            return _animatedPage(
              state: state,
              child: _ambientScreen(state: state, child: child),
            );
          },
        ),

        GoRoute(
          path: '/register/atypical-situation',
          name: 'register-atypical-situation',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final child = anonymousId == null
                ? const RegisterView()
                : AtypicalSituationFormView(
                    repository: atypicalSituationRepository,
                    recordFactory: atypicalSituationRecordFactory,
                    anonymousId: anonymousId,
                  );

            return _animatedPage(
              state: state,
              child: _ambientScreen(state: state, child: child),
            );
          },
        ),

        GoRoute(
          path: '/routines',
          name: 'routine-management',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return _animatedPage(
                state: state,
                child: HomePlaceholderView(
                  trackingViewModel: trackingViewModel,
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: RoutineManagementView(
                  repository: routineRepository,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),

        GoRoute(
          path: '/routines/new',
          name: 'routine-new',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return _animatedPage(
                state: state,
                child: HomePlaceholderView(
                  trackingViewModel: trackingViewModel,
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: RoutineFormView(
                  repository: routineRepository,
                  routineFactory: routineFactory,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),

        GoRoute(
          path: '/routines/edit',
          name: 'routine-edit',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return _animatedPage(
                state: state,
                child: HomePlaceholderView(
                  trackingViewModel: trackingViewModel,
                ),
              );
            }

            final extra = state.extra;

            final child = extra is! Routine || extra.anonymousId != anonymousId
                ? RoutineManagementView(
                    repository: routineRepository,
                    anonymousId: anonymousId,
                  )
                : RoutineFormView(
                    repository: routineRepository,
                    routineFactory: routineFactory,
                    anonymousId: anonymousId,
                    initialRoutine: extra,
                  );

            return _animatedPage(
              state: state,
              child: _ambientScreen(state: state, child: child),
            );
          },
        ),

        GoRoute(
          path: '/routines/status/new',
          name: 'routine-status-new',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return _animatedPage(
                state: state,
                child: HomePlaceholderView(
                  trackingViewModel: trackingViewModel,
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: RoutineStatusFormView(
                  routineRepository: routineRepository,
                  routineStatusRepository: routineStatusRepository,
                  recordFactory: routineStatusRecordFactory,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  static Widget _ambientScreen({
    required GoRouterState state,
    required Widget child,
    bool compact = true,
  }) {
    return AmbientBackground(
      key: ValueKey<String>('ambient-${state.uri}'),
      compact: compact,
      child: child,
    );
  }

  static CustomTransitionPage<void> _animatedPage({
    required GoRouterState state,
    required Widget child,
  }) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: AppMotion.routeDuration,
      reverseTransitionDuration: AppMotion.routeReverseDuration,

      // La página sigue siendo una ruta opaca.
      // AmbientBackground pinta el lienzo completo.
      opaque: true,

      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: AppMotion.standardCurve,
          reverseCurve: AppMotion.standardCurve,
        );

        final slideAnimation = Tween<Offset>(
          begin: const Offset(0.035, 0),
          end: Offset.zero,
        ).animate(curvedAnimation);

        // No usamos FadeTransition porque las pantallas
        // transparentes mostrarían la ruta anterior debajo.
        return ClipRect(
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
    );
  }
}
