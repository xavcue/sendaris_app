import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/home/domain/exceptions/home_overview_failure.dart';
import 'package:sendaris/features/home/domain/models/home_activity_area.dart';
import 'package:sendaris/features/home/domain/models/home_day_overview.dart';
import 'package:sendaris/features/home/domain/repositories/home_overview_repository.dart';
import 'package:sendaris/features/home/domain/services/home_clock.dart';
import 'package:sendaris/features/home/presentation/viewmodels/home_view_model.dart';

void main() {
  group('HomeViewModel - Panorama de hoy', () {
    test(
      'carga el panorama usando el seguimiento activo y la fecha local',
      () async {
        final clock = _FakeHomeClock(DateTime(2026, 10, 12, 9, 30));

        final repository = _ProgrammableHomeOverviewRepository();

        repository
            .handler = ({required anonymousId, required localDate}) async {
          return HomeDayOverview(
            date: localDate,
            areas: const {HomeActivityArea.behavior, HomeActivityArea.sleep},
          );
        };

        final viewModel = HomeViewModel(
          clock: clock,
          overviewRepository: repository,
        );

        addTearDown(viewModel.dispose);

        await viewModel.setActiveTracking('seguimiento-a');

        expect(viewModel.activeAnonymousId, 'seguimiento-a');

        expect(viewModel.overview?.orderedAreas, [
          HomeActivityArea.behavior,
          HomeActivityArea.sleep,
        ]);

        expect(viewModel.lastUpdatedAt, clock.current);

        expect(viewModel.errorMessage, isNull);

        expect(viewModel.isRefreshing, isFalse);

        expect(repository.requests, hasLength(1));

        expect(repository.requests.single.anonymousId, 'seguimiento-a');

        expect(repository.requests.single.localDate, DateTime(2026, 10, 12));
      },
    );

    test(
      'mantiene el panorama anterior mientras se ejecuta un refresh',
      () async {
        final clock = _FakeHomeClock(DateTime(2026, 10, 12, 10));

        final repository = _ProgrammableHomeOverviewRepository();

        repository.handler =
            ({required anonymousId, required localDate}) async {
              return HomeDayOverview(
                date: localDate,
                areas: const {HomeActivityArea.behavior},
              );
            };

        final viewModel = HomeViewModel(
          clock: clock,
          overviewRepository: repository,
        );

        addTearDown(viewModel.dispose);

        await viewModel.setActiveTracking('seguimiento-a');

        expect(viewModel.overview?.orderedAreas, [HomeActivityArea.behavior]);

        final completer = Completer<HomeDayOverview>();

        repository.handler = ({required anonymousId, required localDate}) {
          return completer.future;
        };

        final refreshFuture = viewModel.refreshOverview();

        await Future<void>.delayed(Duration.zero);

        expect(viewModel.isRefreshing, isTrue);

        expect(viewModel.overview?.orderedAreas, [HomeActivityArea.behavior]);

        completer.complete(
          HomeDayOverview(
            date: DateTime(2026, 10, 12),
            areas: const {HomeActivityArea.sleep},
          ),
        );

        expect(await refreshFuture, isTrue);

        expect(viewModel.isRefreshing, isFalse);

        expect(viewModel.overview?.orderedAreas, [HomeActivityArea.sleep]);
      },
    );

    test('un error de refresh conserva el panorama válido anterior', () async {
      final clock = _FakeHomeClock(DateTime(2026, 10, 12, 14));

      final repository = _ProgrammableHomeOverviewRepository();

      repository.handler = ({required anonymousId, required localDate}) async {
        return HomeDayOverview(
          date: localDate,
          areas: const {HomeActivityArea.feeding, HomeActivityArea.routines},
        );
      };

      final viewModel = HomeViewModel(
        clock: clock,
        overviewRepository: repository,
      );

      addTearDown(viewModel.dispose);

      await viewModel.setActiveTracking('seguimiento-a');

      repository.handler = ({required anonymousId, required localDate}) async {
        throw const HomeOverviewFailure(
          'No fue posible actualizar el panorama de hoy. '
          'Inténtalo nuevamente.',
        );
      };

      expect(await viewModel.refreshOverview(), isFalse);

      expect(viewModel.overview?.orderedAreas, [
        HomeActivityArea.feeding,
        HomeActivityArea.routines,
      ]);

      expect(
        viewModel.errorMessage,
        'No fue posible actualizar el panorama de hoy. '
        'Inténtalo nuevamente.',
      );

      expect(viewModel.isRefreshing, isFalse);
    });

    test(
      'al cambiar de seguimiento elimina inmediatamente los datos anteriores',
      () async {
        final clock = _FakeHomeClock(DateTime(2026, 10, 12, 15));

        final repository = _ProgrammableHomeOverviewRepository();

        repository.handler =
            ({required anonymousId, required localDate}) async {
              return HomeDayOverview(
                date: localDate,
                areas: const {HomeActivityArea.behavior},
              );
            };

        final viewModel = HomeViewModel(
          clock: clock,
          overviewRepository: repository,
        );

        addTearDown(viewModel.dispose);

        await viewModel.setActiveTracking('seguimiento-a');

        expect(viewModel.overview?.orderedAreas, [HomeActivityArea.behavior]);

        final secondTrackingCompleter = Completer<HomeDayOverview>();

        repository.handler = ({required anonymousId, required localDate}) {
          return secondTrackingCompleter.future;
        };

        final changeFuture = viewModel.setActiveTracking('seguimiento-b');

        await Future<void>.delayed(Duration.zero);

        expect(viewModel.activeAnonymousId, 'seguimiento-b');

        expect(viewModel.overview, isNull);

        expect(viewModel.lastUpdatedAt, isNull);

        secondTrackingCompleter.complete(
          HomeDayOverview(
            date: DateTime(2026, 10, 12),
            areas: const {HomeActivityArea.sleep},
          ),
        );

        await changeFuture;

        expect(viewModel.overview?.orderedAreas, [HomeActivityArea.sleep]);

        expect(
          viewModel.overview?.contains(HomeActivityArea.behavior),
          isFalse,
        );
      },
    );

    test(
      'un resultado atrasado de otro seguimiento no reemplaza el actual',
      () async {
        final clock = _FakeHomeClock(DateTime(2026, 10, 12, 16));

        final repository = _ProgrammableHomeOverviewRepository();

        final firstCompleter = Completer<HomeDayOverview>();

        repository.handler = ({required anonymousId, required localDate}) {
          if (anonymousId == 'seguimiento-a') {
            return firstCompleter.future;
          }

          return Future.value(
            HomeDayOverview(
              date: localDate,
              areas: const {HomeActivityArea.routines},
            ),
          );
        };

        final viewModel = HomeViewModel(
          clock: clock,
          overviewRepository: repository,
        );

        addTearDown(viewModel.dispose);

        final firstFuture = viewModel.setActiveTracking('seguimiento-a');

        await Future<void>.delayed(Duration.zero);

        await viewModel.setActiveTracking('seguimiento-b');

        expect(viewModel.overview?.orderedAreas, [HomeActivityArea.routines]);

        firstCompleter.complete(
          HomeDayOverview(
            date: DateTime(2026, 10, 12),
            areas: const {HomeActivityArea.behavior},
          ),
        );

        await firstFuture;

        expect(viewModel.activeAnonymousId, 'seguimiento-b');

        expect(viewModel.overview?.orderedAreas, [HomeActivityArea.routines]);
      },
    );

    test('al llegar a medianoche descarta el panorama anterior y recupera el nuevo día', () async {
      final clock = _FakeHomeClock(DateTime(2026, 10, 12, 23, 59, 59));

      final scheduler = _ControlledTimerScheduler();

      final repository = _ProgrammableHomeOverviewRepository();

      repository.handler = ({required anonymousId, required localDate}) async {
        if (localDate.day == 12) {
          return HomeDayOverview(
            date: localDate,
            areas: const {HomeActivityArea.behavior},
          );
        }

        return HomeDayOverview(
          date: localDate,
          areas: const {HomeActivityArea.sleep, HomeActivityArea.routines},
        );
      };

      final viewModel = HomeViewModel(
        clock: clock,
        overviewRepository: repository,
        timerFactory: scheduler.createTimer,
      );

      addTearDown(viewModel.dispose);

      await viewModel.setActiveTracking('seguimiento-a');

      expect(viewModel.overview?.orderedAreas, [HomeActivityArea.behavior]);

      clock.current = DateTime(2026, 10, 13);

      scheduler.fire();

      await pumpEventQueue();

      expect(viewModel.localDate, DateTime(2026, 10, 13));

      expect(viewModel.overview?.orderedAreas, [
        HomeActivityArea.sleep,
        HomeActivityArea.routines,
      ]);

      expect(repository.requests, hasLength(2));

      expect(repository.requests.last.localDate, DateTime(2026, 10, 13));
    });

    test(
      'reanudar la app actualiza el panorama sin eliminar el contenido válido',
      () async {
        final clock = _FakeHomeClock(DateTime(2026, 10, 12, 10));

        final repository = _ProgrammableHomeOverviewRepository();

        repository.handler =
            ({required anonymousId, required localDate}) async {
              return HomeDayOverview(
                date: localDate,
                areas: const {HomeActivityArea.behavior},
              );
            };

        final viewModel = HomeViewModel(
          clock: clock,
          overviewRepository: repository,
        );

        addTearDown(viewModel.dispose);

        await viewModel.setActiveTracking('seguimiento-a');

        final completer = Completer<HomeDayOverview>();

        repository.handler = ({required anonymousId, required localDate}) {
          return completer.future;
        };

        clock.current = DateTime(2026, 10, 12, 15);

        viewModel.handleAppResumed();

        await Future<void>.delayed(Duration.zero);

        expect(viewModel.greeting, 'Buenas tardes');

        expect(viewModel.overview?.orderedAreas, [HomeActivityArea.behavior]);

        expect(viewModel.isRefreshing, isTrue);

        completer.complete(
          HomeDayOverview(
            date: DateTime(2026, 10, 12),
            areas: const {HomeActivityArea.socialInteraction},
          ),
        );

        await pumpEventQueue();

        expect(viewModel.isRefreshing, isFalse);

        expect(viewModel.overview?.orderedAreas, [
          HomeActivityArea.socialInteraction,
        ]);
      },
    );

    test('sin seguimiento activo no consulta el repositorio', () async {
      final clock = _FakeHomeClock(DateTime(2026, 10, 12, 12));

      final repository = _ProgrammableHomeOverviewRepository();

      final viewModel = HomeViewModel(
        clock: clock,
        overviewRepository: repository,
      );

      addTearDown(viewModel.dispose);

      expect(await viewModel.refreshOverview(), isFalse);

      expect(repository.requests, isEmpty);

      expect(viewModel.overview, isNull);
    });

    test(
      'eliminar el seguimiento activo también elimina el panorama visible',
      () async {
        final clock = _FakeHomeClock(DateTime(2026, 10, 12, 12));

        final repository = _ProgrammableHomeOverviewRepository();

        repository.handler =
            ({required anonymousId, required localDate}) async {
              return HomeDayOverview(
                date: localDate,
                areas: const {HomeActivityArea.dysregulation},
              );
            };

        final viewModel = HomeViewModel(
          clock: clock,
          overviewRepository: repository,
        );

        addTearDown(viewModel.dispose);

        await viewModel.setActiveTracking('seguimiento-a');

        expect(viewModel.overview, isNotNull);

        await viewModel.setActiveTracking(null);

        expect(viewModel.activeAnonymousId, isNull);

        expect(viewModel.overview, isNull);

        expect(viewModel.lastUpdatedAt, isNull);

        expect(viewModel.errorMessage, isNull);
      },
    );
  });
}

