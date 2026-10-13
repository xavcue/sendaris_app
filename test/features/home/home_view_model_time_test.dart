import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/home/domain/models/home_day_overview.dart';
import 'package:sendaris/features/home/domain/repositories/home_overview_repository.dart';
import 'package:sendaris/features/home/domain/services/home_clock.dart';
import 'package:sendaris/features/home/presentation/viewmodels/home_view_model.dart';

void main() {
  group('HomeViewModel - contexto temporal', () {
    test('expone saludo y fecha usando exclusivamente el reloj inyectado', () {
      final clock = _FakeHomeClock(DateTime(2026, 10, 12, 8, 30));

      final scheduler = _ControlledTimerScheduler();

      final viewModel = HomeViewModel(
        clock: clock,
        overviewRepository: _FakeHomeOverviewRepository(),
        timerFactory: scheduler.createTimer,
      );

      addTearDown(viewModel.dispose);

      expect(viewModel.greeting, 'Buenos días');

      expect(viewModel.localDate, DateTime(2026, 10, 12));

      expect(scheduler.lastDuration, const Duration(hours: 3, minutes: 30));
    });

    test('cambia automáticamente de Buenos días a Buenas tardes', () {
      final clock = _FakeHomeClock(DateTime(2026, 10, 12, 11, 59, 59));

      final scheduler = _ControlledTimerScheduler();

      final viewModel = HomeViewModel(
        clock: clock,
        overviewRepository: _FakeHomeOverviewRepository(),
        timerFactory: scheduler.createTimer,
      );

      addTearDown(viewModel.dispose);

      var notifications = 0;

      viewModel.addListener(() {
        notifications += 1;
      });

      expect(viewModel.greeting, 'Buenos días');

      expect(scheduler.lastDuration, const Duration(seconds: 1));

      clock.current = DateTime(2026, 10, 12, 12);

      scheduler.fire();

      expect(viewModel.greeting, 'Buenas tardes');

      expect(notifications, 1);

      expect(scheduler.lastDuration, const Duration(hours: 7));
    });

    test('cambia automáticamente de Buenas tardes a Buenas noches', () {
      final clock = _FakeHomeClock(DateTime(2026, 10, 12, 18, 59, 59));

      final scheduler = _ControlledTimerScheduler();

      final viewModel = HomeViewModel(
        clock: clock,
        overviewRepository: _FakeHomeOverviewRepository(),
        timerFactory: scheduler.createTimer,
      );

      addTearDown(viewModel.dispose);

      expect(viewModel.greeting, 'Buenas tardes');

      clock.current = DateTime(2026, 10, 12, 19);

      scheduler.fire();

      expect(viewModel.greeting, 'Buenas noches');

      expect(scheduler.lastDuration, const Duration(hours: 5));
    });

    test('actualiza la fecha al llegar a medianoche sin cambiar el saludo', () {
      final clock = _FakeHomeClock(DateTime(2026, 10, 12, 23, 59, 59));

      final scheduler = _ControlledTimerScheduler();

      final viewModel = HomeViewModel(
        clock: clock,
        overviewRepository: _FakeHomeOverviewRepository(),
        timerFactory: scheduler.createTimer,
      );

      addTearDown(viewModel.dispose);

      var notifications = 0;

      viewModel.addListener(() {
        notifications += 1;
      });

      expect(viewModel.greeting, 'Buenas noches');

      expect(viewModel.localDate, DateTime(2026, 10, 12));

      expect(scheduler.lastDuration, const Duration(seconds: 1));

      clock.current = DateTime(2026, 10, 13);

      scheduler.fire();

      expect(viewModel.greeting, 'Buenas noches');

      expect(viewModel.localDate, DateTime(2026, 10, 13));

      expect(notifications, 1);

      expect(scheduler.lastDuration, const Duration(hours: 5));
    });

    test('al reanudar la app adopta inmediatamente la hora actual', () {
      final clock = _FakeHomeClock(DateTime(2026, 10, 12, 10));

      final scheduler = _ControlledTimerScheduler();

      final viewModel = HomeViewModel(
        clock: clock,
        overviewRepository: _FakeHomeOverviewRepository(),
        timerFactory: scheduler.createTimer,
      );

      addTearDown(viewModel.dispose);

      expect(viewModel.greeting, 'Buenos días');

      clock.current = DateTime(2026, 10, 12, 20, 15);

      viewModel.handleAppResumed();

      expect(viewModel.greeting, 'Buenas noches');

      expect(viewModel.localDate, DateTime(2026, 10, 12));
    });

    test('dispose cancela el temporizador pendiente', () {
      final clock = _FakeHomeClock(DateTime(2026, 10, 12, 8));

      final scheduler = _ControlledTimerScheduler();

      final viewModel = HomeViewModel(
        clock: clock,
        overviewRepository: _FakeHomeOverviewRepository(),
        timerFactory: scheduler.createTimer,
      );

      final timer = scheduler.lastTimer;

      expect(timer, isNotNull);

      expect(timer!.isActive, isTrue);

      viewModel.dispose();

      expect(timer.isActive, isFalse);
    });
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

class _FakeHomeOverviewRepository implements HomeOverviewRepository {
  @override
  Future<HomeDayOverview> recoverDayOverview({
    required String anonymousId,
    required DateTime localDate,
  }) async {
    return HomeDayOverview(date: localDate, areas: const {});
  }
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
