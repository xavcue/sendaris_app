import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../../features/auth/presentation/views/login_view.dart';
import '../../features/home/presentation/views/home_placeholder_view.dart';
import '../../features/tracking/domain/repositories/tracking_repository.dart';
import '../../features/tracking/domain/services/anonymous_tracking_profile_factory.dart';

abstract final class AppRouter {
  static GoRouter create(
    AuthViewModel authViewModel, {
    required TrackingRepository trackingRepository,
    required AnonymousTrackingProfileFactory trackingProfileFactory,
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
          builder: (context, state) => HomePlaceholderView(
            trackingRepository: trackingRepository,
            trackingProfileFactory: trackingProfileFactory,
          ),
        ),
      ],
    );
  }
}
