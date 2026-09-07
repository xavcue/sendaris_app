import 'package:go_router/go_router.dart';

import '../../features/atypical_situation/domain/repositories/atypical_situation_repository.dart';
import '../../features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import '../../features/atypical_situation/presentation/views/atypical_situation_form_view.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/behavior/domain/repositories/behavior_repository.dart';
import '../../features/behavior/domain/services/behavior_record_factory.dart';
import '../../features/behavior/presentation/views/behavior_form_view.dart';
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
import '../../features/tracking/presentation/viewmodels/tracking_view_model.dart';

abstract final class AppRouter {
  static GoRouter create(
    AuthViewModel authViewModel, {
    required TrackingViewModel trackingViewModel,
    required BehaviorRepository behaviorRepository,
    required BehaviorRecordFactory behaviorRecordFactory,
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
          builder: (context, state) => const LoginView(),
        ),

        GoRoute(
          path: '/',
          name: 'home',
          builder: (context, state) =>
              HomePlaceholderView(trackingViewModel: trackingViewModel),
        ),

        GoRoute(
          path: '/register',
          name: 'register',
          builder: (context, state) => const RegisterView(),
        ),

        GoRoute(
          path: '/register/behavior',
          name: 'register-behavior',
          builder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return const RegisterView();
            }

            return BehaviorFormView(
              repository: behaviorRepository,
              recordFactory: behaviorRecordFactory,
              anonymousId: anonymousId,
            );
          },
        ),

        GoRoute(
          path: '/register/atypical-situation',
          name: 'register-atypical-situation',
          builder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return const RegisterView();
            }

            return AtypicalSituationFormView(
              repository: atypicalSituationRepository,
              recordFactory: atypicalSituationRecordFactory,
              anonymousId: anonymousId,
            );
          },
        ),

        GoRoute(
          path: '/routines',
          name: 'routine-management',
          builder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return HomePlaceholderView(trackingViewModel: trackingViewModel);
            }

            return RoutineManagementView(
              repository: routineRepository,
              anonymousId: anonymousId,
            );
          },
        ),

        GoRoute(
          path: '/routines/new',
          name: 'routine-new',
          builder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return HomePlaceholderView(trackingViewModel: trackingViewModel);
            }

            return RoutineFormView(
              repository: routineRepository,
              routineFactory: routineFactory,
              anonymousId: anonymousId,
            );
          },
        ),

        GoRoute(
          path: '/routines/edit',
          name: 'routine-edit',
          builder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return HomePlaceholderView(trackingViewModel: trackingViewModel);
            }

            final extra = state.extra;

            if (extra is! Routine || extra.anonymousId != anonymousId) {
              return RoutineManagementView(
                repository: routineRepository,
                anonymousId: anonymousId,
              );
            }

            return RoutineFormView(
              repository: routineRepository,
              routineFactory: routineFactory,
              anonymousId: anonymousId,
              initialRoutine: extra,
            );
          },
        ),

        GoRoute(
          path: '/routines/status/new',
          name: 'routine-status-new',
          builder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return HomePlaceholderView(trackingViewModel: trackingViewModel);
            }

            return RoutineStatusFormView(
              routineRepository: routineRepository,
              routineStatusRepository: routineStatusRepository,
              recordFactory: routineStatusRecordFactory,
              anonymousId: anonymousId,
            );
          },
        ),
      ],
    );
  }
}
