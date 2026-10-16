import 'package:flutter/foundation.dart';

import '../../domain/exceptions/duration_failure.dart';
import '../../domain/exceptions/duration_query_validation_failure.dart';
import '../../domain/repositories/duration_repository.dart';
import '../../domain/services/duration_overview_service.dart';

enum DurationPeriod { sevenDays, thisMonth, thirtyDays, custom }

class DurationOverviewViewModel extends ChangeNotifier {
  DurationOverviewViewModel(
    this._repository, {
    required this.anonymousId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    _setInitialPeriod();
  }

  final DurationRepository _repository;
  final DateTime Function() _clock;

  final String anonymousId;

  late DateTime _startDate;
  late DateTime _endDate;

  DurationPeriod _selectedPeriod = DurationPeriod.thisMonth;

  DurationOverview? _overview;
  String? _errorMessage;

  bool _isLoading = false;
  bool _disposed = false;

  int _requestVersion = 0;

  DateTime get startDate => _startDate;
  DateTime get endDate => _endDate;

  DurationPeriod get selectedPeriod => _selectedPeriod;

  DurationOverview? get overview => _overview;

  String? get errorMessage => _errorMessage;

  bool get isLoading => _isLoading;
  bool get isDisposed => _disposed;

  bool get hasData => _overview?.hasAnyData ?? false;

  void _setInitialPeriod() {
    final now = _clock();
    final today = _dateOnly(now);

    _selectedPeriod = DurationPeriod.thisMonth;
    _startDate = DateTime(today.year, today.month);
    _endDate = today;
  }

  Future<void> selectPeriod(DurationPeriod period) {
    if (_disposed || _selectedPeriod == period) {
      return Future<void>.value();
    }

    if (period == DurationPeriod.custom) {
      _selectedPeriod = DurationPeriod.custom;
      notifyListeners();

      return Future<void>.value();
    }

    final today = _dateOnly(_clock());

    late final DateTime start;

    switch (period) {
      case DurationPeriod.sevenDays:
        start = DateTime(today.year, today.month, today.day - 6);

      case DurationPeriod.thisMonth:
        start = DateTime(today.year, today.month);

      case DurationPeriod.thirtyDays:
        start = DateTime(today.year, today.month, today.day - 29);

      case DurationPeriod.custom:
        return Future<void>.value();
    }

    _selectedPeriod = period;
    _startDate = start;
    _endDate = today;

    return load();
  }

  Future<void> setDate({required bool isStartDate, required DateTime date}) {
    if (_disposed) {
      return Future<void>.value();
    }

    final normalizedDate = _dateOnly(date);

    if (isStartDate) {
      _startDate = normalizedDate;

      if (_endDate.isBefore(_startDate)) {
        _endDate = _startDate;
      }
    } else {
      _endDate = normalizedDate;

      if (_startDate.isAfter(_endDate)) {
        _startDate = _endDate;
      }
    }

    _selectedPeriod = DurationPeriod.custom;

    return load();
  }

  Future<void> load() async {
    if (_disposed) {
      return;
    }

    final request = ++_requestVersion;

    final expectedId = anonymousId;
    final start = _startDate;
    final end = _endDate;

    _isLoading = true;
    _errorMessage = null;
    _overview = null;

    notifyListeners();

    try {
      final result = await DurationOverviewService(_repository)
          .load(anonymousId: expectedId, startDate: start, endDate: end);

      if (!_isRequestCurrent(request)) {
        return;
      }

      if (result.anonymousId != expectedId.trim()) {
        _showError(request, 'No fue posible validar el seguimiento actual.');
        return;
      }

      _overview = result;
      _errorMessage = null;
      _isLoading = false;

      notifyListeners();
    } on DurationQueryValidationFailure catch (failure) {
      _showError(
        request,
        failure.errorFor('period') ??
            failure.errorFor('anonymousId') ??
            failure.message,
      );
    } on DurationFailure catch (failure) {
      _showError(request, failure.message);
    } catch (_) {
      _showError(
        request,
        'No fue posible recuperar las duraciones. '
        'Comprueba tu conexión e inténtalo nuevamente.',
      );
    }
  }

  void _showError(int request, String message) {
    if (!_isRequestCurrent(request)) {
      return;
    }

    _isLoading = false;
    _overview = null;
    _errorMessage = message;

    notifyListeners();
  }

  bool _isRequestCurrent(int request) {
    return !_disposed && request == _requestVersion;
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _requestVersion++;

    super.dispose();
  }
}
