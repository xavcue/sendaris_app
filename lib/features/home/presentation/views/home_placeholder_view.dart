import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../app/animation/animated_entrance.dart';
import '../../../../app/animation/animated_pressable_scale.dart';
import '../../../../app/router/app_routes.dart';
import '../../../../app/theme/ambient_background.dart';
import '../../../../app/widgets/sendaris_primary_app_bar.dart';
import '../../../tracking/presentation/viewmodels/tracking_view_model.dart';
import '../../domain/models/home_activity_area.dart';
import '../viewmodels/home_view_model.dart';
import '../widgets/home_tracking_selector_sheet.dart';

class HomePlaceholderView extends StatefulWidget {
  const HomePlaceholderView({required this.trackingViewModel, super.key});

  final TrackingViewModel trackingViewModel;

  @override
  State<HomePlaceholderView> createState() => _HomePlaceholderViewState();
}

class _HomePlaceholderViewState extends State<HomePlaceholderView> {
  late final AmbientBackgroundController _ambientBackgroundController;

  bool _wasNavigationBranchActive = false;

  bool _silentRefreshScheduled = false;

  @override
  void initState() {
    super.initState();

    _ambientBackgroundController = AmbientBackgroundController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      unawaited(widget.trackingViewModel.initialize());
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final isNavigationBranchActive = TickerMode.valuesOf(context).enabled;

    if (isNavigationBranchActive && !_wasNavigationBranchActive) {
      _scheduleSilentOverviewRefresh();
    }

    _wasNavigationBranchActive = isNavigationBranchActive;
  }

  @override
  void dispose() {
    _ambientBackgroundController.dispose();

    super.dispose();
  }

