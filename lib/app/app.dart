import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/atypical_situation/domain/repositories/atypical_situation_repository.dart';
import '../features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../features/behavior/domain/repositories/behavior_repository.dart';
import '../features/behavior/domain/services/behavior_record_factory.dart';
import '../features/routine/domain/repositories/routine_repository.dart';
import '../features/routine/domain/services/routine_factory.dart';
import '../features/routine_status/domain/repositories/routine_status_repository.dart';
import '../features/routine_status/domain/services/routine_status_record_factory.dart';
import '../features/sleep/domain/repositories/sleep_repository.dart';
import '../features/sleep/domain/services/sleep_record_factory.dart';
import '../features/tracking/domain/repositories/tracking_repository.dart';
import '../features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import '../features/tracking/presentation/viewmodels/tracking_view_model.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_mode_controller.dart';

class SendarisApp extends StatefulWidget {
  const SendarisApp({
    required this.authRepository,
    required this.trackingRepository,
    required this.trackingProfileFactory,
    required this.behaviorRepository,
    required this.behaviorRecordFactory,
    required this.sleepRepository,
    required this.sleepRecordFactory,
    required this.routineRepository,
    required this.routineFactory,
    required this.routineStatusRepository,
    required this.routineStatusRecordFactory,
    required this.atypicalSituationRepository,
    required this.atypicalSituationRecordFactory,
    super.key,
  });

  final AuthRepository authRepository;
  final TrackingRepository trackingRepository;
  final AnonymousTrackingProfileFactory trackingProfileFactory;

  final BehaviorRepository behaviorRepository;
  final BehaviorRecordFactory behaviorRecordFactory;

  final SleepRepository sleepRepository;
  final SleepRecordFactory sleepRecordFactory;

  final RoutineRepository routineRepository;
  final RoutineFactory routineFactory;

  final RoutineStatusRepository routineStatusRepository;
  final RoutineStatusRecordFactory routineStatusRecordFactory;

  final AtypicalSituationRepository atypicalSituationRepository;
  final AtypicalSituationRecordFactory atypicalSituationRecordFactory;

  @override
  State<SendarisApp> createState() => _SendarisAppState();
}

class _SendarisAppState extends State<SendarisApp> {
  late final AuthViewModel _authViewModel;
  late final TrackingViewModel _trackingViewModel;
  late final ThemeModeController _themeModeController;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();

    _authViewModel = AuthViewModel(widget.authRepository);

    _trackingViewModel = TrackingViewModel(
      widget.trackingRepository,
      widget.trackingProfileFactory,
    );

    _themeModeController = ThemeModeController();

    _router = AppRouter.create(
      _authViewModel,
      trackingViewModel: _trackingViewModel,
      behaviorRepository: widget.behaviorRepository,
      behaviorRecordFactory: widget.behaviorRecordFactory,
      sleepRepository: widget.sleepRepository,
      sleepRecordFactory: widget.sleepRecordFactory,
      routineRepository: widget.routineRepository,
      routineFactory: widget.routineFactory,
      routineStatusRepository: widget.routineStatusRepository,
      routineStatusRecordFactory: widget.routineStatusRecordFactory,
      atypicalSituationRepository: widget.atypicalSituationRepository,
      atypicalSituationRecordFactory: widget.atypicalSituationRecordFactory,
    );
  }

  @override
  void dispose() {
    _router.dispose();
    _authViewModel.dispose();
    _trackingViewModel.dispose();
    _themeModeController.dispose();

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
        ChangeNotifierProvider<ThemeModeController>.value(
          value: _themeModeController,
        ),
      ],
      child: Consumer<ThemeModeController>(
        builder: (context, themeModeController, child) {
          return MaterialApp.router(
            title: 'Sendaris',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeModeController.themeMode,
            routerConfig: _router,
          );
        },
      ),
    );
  }
}
