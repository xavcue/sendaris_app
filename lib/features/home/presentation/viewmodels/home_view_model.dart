import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/exceptions/home_overview_failure.dart';
import '../../domain/models/home_day_overview.dart';
import '../../domain/repositories/home_overview_repository.dart';
import '../../domain/services/home_clock.dart';
import '../../domain/services/home_temporal_context.dart';

typedef HomeTimerFactory = Timer Function(
  Duration duration,
  void Function() callback,
);

class HomeViewModel extends ChangeNotifier {
  factory HomeViewModel({
    required HomeClock clock,
    required HomeOverviewRepository overviewRepository,
    HomeTimerFactory? timerFactory,
  }) {
    return HomeViewModel._(
      clock,
      overviewRepository,
      timerFactory ?? _createTimer,
    );
  }

  HomeViewModel._(this._clock, this._overviewRepository, this._timerFactory) {
    _localDateTime = _clock.now();

    _scheduleNextTemporalRefresh();
  }

  final HomeClock _clock;

  final HomeOverviewRepository _overviewRepository;

  final HomeTimerFactory _timerFactory;

  late DateTime _localDateTime;

  Timer? _temporalTimer;

  String? _activeAnonymousId;

  HomeDayOverview? _overview;

  DateTime? _lastUpdatedAt;

  String? _errorMessage;

  bool _isRefreshing = false;

  int _requestVersion = 0;

  bool _isDisposed = false;

  DateTime get localDateTime => _localDateTime;

  DateTime get localDate {
    return HomeTemporalContext.localDateFor(_localDateTime);
  }

  HomeGreetingPeriod get greetingPeriod {
    return HomeTemporalContext.greetingPeriodFor(_localDateTime);
  }

  String get greeting {
    return HomeTemporalContext.greetingFor(_localDateTime);
  }

  String? get activeAnonymousId => _activeAnonymousId;

  HomeDayOverview? get overview => _overview;

  DateTime? get lastUpdatedAt => _lastUpdatedAt;

  String? get errorMessage => _errorMessage;

  bool get isRefreshing => _isRefreshing;

  bool get hasOverview => _overview != null;

  bool get hasActivity => _overview?.hasActivity ?? false;

  Future<void> setActiveTracking(String? anonymousId) async {
    final normalizedAnonymousId = _normalizeAnonymousId(anonymousId);

    if (_activeAnonymousId == normalizedAnonymousId) {
      return;
    }

    _activeAnonymousId = normalizedAnonymousId;

    _invalidateOverviewForContextChange();

    _notifySafely();

    if (normalizedAnonymousId == null) {
      return;
    }

    await _recoverOverviewFor(normalizedAnonymousId);
  }

  Future<bool> refreshOverview() async {
    final anonymousId = _activeAnonymousId;

    if (anonymousId == null || _isRefreshing) {
      return false;
    }

    return _recoverOverviewFor(anonymousId);
  }

  void handleAppResumed() {
    _refreshTemporalContext(refreshOverviewWhenDateIsUnchanged: true);
  }

  void refreshTemporalContext() {
    _refreshTemporalContext(refreshOverviewWhenDateIsUnchanged: false);
  }

  void _refreshTemporalContext({
    required bool refreshOverviewWhenDateIsUnchanged,
  }) {
    final previousDateTime = _localDateTime;

    _localDateTime = _clock.now();

    _scheduleNextTemporalRefresh();

    final previousDate = HomeTemporalContext.localDateFor(previousDateTime);
    final currentDate = HomeTemporalContext.localDateFor(_localDateTime);

    final previousGreeting = HomeTemporalContext.greetingPeriodFor(
      previousDateTime,
    );

    final currentGreeting = HomeTemporalContext.greetingPeriodFor(
      _localDateTime,
    );

    final dateChanged = previousDate != currentDate;

    final greetingChanged = previousGreeting != currentGreeting;

    if (dateChanged) {
      final anonymousId = _activeAnonymousId;

      _invalidateOverviewForContextChange();

      _notifySafely();

      if (anonymousId != null) {
        unawaited(_recoverOverviewFor(anonymousId));
      }

      return;
    }

    if (greetingChanged) {
      _notifySafely();
    }

    if (refreshOverviewWhenDateIsUnchanged &&
        _activeAnonymousId != null &&
        !_isRefreshing) {
      unawaited(refreshOverview());
    }
  }

  Future<bool> _recoverOverviewFor(String anonymousId) async {
    final requestedDate = localDate;

    final requestVersion = ++_requestVersion;

    _isRefreshing = true;

    _errorMessage = null;

    _notifySafely();

    try {
      final recoveredOverview = await _overviewRepository.recoverDayOverview(
        anonymousId: anonymousId,
        localDate: requestedDate,
      );

      if (!_isCurrentRequest(
        requestVersion: requestVersion,
        anonymousId: anonymousId,
      )) {
        return false;
      }

      if (!_isSameDay(recoveredOverview.date, requestedDate)) {
        _errorMessage =
            'No fue posible actualizar correctamente el panorama de hoy.';

        return false;
      }

      _overview = recoveredOverview;

      _lastUpdatedAt = _clock.now();

      _errorMessage = null;

      return true;
    } on HomeOverviewFailure catch (failure) {
      if (_isCurrentRequest(
        requestVersion: requestVersion,
        anonymousId: anonymousId,
      )) {
        _errorMessage = failure.message;
      }

      return false;
    } catch (_) {
      if (_isCurrentRequest(
        requestVersion: requestVersion,
        anonymousId: anonymousId,
      )) {
        _errorMessage =
            'No fue posible actualizar el panorama de hoy. '
            'Inténtalo nuevamente.';
      }

      return false;
    } finally {
      if (_isCurrentRequest(
        requestVersion: requestVersion,
        anonymousId: anonymousId,
      )) {
        _isRefreshing = false;

        _notifySafely();
      }
    }
  }

  bool _isCurrentRequest({
    required int requestVersion,
    required String anonymousId,
  }) {
    return !_isDisposed &&
        requestVersion == _requestVersion &&
        anonymousId == _activeAnonymousId;
  }

  void _invalidateOverviewForContextChange() {
    _requestVersion += 1;

    _isRefreshing = false;

    _overview = null;

    _lastUpdatedAt = null;

    _errorMessage = null;
  }

  void _scheduleNextTemporalRefresh() {
    _temporalTimer?.cancel();

    final nextBoundary = HomeTemporalContext.nextTemporalBoundaryAfter(
      _localDateTime,
    );

    var duration = nextBoundary.difference(_localDateTime);

    if (duration <= Duration.zero) {
      duration = const Duration(milliseconds: 1);
    }

    _temporalTimer = _timerFactory(duration, _handleTemporalBoundaryReached);
  }

  void _handleTemporalBoundaryReached() {
    _temporalTimer = null;

    _refreshTemporalContext(refreshOverviewWhenDateIsUnchanged: false);
  }

  String? _normalizeAnonymousId(String? anonymousId) {
    final normalized = anonymousId?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  void _notifySafely() {
    if (_isDisposed) {
      return;
    }

    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;

    _requestVersion += 1;

    _temporalTimer?.cancel();

    super.dispose();
  }

  static Timer _createTimer(Duration duration, void Function() callback) {
    return Timer(duration, callback);
  }
}