  void _scheduleSilentOverviewRefresh() {
    if (_silentRefreshScheduled) {
      return;
    }

    _silentRefreshScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _silentRefreshScheduled = false;

      if (!mounted || !TickerMode.valuesOf(context).enabled) {
        return;
      }

      final homeViewModel = context.read<HomeViewModel>();

      if (homeViewModel.activeAnonymousId == null) {
        return;
      }

      unawaited(homeViewModel.refreshOverview());
    });
  }

  Future<void> _showTrackingSelector(TrackingViewModel viewModel) async {
    final resultMessage = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) {
        return ChangeNotifierProvider<TrackingViewModel>.value(
          value: viewModel,
          child: const HomeTrackingSelectorSheet(),
        );
      },
    );

    if (!mounted || resultMessage == null) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(resultMessage)));

    _ambientBackgroundController.replay();
  }

  void _openArea(HomeActivityArea area, DateTime localDate) {
    final route = switch (area) {
      HomeActivityArea.behavior => AppRoutes.behavior,
      HomeActivityArea.sleep => AppRoutes.sleep,
      HomeActivityArea.feeding => AppRoutes.feeding,
      HomeActivityArea.socialInteraction => AppRoutes.socialInteraction,
      HomeActivityArea.dysregulation => AppRoutes.dysregulation,
      HomeActivityArea.otherSituation => AppRoutes.atypicalSituation,
      HomeActivityArea.routines => AppRoutes.routineStatus,
    };

    final date = _formatRouteDate(localDate);

    context.push('$route?date=$date');
  }

  @override
  Widget build(BuildContext context) {
    final trackingViewModel = context.watch<TrackingViewModel>();

    final homeViewModel = context.watch<HomeViewModel>();

    final activeTrackingIsSynchronized =
        trackingViewModel.activeAnonymousId == homeViewModel.activeAnonymousId;

    final initialOverviewResolved =
        homeViewModel.activeAnonymousId == null ||
        homeViewModel.hasOverview ||
        homeViewModel.errorMessage != null;

    final trackingContextReady =
        trackingViewModel.isInitialized &&
        activeTrackingIsSynchronized &&
        initialOverviewResolved;

    final trackingInitializationFailed =
        !trackingViewModel.isInitialized &&
        trackingViewModel.errorMessage != null &&
        !trackingViewModel.isLoading;

    final showInitialLoading =
        !trackingContextReady && !trackingInitializationFailed;

    return AmbientBackground(
      controller: _ambientBackgroundController,
      child: Scaffold(
        key: const Key('home-view'),
        backgroundColor: Colors.transparent,
        appBar: const SendarisPrimaryAppBar(),
        body: SafeArea(
          top: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _HomeIntroduction(
                      greeting: homeViewModel.greeting,
                      date: homeViewModel.localDate,
                    ),

                    if (trackingContextReady) ...[
                      const SizedBox(height: 24),
                      _TrackingContextCard(
                        viewModel: trackingViewModel,
                        onTap: () {
                          _showTrackingSelector(trackingViewModel);
                        },
                      ),
                      const SizedBox(height: 24),
                      _DayOverviewCard(
                        homeViewModel: homeViewModel,
                        onAreaTap: (area) {
                          _openArea(area, homeViewModel.localDate);
                        },
                      ),
                    ],

                    if (showInitialLoading) ...[
                      const SizedBox(height: 70),
                      Center(
                        child: Semantics(
                          label: 'Cargando seguimiento y panorama',
                          child: const CircularProgressIndicator(
                            key: Key('home-overview-loading'),
                          ),
                        ),
                      ),
                    ],

                    if (trackingInitializationFailed) ...[
                      const SizedBox(height: 24),
                      Card(
                        key: const Key('home-tracking-load-error'),
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                trackingViewModel.errorMessage!,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  key: const Key('home-tracking-retry-button'),
                                  onPressed: trackingViewModel.isLoading
                                      ? null
                                      : () {
                                          unawaited(
                                            trackingViewModel.initialize(),
                                          );
                                        },
                                  child: const Text('Reintentar'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ]),
                ),
              ),
              const SliverFillRemaining(
                hasScrollBody: false,
                fillOverscroll: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 28, 20, 36),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [_HomeScopeFooter()],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeIntroduction extends StatelessWidget {
  const _HomeIntroduction({required this.greeting, required this.date});

  final String greeting;

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return AnimatedEntrance(
      duration: const Duration(milliseconds: 420),
      offset: const Offset(0, 0.04),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            greeting,
            key: const Key('home-greeting'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 20,
                color: colorScheme.onSurface,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _formatHomeDate(date),
                  key: const Key('home-current-date'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Organiza eventos, rutinas e indicadores '
            'descriptivos de forma privada.',
            key: const Key('home-purpose-description'),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackingContextCard extends StatelessWidget {
  const _TrackingContextCard({required this.viewModel, required this.onTap});

  final TrackingViewModel viewModel;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final activeProfile = viewModel.activeProfile;

    final label = viewModel.activeTrackingLabel ?? 'Seguimiento';

    return AnimatedEntrance(
      delay: const Duration(milliseconds: 80),
      duration: const Duration(milliseconds: 460),
      beginScale: 0.99,
      child: AnimatedPressableScale(
        child: Card(
          key: const Key('home-tracking-selector-card'),
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: viewModel.isLoading ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.layers_outlined,
                      color: colorScheme.onPrimary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seguimiento actual',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          key: const Key('home-active-tracking-label'),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activeProfile == null
                              ? 'Toca para crear o seleccionar '
                                    'un seguimiento.'
                              : 'Activo desde el '
                                    '${_formatTrackingDate(activeProfile.createdAt)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DayOverviewCard extends StatelessWidget {
  const _DayOverviewCard({
    required this.homeViewModel,
    required this.onAreaTap,
  });

  final HomeViewModel homeViewModel;

  final ValueChanged<HomeActivityArea> onAreaTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final isDark = theme.brightness == Brightness.dark;

    final overview = homeViewModel.overview;

    final orderedAreas = overview?.orderedAreas ?? const <HomeActivityArea>[];

    return AnimatedEntrance(
      delay: const Duration(milliseconds: 150),
      duration: const Duration(milliseconds: 470),
      beginScale: 0.99,
      child: Card(
        key: const Key('home-day-overview-card'),
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hoy en el seguimiento',
                key: const Key('home-day-overview-title'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Áreas registradas hoy.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 20),

              if (homeViewModel.errorMessage != null) ...[
                Container(
                  key: const Key('home-overview-error'),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.errorContainer.withValues(
                      alpha: isDark ? 0.55 : 0.74,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 20,
                            color: colorScheme.onErrorContainer,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              homeViewModel.errorMessage!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          key: const Key('home-overview-retry-button'),
                          onPressed: homeViewModel.activeAnonymousId == null
                              ? null
                              : () {
                                  unawaited(homeViewModel.refreshOverview());
                                },
                          child: const Text('Reintentar'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              if (orderedAreas.isEmpty)
                _EmptyOverviewState(
                  hasTracking: homeViewModel.activeAnonymousId != null,
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    const spacing = 10.0;

                    final tileWidth = (constraints.maxWidth - spacing) / 2;

                    return Wrap(
                      key: const Key('home-overview-areas'),
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (final area in orderedAreas)
                          SizedBox(
                            width: tileWidth,
                            child: _ActivityAreaTile(
                              area: area,
                              count: overview!.countFor(area),
                              onTap: () {
                                onAreaTap(area);
                              },
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyOverviewState extends StatelessWidget {
  const _EmptyOverviewState({required this.hasTracking});

  final bool hasTracking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('home-overview-empty-state'),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              hasTracking ? Icons.today_outlined : Icons.layers_outlined,
              color: colorScheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasTracking
                  ? 'El panorama del día aparecerá aquí '
                        'conforme registres información.'
                  : 'Selecciona o crea un seguimiento '
                        'para comenzar a construir '
                        'el panorama del día.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityAreaTile extends StatelessWidget {
  const _ActivityAreaTile({
    required this.area,
    required this.count,
    required this.onTap,
  });

  final HomeActivityArea area;

  final int count;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final visual = _visualFor(area);

    final isDark = theme.brightness == Brightness.dark;

    return AnimatedPressableScale(
      child: Material(
        color: visual.color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          key: Key('home-overview-area-${area.code}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(17),
          child: Container(
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: visual.color.withValues(alpha: 0.24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: visual.color.withValues(
                          alpha: isDark ? 0.20 : 0.14,
                        ),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Icon(visual.icon, size: 17, color: visual.color),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      key: Key('home-overview-area-count-${area.code}'),
                      constraints: const BoxConstraints(
                        minWidth: 23,
                        minHeight: 23,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: visual.color.withValues(
                          alpha: isDark ? 0.24 : 0.17,
                        ),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  area.label,
                  softWrap: true,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeScopeFooter extends StatelessWidget {
  const _HomeScopeFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return AnimatedEntrance(
      delay: const Duration(milliseconds: 210),
      child: Container(
        key: const Key('home-descriptive-scope-footer'),
        width: double.infinity,
        padding: const EdgeInsets.only(top: 14, left: 2, right: 2),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.shield_outlined, size: 18, color: colorScheme.primary),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Sin diagnósticos, recomendaciones, '
                'predicciones ni interpretaciones clínicas.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AreaVisual {
  const _AreaVisual({required this.icon, required this.color});

  final IconData icon;

  final Color color;
}

_AreaVisual _visualFor(HomeActivityArea area) {
  return switch (area) {
    HomeActivityArea.behavior => const _AreaVisual(
      icon: Icons.psychology_alt_outlined,
      color: Color(0xFFE56F61),
    ),
    HomeActivityArea.sleep => const _AreaVisual(
      icon: Icons.bedtime_outlined,
      color: Color(0xFF78AFC1),
    ),
    HomeActivityArea.feeding => const _AreaVisual(
      icon: Icons.restaurant_outlined,
      color: Color(0xFFC9A353),
    ),
    HomeActivityArea.socialInteraction => const _AreaVisual(
      icon: Icons.groups_outlined,
      color: Color(0xFF69AA98),
    ),
    HomeActivityArea.dysregulation => const _AreaVisual(
      icon: Icons.sentiment_dissatisfied_outlined,
      color: Color(0xFF8173AE),
    ),
    HomeActivityArea.otherSituation => const _AreaVisual(
      icon: Icons.event_note_outlined,
      color: Color(0xFF9B8564),
    ),
    HomeActivityArea.routines => const _AreaVisual(
      icon: Icons.event_repeat_rounded,
      color: Color(0xFF527B7E),
    ),
  };
}

String _formatHomeDate(DateTime value) {
  const weekdays = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];

  const months = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];

  return 'Hoy, '
      '${weekdays[value.weekday - 1]} '
      '${value.day} de '
      '${months[value.month - 1]}';
}

String _formatTrackingDate(DateTime value) {
  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  final localValue = value.toLocal();

  return '${localValue.day.toString().padLeft(2, '0')} '
      '${months[localValue.month - 1]} '
      '${localValue.year}';
}

String _formatRouteDate(DateTime value) {
  final localValue = value.toLocal();

  final month = localValue.month.toString().padLeft(2, '0');

  final day = localValue.day.toString().padLeft(2, '0');

  return '${localValue.year}-$month-$day';
}
