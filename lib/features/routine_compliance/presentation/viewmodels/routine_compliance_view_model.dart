import 'package:flutter/foundation.dart';

import '../../domain/exceptions/routine_compliance_failure.dart';
import '../../domain/exceptions/routine_compliance_query_validation_failure.dart';
import '../../domain/models/routine_compliance_entry.dart';
import '../../domain/models/routine_compliance_query.dart';
import '../../domain/models/routine_compliance_result.dart';
import '../../domain/repositories/routine_compliance_repository.dart';
import '../../domain/services/routine_compliance_calculator.dart';
import '../../domain/validation/routine_compliance_query_validator.dart';

class RoutineComplianceViewModel extends ChangeNotifier {
  RoutineComplianceViewModel(this._repository, {required this.anonymousId});

  final RoutineComplianceRepository _repository;

  final String anonymousId;

  DateTime? _startDate;

  DateTime? _endDate;

  RoutineComplianceResult? _result;

  bool _isCalculating = false;

  String? _errorMessage;

  Map<String, String> _fieldErrors = const {};

  DateTime? get startDate => _startDate;

  DateTime? get endDate => _endDate;

  RoutineComplianceResult? get result => _result;

  bool get isCalculating => _isCalculating;

  String? get errorMessage => _errorMessage;

  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);

  bool get hasFieldErrors => _fieldErrors.isNotEmpty;

  bool get hasResult => _result != null;

  bool get hasProgrammedRoutines => _result?.hasProgrammedRoutines ?? false;

  bool get hasNoProgrammedRoutines =>
      _result != null && !_result!.hasProgrammedRoutines;

  bool get hasPercentage => _result?.hasPercentage ?? false;

  int get programmedCount => _result?.programmedCount ?? 0;

  int get completedCount => _result?.completedCount ?? 0;

  double? get compliancePercentage => _result?.compliancePercentage;

  List<RoutineComplianceEntry> get entries => _result?.entries ?? const [];

  String? errorFor(String field) {
    return _fieldErrors[field];
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

    final validationErrors = Map<String, String>.from(
      RoutineComplianceQueryValidator.validate(
        anonymousId: anonymousId,
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
      final query = RoutineComplianceQuery.create(
        anonymousId: anonymousId,
        startDate: currentStartDate,
        endDate: currentEndDate,
      );

      final sourceEntries = await _repository.recoverEntries(
        anonymousId: anonymousId,
      );

      _result = RoutineComplianceCalculator.calculate(
        query: query,
        entries: sourceEntries,
      );

      return true;
    } on RoutineComplianceQueryValidationFailure catch (failure) {
      final validationErrors = Map<String, String>.from(failure.fieldErrors);

      final profileError = validationErrors.remove('anonymousId');

      if (profileError != null) {
        _errorMessage = profileError;
      }

      _fieldErrors = Map.unmodifiable(validationErrors);

      return false;
    } on RoutineComplianceFailure catch (failure) {
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible calcular el cumplimiento '
          'de rutinas. Inténtalo nuevamente.';

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
