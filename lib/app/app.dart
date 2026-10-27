import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/atypical_situation/domain/repositories/atypical_situation_repository.dart';
import '../features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import '../features/auth/domain/repositories/auth_repository.dart';
import '../features/auth/presentation/viewmodels/auth_view_model.dart';
import '../features/behavior/domain/repositories/behavior_repository.dart';
import '../features/behavior/domain/services/behavior_record_factory.dart';
import '../features/duration/domain/repositories/duration_repository.dart';
import '../features/dysregulation/domain/repositories/dysregulation_repository.dart';
import '../features/dysregulation/domain/services/dysregulation_record_factory.dart';
import '../features/feeding/domain/repositories/feeding_repository.dart';
import '../features/feeding/domain/services/feeding_record_factory.dart';
import '../features/home/data/repositories/composite_home_overview_repository.dart';
import '../features/home/data/services/system_home_clock.dart';
import '../features/home/presentation/viewmodels/home_view_model.dart';
import '../features/routine/domain/repositories/routine_repository.dart';
import '../features/routine/domain/services/routine_factory.dart';
import '../features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import '../features/routine_status/domain/repositories/routine_status_repository.dart';
import '../features/routine_status/domain/services/routine_status_record_factory.dart';
import '../features/sleep/domain/repositories/sleep_repository.dart';
import '../features/sleep/domain/services/sleep_record_factory.dart';
import '../features/social_interaction/domain/repositories/social_interaction_repository.dart';
import '../features/social_interaction/domain/services/social_interaction_record_factory.dart';
import '../features/tracking/domain/repositories/tracking_repository.dart';
import '../features/tracking/domain/services/anonymous_tracking_profile_factory.dart';
import '../features/tracking/presentation/viewmodels/tracking_view_model.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/sendaris_theme_preference.dart';
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
    required this.feedingRepository,
    required this.feedingRecordFactory,
    required this.socialInteractionRepository,
    required this.socialInteractionRecordFactory,
    required this.dysregulationRepository,
    required this.dysregulationRecordFactory,
    required this.durationRepository,
    required this.routineRepository,
    required this.routineFactory,
    required this.routineStatusRepository,
    required this.routineStatusRecordFactory,
    required this.routineComplianceRepository,
    required this.atypicalSituationRepository,
    required this.atypicalSituationRecordFactory,
    this.privateAccessPermission,
    super.key,
  });

  final AuthRepository authRepository;
  final ValueListenable<bool>? privateAccessPermission;

  final TrackingRepository trackingRepository;
  final AnonymousTrackingProfileFactory trackingProfileFactory;

  final BehaviorRepository behaviorRepository;
  final BehaviorRecordFactory behaviorRecordFactory;

  final SleepRepository sleepRepository;
  final SleepRecordFactory sleepRecordFactory;

  final FeedingRepository feedingRepository;
  final FeedingRecordFactory feedingRecordFactory;

  final SocialInteractionRepository socialInteractionRepository;
  final SocialInteractionRecordFactory socialInteractionRecordFactory;

  final DysregulationRepository dysregulationRepository;
  final DysregulationRecordFactory dysregulationRecordFactory;

  final DurationRepository durationRepository;

  final RoutineRepository routineRepository;
  final RoutineFactory routineFactory;

  final RoutineStatusRepository routineStatusRepository;
  final RoutineStatusRecordFactory routineStatusRecordFactory;

  final RoutineComplianceRepository routineComplianceRepository;

  final AtypicalSituationRepository atypicalSituationRepository;
  final AtypicalSituationRecordFactory atypicalSituationRecordFactory;

  @override
  State<SendarisApp> createState() => _SendarisAppState();
}

class _SendarisAppState extends State<SendarisApp> with WidgetsBindingObserver {
  late final AuthViewModel _authViewModel;
  late final TrackingViewModel _trackingViewModel;
  late final HomeViewModel _homeViewModel;
  late final ThemeModeController _themeModeController;
  late final GoRouter _router;

  // Recuerda el ultimo UID habilitado para utilizar
  // las funcionalidades de seguimiento de Sendaris.
  //
  // Es independiente del identificador anonimo
  // de cada seguimiento.
  String? _lastTrackingUserId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _authViewModel = AuthViewModel(widget.authRepository);

    _trackingViewModel = TrackingViewModel(
      widget.trackingRepository,
      widget.trackingProfileFactory,
    );

    final homeOverviewRepository = CompositeHomeOverviewRepository(
      behaviorRepository: widget.behaviorRepository,
      sleepRepository: widget.sleepRepository,
      feedingRepository: widget.feedingRepository,
      socialInteractionRepository: widget.socialInteractionRepository,
      dysregulationRepository: widget.dysregulationRepository,
      atypicalSituationRepository: widget.atypicalSituationRepository,
      routineStatusRepository: widget.routineStatusRepository,
    );