class _FakeHomeClock implements HomeClock {
  _FakeHomeClock(this.current);

  DateTime current;

  @override
  DateTime now() {
    return current;
  }
}

typedef _OverviewHandler = Future<HomeDayOverview> Function({
  required String anonymousId,
  required DateTime localDate,
});

class _ProgrammableHomeOverviewRepository implements HomeOverviewRepository {
  _OverviewHandler? handler;

  final List<_OverviewRequest> requests = [];

  @override
  Future<HomeDayOverview> recoverDayOverview({
    required String anonymousId,
    required DateTime localDate,
  }) {
    requests.add(
      _OverviewRequest(anonymousId: anonymousId, localDate: localDate),
    );

    final currentHandler = handler;

    if (currentHandler == null) {
      return Future.value(HomeDayOverview(date: localDate, areas: const {}));
    }

    return currentHandler(anonymousId: anonymousId, localDate: localDate);
  }
}

class _OverviewRequest {
  const _OverviewRequest({required this.anonymousId, required this.localDate});

  final String anonymousId;

  final DateTime localDate;
}

class _ControlledTimerScheduler {
  Duration? lastDuration;

  _ControlledTimer? lastTimer;

  void Function()? _callback;

  Timer createTimer(Duration duration, void Function() callback) {
    lastDuration = duration;

    _callback = callback;

    final timer = _ControlledTimer();

    lastTimer = timer;

    return timer;
  }

  void fire() {
    final callback = _callback;

    final timer = lastTimer;

    if (callback == null || timer == null || !timer.isActive) {
      throw StateError('No existe un temporizador activo para ejecutar.');
    }

    timer.markTriggered();

    callback();
  }
}

class _ControlledTimer implements Timer {
  bool _isActive = true;

  @override
  bool get isActive => _isActive;

  @override
  int get tick => _isActive ? 0 : 1;

  @override
  void cancel() {
    _isActive = false;
  }

  void markTriggered() {
    _isActive = false;
  }
}
