import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/behavior/domain/repositories/behavior_repository.dart';
import '../../features/behavior/domain/services/behavior_record_factory.dart';
import '../../features/behavior/presentation/views/behavior_form_view.dart';
import '../../features/home/presentation/views/home_placeholder_view.dart';
import '../../features/register/presentation/views/register_view.dart';
import '../../features/tracking/presentation/viewmodels/tracking_view_model.dart';

abstract final class AppRouter {
  static GoRouter create(
    AuthViewModel authViewModel, {
    required TrackingViewModel trackingViewModel,
    required BehaviorRepository behaviorRepository,
    required BehaviorRecordFactory behaviorRecordFactory,
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
      ],
    );
  }
}