    _homeViewModel = HomeViewModel(
      clock: const SystemHomeClock(),
      overviewRepository: homeOverviewRepository,
    );

    // En produccion, main() ya recupero la preferencia
    // persistida antes de construir esta instancia.
    //
    // Los tests que no inicializan almacenamiento
    // conservan el comportamiento original: Sistema.
    _themeModeController = ThemeModeController(
      initialMode: SendarisThemePreference.isInitialized
          ? SendarisThemePreference.selectedMode
          : ThemeMode.system,
      onChanged: (mode) {
        unawaited(SendarisThemePreference.save(mode));
      },
    );

    _trackingViewModel.addListener(_handleTrackingChange);

    _authViewModel.addListener(_handleAuthenticationChange);

    // Sincroniza el contexto inicial antes de preparar
    // la navegacion de la aplicacion.
    _handleTrackingChange();
    _handleAuthenticationChange();

    if (_authViewModel.isAuthenticated) {
      unawaited(_authViewModel.validateCurrentSession());
    }

    _router = AppRouter.create(
      _authViewModel,
      privateAccessPermission: widget.privateAccessPermission,
      trackingViewModel: _trackingViewModel,
      behaviorRepository: widget.behaviorRepository,
      behaviorRecordFactory: widget.behaviorRecordFactory,
      sleepRepository: widget.sleepRepository,
      sleepRecordFactory: widget.sleepRecordFactory,
      feedingRepository: widget.feedingRepository,
      feedingRecordFactory: widget.feedingRecordFactory,
      socialInteractionRepository: widget.socialInteractionRepository,
      socialInteractionRecordFactory: widget.socialInteractionRecordFactory,
      dysregulationRepository: widget.dysregulationRepository,
      dysregulationRecordFactory: widget.dysregulationRecordFactory,
      durationRepository: widget.durationRepository,
      routineRepository: widget.routineRepository,
      routineFactory: widget.routineFactory,
      routineStatusRepository: widget.routineStatusRepository,
      routineStatusRecordFactory: widget.routineStatusRecordFactory,
      routineComplianceRepository: widget.routineComplianceRepository,
      atypicalSituationRepository: widget.atypicalSituationRepository,
      atypicalSituationRecordFactory: widget.atypicalSituationRecordFactory,
    );
  }

  void _handleTrackingChange() {
    unawaited(
      _homeViewModel.setActiveTracking(_trackingViewModel.activeAnonymousId),
    );
  }

  /// Sincroniza el seguimiento con la identidad autenticada.
  ///
  /// Cuando cambia directamente de una cuenta habilitada
  /// a otra, invalida los seguimientos anteriores e inicia
  /// la recuperacion correspondiente al nuevo UID.
  ///
  /// La recuperacion inicial sigue a cargo de Inicio,
  /// evitando ejecutar dos cargas al montar la pantalla.
  void _handleAuthenticationChange() {
    if (widget.authRepository is AuthIdentityRepository) {
      final userId = _authViewModel.isAuthenticatedAppReady
          ? _authViewModel.currentUserId
          : null;

      final previousUserId = _lastTrackingUserId;

      final isDirectAccountSwitch =
          previousUserId != null && userId != null && previousUserId != userId;

      _lastTrackingUserId = userId;

      // Si el UID cambia, TrackingViewModel descarta
      // los perfiles de la cuenta anterior e invalida
      // los resultados asincronicos pendientes.
      _trackingViewModel.synchronizeAuthenticationContext(userId);

      // Una pantalla Inicio que permanece montada no
      // ejecuta nuevamente initState al cambiar de UID.
      //
      // Por ello recuperamos aqui los perfiles de B
      // exclusivamente cuando ocurre un cambio directo
      // entre dos cuentas autenticadas y habilitadas.
      if (isDirectAccountSwitch) {
        unawaited(_trackingViewModel.initialize());
      }

      if (userId == null) {
        unawaited(_homeViewModel.setActiveTracking(null));
      }

      return;
    }

    // Compatibilidad con repositorios que no exponen UID.
    // FirebaseAuthRepository implementa la interfaz
    // AuthIdentityRepository y utiliza la ruta anterior.
    if (!_authViewModel.isAuthenticated) {
      _trackingViewModel.clearAuthenticationState();

      unawaited(_homeViewModel.setActiveTracking(null));
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state != AppLifecycleState.resumed) {
      return;
    }

    _homeViewModel.handleAppResumed();

    if (!_authViewModel.isAuthenticated) {
      return;
    }

    unawaited(_authViewModel.validateCurrentSession());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _router.dispose();

    _authViewModel.removeListener(_handleAuthenticationChange);

    _trackingViewModel.removeListener(_handleTrackingChange);

    _authViewModel.dispose();
    _trackingViewModel.dispose();
    _homeViewModel.dispose();
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
        ChangeNotifierProvider<HomeViewModel>.value(value: _homeViewModel),
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
