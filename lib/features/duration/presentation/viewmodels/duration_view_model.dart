import 'package:flutter/foundation.dart';

import '../../domain/exceptions/duration_failure.dart';
import '../../domain/exceptions/duration_query_validation_failure.dart';
import '../../domain/models/duration_metric_type.dart';
import '../../domain/models/duration_observation.dart';
import '../../domain/models/duration_query.dart';
import '../../domain/models/duration_result.dart';
import '../../domain/repositories/duration_repository.dart';
import '../../domain/services/duration_calculator.dart';
import '../../domain/validation/duration_query_validator.dart';

class DurationViewModel extends ChangeNotifier {
  DurationViewModel(this._repository, {required this.anonymousId});

  final DurationRepository _repository;

  final String anonymousId;

  DurationMetricType? _selectedMetricType;

  DateTime? _startDate;

  DateTime? _endDate;

  DurationResult? _result;

  bool _isCalculating = false;

  String? _errorMessage;

  Map<String, String> _fieldErrors = const {};

  DurationMetricType? get selectedMetricType => _selectedMetricType;

  DateTime? get startDate => _startDate;

  DateTime? get endDate => _endDate;

  DurationResult? get result => _result;

  bool get isCalculating => _isCalculating;

  String? get errorMessage => _errorMessage;

  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);

  bool get hasFieldErrors => _fieldErrors.isNotEmpty;

  bool get hasResult => _result != null;

  bool get hasSufficientData => _result?.hasSufficientData ?? false;

  bool get hasInsufficientData =>
      _result != null && !_result!.hasSufficientData;

  double? get averageMinutes => _result?.averageMinutes;

  int get validRecordCount => _result?.validRecordCount ?? 0;

  List<DurationObservation> get validObservations =>
      _result?.observations ?? const [];

  String? errorFor(String field) {
    return _fieldErrors[field];
  }

  void setMetricType(DurationMetricType metricType) {
    if (_selectedMetricType == metricType) {
      return;
    }

    _selectedMetricType = metricType;

    _removeFieldError('metricType');

    _clearGeneralError();
    _invalidateResult();

    notifyListeners();
  }

  void setStartDate(DateTime date) {
    _startDate = _dateOnly(date);

    _removeFieldError('period');

    _clearGeneralError();
    _invalidateResult();

    notifyListeners();
  }

  void setEndDate(DateTime date) {
    _endDate = _dateOnly(date);

    _removeFieldError('period');

    _clearGeneralError();
    _invalidateResult();

    notifyListeners();
  }

  Future<bool> calculate() async {
    if (_isCalculating) {
      return false;
    }

    _fieldErrors = const {};
    _errorMessage = null;

    final metricType = _selectedMetricType;

    if (metricType == null) {
      _fieldErrors = const {'metricType': 'Selecciona un tipo de duración.'};

      _result = null;

      notifyListeners();

      return false;
    }

    final validationErrors = Map<String, String>.from(
      DurationQueryValidator.validate(
        anonymousId: anonymousId,
        metricType: metricType,
        startDate: _startDate,
        endDate: _endDate,
      ),
    );

    final profileError = validationErrors.remove('anonymousId');

    if (profileError != null) {
      _errorMessage = profileError;
    }

    if (validationErrors.isNotEmpty) {
      _fieldErrors = Map.unmodifiable(validationErrors);
    }

    if (profileError != null || validationErrors.isNotEmpty) {
      _result = null;

      notifyListeners();

      return false;
    }

    final currentStartDate = _startDate;

    final currentEndDate = _endDate;

    if (currentStartDate == null || currentEndDate == null) {
      _fieldErrors = const {
        'period': 'Selecciona una fecha inicial y una fecha final.',
      };

      _result = null;

      notifyListeners();

      return false;
    }

    _isCalculating = true;
    _result = null;

    notifyListeners();

    try {
      final query = DurationQuery.create(
        anonymousId: anonymousId,
        metricType: metricType,
        startDate: currentStartDate,
        endDate: currentEndDate,
      );

      final observations = await _repository.recoverObservations(
        anonymousId: anonymousId,
        metricType: metricType,
      );

      _result = DurationCalculator.calculate(
        query: query,
        observations: observations,
      );

      return true;
    } on DurationQueryValidationFailure catch (failure) {
      _fieldErrors = Map.unmodifiable(failure.fieldErrors);

      return false;
    } on DurationFailure catch (failure) {
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible calcular las duraciones. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _isCalculating = false;

      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;

    notifyListeners();
  }

  void _invalidateResult() {
    _result = null;
  }

  void _clearGeneralError() {
    _errorMessage = null;
  }

  void _removeFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) {
      return;
    }

    final updated = Map<String, String>.from(_fieldErrors);

    updated.remove(field);

    _fieldErrors = Map.unmodifiable(updated);
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
