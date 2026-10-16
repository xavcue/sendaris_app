import 'package:flutter/foundation.dart';

import '../../domain/exceptions/routine_compliance_failure.dart';
import '../../domain/exceptions/routine_compliance_query_validation_failure.dart';
import '../../domain/repositories/routine_compliance_repository.dart';
import '../../domain/services/routine_overview_service.dart';

enum RoutineOverviewPeriod { sevenDays, thisMonth, thirtyDays, custom }

class RoutineOverviewViewModel extends ChangeNotifier {
  RoutineOverviewViewModel(
    this._repository, {
    required this.anonymousId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    final today = _dateOnly(_clock());

    _startDate = DateTime(today.year, today.month);
    _endDate = today;
  }

  final RoutineComplianceRepository _repository;
  final DateTime Function() _clock;

  final String anonymousId;

  late DateTime _startDate;
  late DateTime _endDate;

  RoutineOverviewPeriod _selectedPeriod = RoutineOverviewPeriod.thisMonth;

  RoutineOverview? _overview;
  String? _errorMessage;

  bool _isLoading = false;
  bool _disposed = false;

  int _requestVersion = 0;

  DateTime get startDate => _startDate;

  DateTime get endDate => _endDate;

  RoutineOverviewPeriod get selectedPeriod => _selectedPeriod;

  RoutineOverview? get overview => _overview;

  String? get errorMessage => _errorMessage;

  bool get isLoading => _isLoading;

  bool get isDisposed => _disposed;

  bool get hasRecords => _overview?.hasRecords ?? false;

  int get totalRecords => _overview?.totalRecords ?? 0;

  int get completedCount => _overview?.completedCount ?? 0;

  double? get compliancePercentage => _overview?.compliancePercentage;

  Future<void> selectPeriod(RoutineOverviewPeriod period) {
    if (_disposed || _selectedPeriod == period) {
      return Future<void>.value();
    }

    if (period == RoutineOverviewPeriod.custom) {
      _selectedPeriod = period;
      notifyListeners();

      return Future<void>.value();
    }

    final today = _dateOnly(_clock());

    final startDate = switch (period) {
      RoutineOverviewPeriod.sevenDays => DateTime(
        today.year,
        today.month,
        today.day - 6,
      ),
      RoutineOverviewPeriod.thisMonth => DateTime(today.year, today.month),
      RoutineOverviewPeriod.thirtyDays => DateTime(
        today.year,
        today.month,
        today.day - 29,
      ),
      RoutineOverviewPeriod.custom => _startDate,
    };

    _selectedPeriod = period;
    _startDate = startDate;
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

    _selectedPeriod = RoutineOverviewPeriod.custom;

    return load();
  }

  Future<void> load() async {
    if (_disposed) {
      return;
    }

    final request = ++_requestVersion;
    final expectedAnonymousId = anonymousId.trim();

    final startDate = _startDate;
    final endDate = _endDate;

    _isLoading = true;
    _overview = null;
    _errorMessage = null;

    notifyListeners();

    try {
      final result = await RoutineOverviewService(_repository).load(
        anonymousId: expectedAnonymousId,
        startDate: startDate,
        endDate: endDate,
      );

      if (!_isRequestCurrent(request)) {
        return;
      }

      if (result.anonymousId != expectedAnonymousId) {
        _showError(request, 'No fue posible validar el seguimiento actual.');
        return;
      }

      _overview = result;
      _errorMessage = null;
      _isLoading = false;

      notifyListeners();
    } on RoutineComplianceQueryValidationFailure catch (failure) {
      _showError(
        request,
        failure.fieldErrors['period'] ??
            failure.fieldErrors['anonymousId'] ??
            failure.message,
      );
    } on RoutineComplianceFailure catch (failure) {
      _showError(request, failure.message);
    } catch (_) {
      _showError(
        request,
        'No fue posible recuperar los estados de rutina. '
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
    return !_disposed && _requestVersion == request;
  }

  static DateTime _dateOnly(DateTime date) {
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
