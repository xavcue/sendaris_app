import 'package:flutter/foundation.dart';

import '../../domain/exceptions/frequency_failure.dart';
import '../../domain/exceptions/frequency_query_validation_failure.dart';
import '../../domain/models/frequency_category_option.dart';
import '../../domain/models/frequency_metric_type.dart';
import '../../domain/models/frequency_query.dart';
import '../../domain/models/frequency_result.dart';
import '../../domain/repositories/frequency_repository.dart';
import '../../domain/services/frequency_calculator.dart';
import '../../domain/validation/frequency_query_validator.dart';

class FrequencyViewModel extends ChangeNotifier {
  FrequencyViewModel(this._repository, {required this.anonymousId});

  final FrequencyRepository _repository;

  final String anonymousId;

  FrequencyMetricType? _selectedMetricType;

  DateTime? _startDate;

  DateTime? _endDate;

  String? _selectedCategoryCode;

  FrequencyResult? _result;

  bool _isCalculating = false;

  String? _errorMessage;

  Map<String, String> _fieldErrors = const {};

  FrequencyMetricType? get selectedMetricType => _selectedMetricType;

  DateTime? get startDate => _startDate;

  DateTime? get endDate => _endDate;

  String? get selectedCategoryCode => _selectedCategoryCode;

  FrequencyResult? get result => _result;

  bool get isCalculating => _isCalculating;

  String? get errorMessage => _errorMessage;

  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);

  bool get hasFieldErrors => _fieldErrors.isNotEmpty;

  bool get hasResult => _result != null;

  int? get resultCount => _result?.count;

  bool get isZeroResult => _result?.count == 0;

  List<FrequencyCategoryOption> get availableCategories {
    final metricType = _selectedMetricType;

    if (metricType == null) {
      return const [];
    }

    return metricType.categoryOptions;
  }

  bool get metricSupportsCategories =>
      _selectedMetricType?.supportsCategories ?? false;

  bool get metricRequiresCategory =>
      _selectedMetricType?.requiresCategory ?? false;

  String? get selectedCategoryLabel {
    final selectedCode = _selectedCategoryCode;

    if (selectedCode == null) {
      return null;
    }

    for (final option in availableCategories) {
      if (option.code == selectedCode) {
        return option.label;
      }
    }

    return null;
  }

  String? errorFor(String field) {
    return _fieldErrors[field];
  }

  void setMetricType(FrequencyMetricType metricType) {
    if (_selectedMetricType == metricType) {
      return;
    }

    _selectedMetricType = metricType;

    _selectedCategoryCode = null;

    _removeFieldError('metricType');

    _removeFieldError('category');

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

  void setCategoryCode(String? code) {
    final normalizedCode = code?.trim();

    _selectedCategoryCode = normalizedCode == null || normalizedCode.isEmpty
        ? null
        : normalizedCode;

    _removeFieldError('category');

    _clearGeneralError();
    _invalidateResult();

    notifyListeners();
  }

  void clearCategory() {
    if (_selectedCategoryCode == null) {
      return;
    }

    setCategoryCode(null);
  }

  Future<bool> calculate() async {
    if (_isCalculating) {
      return false;
    }

    _fieldErrors = const {};
    _errorMessage = null;

    final metricType = _selectedMetricType;

    if (metricType == null) {
      _fieldErrors = const {'metricType': 'Selecciona un tipo de frecuencia.'};

      _result = null;

      notifyListeners();

      return false;
    }

    final validationErrors = Map<String, String>.from(
      FrequencyQueryValidator.validate(
        anonymousId: anonymousId,
        metricType: metricType,
        startDate: _startDate,
        endDate: _endDate,
        categoryCode: _selectedCategoryCode,
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
      final query = FrequencyQuery.create(
        anonymousId: anonymousId,
        metricType: metricType,
        startDate: currentStartDate,
        endDate: currentEndDate,
        categoryCode: _selectedCategoryCode,
      );

      final events = await _repository.recoverEvents(
        anonymousId: anonymousId,
        metricType: metricType,
      );

      _result = FrequencyCalculator.calculate(query: query, events: events);

      return true;
    } on FrequencyQueryValidationFailure catch (failure) {
      _fieldErrors = Map.unmodifiable(failure.fieldErrors);

      return false;
    } on FrequencyFailure catch (failure) {
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible calcular la frecuencia. '
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
