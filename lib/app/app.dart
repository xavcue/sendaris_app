import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../features/behavior/domain/repositories/behavior_repository.dart';
import '../features/behavior/domain/services/behavior_record_factory.dart';
import '../features/routine/domain/repositories/routine_repository.dart';
import '../features/routine/domain/services/routine_factory.dart';
import '../features/tracking/domain/repositories/tracking_repository.dart';
import '../features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import '../features/tracking/presentation/viewmodels/tracking_view_model.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class SendarisApp extends StatefulWidget {
  const SendarisApp({
    required this.authRepository,
    required this.trackingRepository,
    required this.trackingProfileFactory,
    required this.behaviorRepository,
    required this.behaviorRecordFactory,
    required this.routineRepository,
    required this.routineFactory,
    super.key,
  });

  final AuthRepository authRepository;

  final TrackingRepository trackingRepository;

  final AnonymousTrackingProfileFactory trackingProfileFactory;

  final BehaviorRepository behaviorRepository;

  final BehaviorRecordFactory behaviorRecordFactory;

  final RoutineRepository routineRepository;

  final RoutineFactory routineFactory;

  @override
  State<SendarisApp> createState() => _SendarisAppState();
}

class _SendarisAppState extends State<SendarisApp> {
  late final AuthViewModel _authViewModel;

  late final TrackingViewModel _trackingViewModel;

  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _authViewModel = AuthViewModel(widget.authRepository);

    _trackingViewModel = TrackingViewModel(
      widget.trackingRepository,
      widget.trackingProfileFactory,
    );

    _router = AppRouter.create(
      _authViewModel,
      trackingViewModel: _trackingViewModel,
      behaviorRepository: widget.behaviorRepository,
      behaviorRecordFactory: widget.behaviorRecordFactory,
      routineRepository: widget.routineRepository,
      routineFactory: widget.routineFactory,
    );
  }

  @override
  void dispose() {
    _router.dispose();

    _authViewModel.dispose();

    _trackingViewModel.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthViewModel>.value(value: _authViewModel),
        ChangeNotifierProvider<TrackingViewModel>.value(
          value: _trackingViewModel,
        ),
      ],
      child: MaterialApp.router(
        title: 'Sendaris',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
      ),
    );
  }
}
