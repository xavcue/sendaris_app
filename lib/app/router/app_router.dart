import 'package:go_router/go_router.dart';

import '../../features/home/presentation/views/home_placeholder_view.dart';

abstract final class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: 'home',
        builder: (context, state) => const HomePlaceholderView(),
      ),
    ],
  );
}
