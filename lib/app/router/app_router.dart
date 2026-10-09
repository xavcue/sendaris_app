import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/atypical_situation/domain/models/atypical_situation_record.dart';
import '../../features/atypical_situation/domain/repositories/atypical_situation_management_repository.dart';
import '../../features/atypical_situation/domain/repositories/atypical_situation_repository.dart';
import '../../features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import '../../features/atypical_situation/presentation/views/atypical_situation_detail_view.dart';
import '../../features/atypical_situation/presentation/views/atypical_situation_form_view.dart';
import '../../features/atypical_situation/presentation/views/atypical_situation_management_view.dart';
import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/behavior/domain/models/behavior_record.dart';
import '../../features/behavior/domain/repositories/behavior_management_repository.dart';
import '../../features/behavior/domain/repositories/behavior_repository.dart';
import '../../features/behavior/domain/services/behavior_record_factory.dart';
import '../../features/behavior/presentation/views/behavior_detail_view.dart';
import '../../features/behavior/presentation/views/behavior_form_view.dart';
import '../../features/behavior/presentation/views/behavior_management_view.dart';
import '../../features/duration/domain/repositories/duration_repository.dart';
import '../../features/duration/presentation/views/duration_view.dart';
import '../../features/dysregulation/domain/models/dysregulation_record.dart';
import '../../features/dysregulation/domain/repositories/dysregulation_management_repository.dart';
import '../../features/dysregulation/domain/repositories/dysregulation_repository.dart';
import '../../features/dysregulation/domain/services/dysregulation_record_factory.dart';
import '../../features/dysregulation/presentation/views/dysregulation_detail_view.dart';
import '../../features/dysregulation/presentation/views/dysregulation_form_view.dart';
import '../../features/dysregulation/presentation/views/dysregulation_management_view.dart';
import '../../features/events/presentation/views/events_view.dart';
import '../../features/feeding/domain/models/feeding_record.dart';
import '../../features/feeding/domain/repositories/feeding_management_repository.dart';
import '../../features/feeding/domain/repositories/feeding_repository.dart';
import '../../features/feeding/domain/services/feeding_record_factory.dart';
import '../../features/feeding/presentation/views/feeding_detail_view.dart';
import '../../features/feeding/presentation/views/feeding_form_view.dart';
import '../../features/feeding/presentation/views/feeding_management_view.dart';
import '../../features/frequency/domain/repositories/frequency_repository.dart';
import '../../features/frequency/presentation/views/frequency_view.dart';
import '../../features/home/presentation/views/home_placeholder_view.dart';
import '../../features/indicators/presentation/views/indicators_view.dart';
import '../../features/routine/domain/models/routine.dart';
import '../../features/routine/domain/repositories/routine_repository.dart';
import '../../features/routine/domain/services/routine_factory.dart';
import '../../features/routine/presentation/views/routine_detail_view.dart';
import '../../features/routine/presentation/views/routine_form_view.dart';
import '../../features/routine/presentation/views/routine_management_view.dart';
import '../../features/routine/presentation/views/routines_view.dart';
import '../../features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import '../../features/routine_compliance/presentation/views/routine_compliance_view.dart';
import '../../features/routine_status/domain/models/routine_status_record.dart';
import '../../features/routine_status/domain/repositories/routine_status_management_repository.dart';
import '../../features/routine_status/domain/repositories/routine_status_repository.dart';
import '../../features/routine_status/domain/services/routine_status_record_factory.dart';
import '../../features/routine_status/presentation/views/routine_status_detail_view.dart';
import '../../features/routine_status/presentation/views/routine_status_form_view.dart';
import '../../features/routine_status/presentation/views/routine_status_management_view.dart';
import '../../features/settings/presentation/views/settings_view.dart';
import '../../features/sleep/domain/models/sleep_record.dart';
import '../../features/sleep/domain/repositories/sleep_management_repository.dart';
import '../../features/sleep/domain/repositories/sleep_repository.dart';
import '../../features/sleep/domain/services/sleep_record_factory.dart';
import '../../features/sleep/presentation/views/sleep_detail_view.dart';
import '../../features/sleep/presentation/views/sleep_form_view.dart';
import '../../features/sleep/presentation/views/sleep_management_view.dart';
import '../../features/social_interaction/domain/models/social_interaction_record.dart';
import '../../features/social_interaction/domain/repositories/social_interaction_management_repository.dart';
import '../../features/social_interaction/domain/repositories/social_interaction_repository.dart';
import '../../features/social_interaction/domain/services/social_interaction_record_factory.dart';
import '../../features/social_interaction/presentation/views/social_interaction_detail_view.dart';
import '../../features/social_interaction/presentation/views/social_interaction_form_view.dart';
import '../../features/social_interaction/presentation/views/social_interaction_management_view.dart';
import '../../features/tracking/presentation/viewmodels/tracking_view_model.dart';
import '../animation/app_motion.dart';
import '../navigation/main_navigation_shell.dart';
import '../theme/ambient_background.dart';
import 'app_routes.dart';

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
    required SocialInteractionRepository socialInteractionRepository,
    required SocialInteractionRecordFactory socialInteractionRecordFactory,
    required DysregulationRepository dysregulationRepository,
    required DysregulationRecordFactory dysregulationRecordFactory,
    required FrequencyRepository frequencyRepository,
    required DurationRepository durationRepository,
    required RoutineRepository routineRepository,
    required RoutineFactory routineFactory,
    required RoutineStatusRepository routineStatusRepository,
    required RoutineStatusRecordFactory routineStatusRecordFactory,
    required RoutineComplianceRepository routineComplianceRepository,
    required AtypicalSituationRepository atypicalSituationRepository,
    required AtypicalSituationRecordFactory atypicalSituationRecordFactory,
  }) {
    final BehaviorManagementRepository? behaviorManagementRepository =
        behaviorRepository is BehaviorManagementRepository
        ? behaviorRepository
        : null;

    final SleepManagementRepository? sleepManagementRepository =
        sleepRepository is SleepManagementRepository ? sleepRepository : null;

    final FeedingManagementRepository? feedingManagementRepository =
        feedingRepository is FeedingManagementRepository
        ? feedingRepository
        : null;

    final SocialInteractionManagementRepository?
    socialInteractionManagementRepository =
        socialInteractionRepository is SocialInteractionManagementRepository
        ? socialInteractionRepository
        : null;

    final DysregulationManagementRepository? dysregulationManagementRepository =
        dysregulationRepository is DysregulationManagementRepository
        ? dysregulationRepository
        : null;

    final AtypicalSituationManagementRepository?
    atypicalSituationManagementRepository =
        atypicalSituationRepository is AtypicalSituationManagementRepository
        ? atypicalSituationRepository
        : null;

    final RoutineStatusManagementRepository? routineStatusManagementRepository =
        routineStatusRepository is RoutineStatusManagementRepository
        ? routineStatusRepository
        : null;

    Widget eventsLanding(BuildContext context) {
      final hasTracking = trackingViewModel.activeAnonymousId != null;

      return EventsView(
        key: ValueKey<String>(
          'events-'
          '${trackingViewModel.activeAnonymousId ?? 'sin-seguimiento'}',
        ),
        hasTracking: hasTracking,
        onBehaviorTap: hasTracking && behaviorManagementRepository != null
            ? () {
                context.push(AppRoutes.behavior);
              }
            : null,
        onSleepTap: hasTracking && sleepManagementRepository != null
            ? () {
                context.push(AppRoutes.sleep);
              }
            : null,
        onFeedingTap: hasTracking && feedingManagementRepository != null
            ? () {
                context.push(AppRoutes.feeding);
              }
            : null,
        onSocialInteractionTap:
            hasTracking && socialInteractionManagementRepository != null
            ? () {
                context.push(AppRoutes.socialInteraction);
              }
            : null,
        onDysregulationTap:
            hasTracking && dysregulationManagementRepository != null
            ? () {
                context.push(AppRoutes.dysregulation);
              }
            : null,
        onAtypicalSituationTap:
            hasTracking && atypicalSituationManagementRepository != null
            ? () {
                context.push(AppRoutes.atypicalSituation);
              }
            : null,
      );
    }

    return GoRouter(
      initialLocation: AppRoutes.home,
      refreshListenable: authViewModel,
      redirect: (context, state) {
        final isAuthenticated = authViewModel.isAuthenticated;

        final isGoingToLogin = state.matchedLocation == AppRoutes.login;

        if (!isAuthenticated) {
          return isGoingToLogin ? null : AppRoutes.login;
        }

        if (isGoingToLogin) {
          return AppRoutes.home;
        }

        return null;
      },
      routes: [
        GoRoute(
          path: AppRoutes.login,
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
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return MainNavigationShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.home,
                  name: 'home',
                  pageBuilder: (context, state) {
                    return NoTransitionPage<void>(
                      key: state.pageKey,
                      child: HomePlaceholderView(
                        trackingViewModel: trackingViewModel,
                      ),
                    );
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.events,
                  name: 'events',
                  pageBuilder: (context, state) {
                    return NoTransitionPage<void>(
                      key: state.pageKey,
                      child: _ambientScreen(
                        state: state,
                        child: ListenableBuilder(
                          listenable: trackingViewModel,
                          builder: (context, child) {
                            return eventsLanding(context);
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.routines,
                  name: 'routines',
                  pageBuilder: (context, state) {
                    return NoTransitionPage<void>(
                      key: state.pageKey,
                      child: _ambientScreen(
                        state: state,
                        child: ListenableBuilder(
                          listenable: trackingViewModel,
                          builder: (context, child) {
                            final hasTracking =
                                trackingViewModel.activeAnonymousId != null;

                            return RoutinesView(
                              key: ValueKey<String>(
                                'routines-'
                                '${trackingViewModel.activeAnonymousId ?? 'sin-seguimiento'}',
                              ),
                              hasTracking: hasTracking,
                              onManagementTap: hasTracking
                                  ? () {
                                      context.push(AppRoutes.routineManagement);
                                    }
                                  : null,
                              onStatusTap:
                                  hasTracking &&
                                      routineStatusManagementRepository != null
                                  ? () {
                                      context.push(AppRoutes.routineStatus);
                                    }
                                  : null,
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: AppRoutes.indicators,
                  name: 'indicators',
                  pageBuilder: (context, state) {
                    return NoTransitionPage<void>(
                      key: state.pageKey,
                      child: _ambientScreen(
                        state: state,
                        child: const IndicatorsView(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: AppRoutes.settings,
          name: 'settings',
          pageBuilder: (context, state) {
            return _animatedPage(
              state: state,
              child: _ambientScreen(state: state, child: const SettingsView()),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.behavior,
          name: 'behavior-management',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = behaviorManagementRepository;

            if (anonymousId == null || managementRepository == null) {
              return _animatedPage(
                state: state,
                child: _ambientScreen(
                  state: state,
                  child: eventsLanding(context),
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: BehaviorManagementView(
                  repository: managementRepository,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.behaviorNew,
          name: 'behavior-new',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return _animatedPage(
                state: state,
                child: _ambientScreen(
                  state: state,
                  child: eventsLanding(context),
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: BehaviorFormView(
                  repository: behaviorRepository,
                  recordFactory: behaviorRecordFactory,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.behaviorDetail,
          name: 'behavior-detail',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = behaviorManagementRepository;

            final extra = state.extra;

            if (anonymousId == null ||
                managementRepository == null ||
                extra is! BehaviorRecord ||
                extra.anonymousId != anonymousId) {
              final child = anonymousId != null && managementRepository != null
                  ? BehaviorManagementView(
                      repository: managementRepository,
                      anonymousId: anonymousId,
                    )
                  : eventsLanding(context);

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: BehaviorDetailView(record: extra),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.behaviorEdit,
          name: 'behavior-edit',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = behaviorManagementRepository;

            final extra = state.extra;

            if (anonymousId == null ||
                managementRepository == null ||
                extra is! BehaviorRecord ||
                extra.anonymousId != anonymousId) {
              final child = anonymousId != null && managementRepository != null
                  ? BehaviorManagementView(
                      repository: managementRepository,
                      anonymousId: anonymousId,
                    )
                  : eventsLanding(context);

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: BehaviorFormView(
                  repository: managementRepository,
                  recordFactory: behaviorRecordFactory,
                  anonymousId: anonymousId,
                  initialRecord: extra,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.sleep,
          name: 'sleep-management',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = sleepManagementRepository;

            if (anonymousId == null || managementRepository == null) {
              return _animatedPage(
                state: state,
                child: _ambientScreen(
                  state: state,
                  child: eventsLanding(context),
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: SleepManagementView(
                  repository: managementRepository,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.sleepNew,
          name: 'sleep-new',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return _animatedPage(
                state: state,
                child: _ambientScreen(
                  state: state,
                  child: eventsLanding(context),
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: SleepFormView(
                  repository: sleepRepository,
                  recordFactory: sleepRecordFactory,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.sleepDetail,
          name: 'sleep-detail',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = sleepManagementRepository;

            final extra = state.extra;

            if (anonymousId == null ||
                managementRepository == null ||
                extra is! SleepRecord ||
                extra.anonymousId != anonymousId) {
              final child = anonymousId != null && managementRepository != null
                  ? SleepManagementView(
                      repository: managementRepository,
                      anonymousId: anonymousId,
                    )
                  : eventsLanding(context);

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: SleepDetailView(record: extra),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.sleepEdit,
          name: 'sleep-edit',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = sleepManagementRepository;

            final extra = state.extra;

            if (anonymousId == null ||
                managementRepository == null ||
                extra is! SleepRecord ||
                extra.anonymousId != anonymousId) {
              final child = anonymousId != null && managementRepository != null
                  ? SleepManagementView(
                      repository: managementRepository,
                      anonymousId: anonymousId,
                    )
                  : eventsLanding(context);

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: SleepFormView(
                  repository: managementRepository,
                  recordFactory: sleepRecordFactory,
                  anonymousId: anonymousId,
                  initialRecord: extra,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.feeding,
          name: 'feeding-management',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = feedingManagementRepository;

            if (anonymousId == null || managementRepository == null) {
              return _animatedPage(
                state: state,
                child: _ambientScreen(
                  state: state,
                  child: eventsLanding(context),
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: FeedingManagementView(
                  repository: managementRepository,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.feedingNew,
          name: 'feeding-new',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return _animatedPage(
                state: state,
                child: _ambientScreen(
                  state: state,
                  child: eventsLanding(context),
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: FeedingFormView(
                  repository: feedingRepository,
                  recordFactory: feedingRecordFactory,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.feedingDetail,
          name: 'feeding-detail',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = feedingManagementRepository;

            final extra = state.extra;

            if (anonymousId == null ||
                managementRepository == null ||
                extra is! FeedingRecord ||
                extra.anonymousId != anonymousId) {
              final child = anonymousId != null && managementRepository != null
                  ? FeedingManagementView(
                      repository: managementRepository,
                      anonymousId: anonymousId,
                    )
                  : eventsLanding(context);

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: FeedingDetailView(record: extra),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.feedingEdit,
          name: 'feeding-edit',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = feedingManagementRepository;

            final extra = state.extra;

            if (anonymousId == null ||
                managementRepository == null ||
                extra is! FeedingRecord ||
                extra.anonymousId != anonymousId) {
              final child = anonymousId != null && managementRepository != null
                  ? FeedingManagementView(
                      repository: managementRepository,
                      anonymousId: anonymousId,
                    )
                  : eventsLanding(context);

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: FeedingFormView(
                  repository: managementRepository,
                  recordFactory: feedingRecordFactory,
                  anonymousId: anonymousId,
                  initialRecord: extra,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.socialInteraction,
          name: 'social-interaction-management',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = socialInteractionManagementRepository;

            if (anonymousId == null || managementRepository == null) {
              return _animatedPage(
                state: state,
                child: _ambientScreen(
                  state: state,
                  child: eventsLanding(context),
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: SocialInteractionManagementView(
                  repository: managementRepository,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.socialInteractionNew,
          name: 'social-interaction-new',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return _animatedPage(
                state: state,
                child: _ambientScreen(
                  state: state,
                  child: eventsLanding(context),
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: SocialInteractionFormView(
                  repository: socialInteractionRepository,
                  recordFactory: socialInteractionRecordFactory,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.socialInteractionDetail,
          name: 'social-interaction-detail',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = socialInteractionManagementRepository;

            final extra = state.extra;

            if (anonymousId == null ||
                managementRepository == null ||
                extra is! SocialInteractionRecord ||
                extra.anonymousId != anonymousId) {
              final child = anonymousId != null && managementRepository != null
                  ? SocialInteractionManagementView(
                      repository: managementRepository,
                      anonymousId: anonymousId,
                    )
                  : eventsLanding(context);

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: SocialInteractionDetailView(record: extra),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.socialInteractionEdit,
          name: 'social-interaction-edit',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = socialInteractionManagementRepository;

            final extra = state.extra;

            if (anonymousId == null ||
                managementRepository == null ||
                extra is! SocialInteractionRecord ||
                extra.anonymousId != anonymousId) {
              final child = anonymousId != null && managementRepository != null
                  ? SocialInteractionManagementView(
                      repository: managementRepository,
                      anonymousId: anonymousId,
                    )
                  : eventsLanding(context);

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: SocialInteractionFormView(
                  repository: managementRepository,
                  recordFactory: socialInteractionRecordFactory,
                  anonymousId: anonymousId,
                  initialRecord: extra,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.dysregulation,
          name: 'dysregulation-management',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = dysregulationManagementRepository;

            if (anonymousId == null || managementRepository == null) {
              return _animatedPage(
                state: state,
                child: _ambientScreen(
                  state: state,
                  child: eventsLanding(context),
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: DysregulationManagementView(
                  repository: managementRepository,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.dysregulationNew,
          name: 'dysregulation-new',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return _animatedPage(
                state: state,
                child: _ambientScreen(
                  state: state,
                  child: eventsLanding(context),
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: DysregulationFormView(
                  repository: dysregulationRepository,
                  recordFactory: dysregulationRecordFactory,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.dysregulationDetail,
          name: 'dysregulation-detail',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = dysregulationManagementRepository;

            final extra = state.extra;

            if (anonymousId == null ||
                managementRepository == null ||
                extra is! DysregulationRecord ||
                extra.anonymousId != anonymousId) {
              final child = anonymousId != null && managementRepository != null
                  ? DysregulationManagementView(
                      repository: managementRepository,
                      anonymousId: anonymousId,
                    )
                  : eventsLanding(context);

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: DysregulationDetailView(record: extra),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.dysregulationEdit,
          name: 'dysregulation-edit',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = dysregulationManagementRepository;

            final extra = state.extra;

            if (anonymousId == null ||
                managementRepository == null ||
                extra is! DysregulationRecord ||
                extra.anonymousId != anonymousId) {
              final child = anonymousId != null && managementRepository != null
                  ? DysregulationManagementView(
                      repository: managementRepository,
                      anonymousId: anonymousId,
                    )
                  : eventsLanding(context);

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: DysregulationFormView(
                  repository: managementRepository,
                  recordFactory: dysregulationRecordFactory,
                  anonymousId: anonymousId,
                  initialRecord: extra,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.atypicalSituation,
          name: 'atypical-situation-management',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = atypicalSituationManagementRepository;

            if (anonymousId == null || managementRepository == null) {
              return _animatedPage(
                state: state,
                child: _ambientScreen(
                  state: state,
                  child: eventsLanding(context),
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: AtypicalSituationManagementView(
                  repository: managementRepository,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.atypicalSituationNew,
          name: 'atypical-situation-new',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            if (anonymousId == null) {
              return _animatedPage(
                state: state,
                child: _ambientScreen(
                  state: state,
                  child: eventsLanding(context),
                ),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: AtypicalSituationFormView(
                  repository: atypicalSituationRepository,
                  recordFactory: atypicalSituationRecordFactory,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.atypicalSituationDetail,
          name: 'atypical-situation-detail',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = atypicalSituationManagementRepository;

            final extra = state.extra;

            if (anonymousId == null ||
                managementRepository == null ||
                extra is! AtypicalSituationRecord ||
                extra.anonymousId != anonymousId) {
              final child = anonymousId != null && managementRepository != null
                  ? AtypicalSituationManagementView(
                      repository: managementRepository,
                      anonymousId: anonymousId,
                    )
                  : eventsLanding(context);

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: AtypicalSituationDetailView(record: extra),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.atypicalSituationEdit,
          name: 'atypical-situation-edit',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = atypicalSituationManagementRepository;

            final extra = state.extra;

            if (anonymousId == null ||
                managementRepository == null ||
                extra is! AtypicalSituationRecord ||
                extra.anonymousId != anonymousId) {
              final child = anonymousId != null && managementRepository != null
                  ? AtypicalSituationManagementView(
                      repository: managementRepository,
                      anonymousId: anonymousId,
                    )
                  : eventsLanding(context);

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: AtypicalSituationFormView(
                  repository: managementRepository,
                  recordFactory: atypicalSituationRecordFactory,
                  anonymousId: anonymousId,
                  initialRecord: extra,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/frequencies',
          name: 'frequencies',
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
                child: FrequencyView(
                  repository: frequencyRepository,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/durations',
          name: 'durations',
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
                child: DurationView(
                  repository: durationRepository,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: '/routine-compliance',
          name: 'routine-compliance',
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
                child: RoutineComplianceView(
                  repository: routineComplianceRepository,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.routineManagement,
          name: 'routine-management',
          redirect: (context, state) {
            return trackingViewModel.activeAnonymousId == null
                ? AppRoutes.routines
                : null;
          },
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
          path: AppRoutes.routineDetail,
          name: 'routine-detail',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final extra = state.extra;

            if (anonymousId == null ||
                extra is! Routine ||
                extra.anonymousId != anonymousId) {
              final child = anonymousId == null
                  ? HomePlaceholderView(trackingViewModel: trackingViewModel)
                  : RoutineManagementView(
                      repository: routineRepository,
                      anonymousId: anonymousId,
                    );

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: RoutineDetailView(routine: extra),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.routineNew,
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
          path: AppRoutes.routineEdit,
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
          path: AppRoutes.routineStatus,
          name: 'routine-status-management',
          redirect: (context, state) {
            return trackingViewModel.activeAnonymousId == null ||
                    routineStatusManagementRepository == null
                ? AppRoutes.routines
                : null;
          },
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = routineStatusManagementRepository;

            if (anonymousId == null || managementRepository == null) {
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
                child: RoutineStatusManagementView(
                  repository: managementRepository,
                  routineRepository: routineRepository,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.routineStatusNew,
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
        GoRoute(
          path: AppRoutes.routineStatusDetail,
          name: 'routine-status-detail',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final extra = state.extra;

            if (anonymousId == null ||
                extra is! RoutineStatusRecord ||
                extra.anonymousId != anonymousId) {
              final managementRepository = routineStatusManagementRepository;

              final child = anonymousId != null && managementRepository != null
                  ? RoutineStatusManagementView(
                      repository: managementRepository,
                      routineRepository: routineRepository,
                      anonymousId: anonymousId,
                    )
                  : HomePlaceholderView(trackingViewModel: trackingViewModel);

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: _RoutineStatusDetailRouteView(
                  record: extra,
                  routineRepository: routineRepository,
                  anonymousId: anonymousId,
                ),
              ),
            );
          },
        ),
        GoRoute(
          path: AppRoutes.routineStatusEdit,
          name: 'routine-status-edit',
          pageBuilder: (context, state) {
            final anonymousId = trackingViewModel.activeAnonymousId;

            final managementRepository = routineStatusManagementRepository;

            final extra = state.extra;

            if (anonymousId == null ||
                managementRepository == null ||
                extra is! RoutineStatusRecord ||
                extra.anonymousId != anonymousId) {
              final child = anonymousId != null && managementRepository != null
                  ? RoutineStatusManagementView(
                      repository: managementRepository,
                      routineRepository: routineRepository,
                      anonymousId: anonymousId,
                    )
                  : HomePlaceholderView(trackingViewModel: trackingViewModel);

              return _animatedPage(
                state: state,
                child: _ambientScreen(state: state, child: child),
              );
            }

            return _animatedPage(
              state: state,
              child: _ambientScreen(
                state: state,
                child: RoutineStatusFormView(
                  routineRepository: routineRepository,
                  routineStatusRepository: managementRepository,
                  recordFactory: routineStatusRecordFactory,
                  anonymousId: anonymousId,
                  initialRecord: extra,
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

        return ClipRect(
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
    );
  }
}

class _RoutineStatusDetailRouteView extends StatefulWidget {
  const _RoutineStatusDetailRouteView({
    required this.record,
    required this.routineRepository,
    required this.anonymousId,
  });

  final RoutineStatusRecord record;

  final RoutineRepository routineRepository;

  final String anonymousId;

  @override
  State<_RoutineStatusDetailRouteView> createState() {
    return _RoutineStatusDetailRouteViewState();
  }
}

class _RoutineStatusDetailRouteViewState
    extends State<_RoutineStatusDetailRouteView> {
  late final Future<String> _routineNameFuture;

  @override
  void initState() {
    super.initState();

    _routineNameFuture = _resolveRoutineName();
  }

  Future<String> _resolveRoutineName() async {
    try {
      final routines = await widget.routineRepository.recoverRoutines(
        anonymousId: widget.anonymousId,
      );

      for (final routine in routines) {
        if (routine.anonymousId == widget.anonymousId &&
            routine.routineId == widget.record.routineId) {
          return routine.name;
        }
      }
    } catch (_) {
      return 'Rutina no disponible';
    }

    return 'Rutina no disponible';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _routineNameFuture,
      builder: (context, snapshot) {
        final routineName = snapshot.data;

        if (routineName == null) {
          final theme = Theme.of(context);

          final colorScheme = theme.colorScheme;

          return Scaffold(
            key: const Key('routine-status-detail-loading'),
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Detalle de estado de rutina'),
              backgroundColor: theme.scaffoldBackgroundColor,
              foregroundColor: colorScheme.onSurface,
              elevation: 0,
              scrolledUnderElevation: 0,
              shadowColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return RoutineStatusDetailView(
          record: widget.record,
          routineName: routineName,
        );
      },
    );
  }
}
