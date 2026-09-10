import 'package:flutter/foundation.dart';

import '../../domain/exceptions/sleep_failure.dart';
import '../../domain/exceptions/sleep_validation_failure.dart';
import '../../domain/repositories/sleep_repository.dart';
import '../../domain/services/sleep_duration_calculator.dart';
import '../../domain/services/sleep_record_factory.dart';

class SleepFormViewModel extends ChangeNotifier {
  SleepFormViewModel(
    this._repository,
    this._recordFactory, {
    required this.anonymousId,
    DateTime? initialDate,
  }) : _selectedDate = _dateOnly(initialDate ?? DateTime.now());

  final SleepRepository _repository;
  final SleepRecordFactory _recordFactory;

  final String anonymousId;

  DateTime _selectedDate;

  String? _startTime;
  String? _endTime;

  bool _isSaving = false;

  String? _errorMessage;
  String? _successMessage;

  Map<String, String> _fieldErrors = const {};

  DateTime get selectedDate => _selectedDate;

  String? get startTime => _startTime;

  String? get endTime => _endTime;

  bool get isSaving => _isSaving;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);

  int? get durationMinutes {
    final startTime = _startTime;
    final endTime = _endTime;

    if (startTime == null || endTime == null) {
      return null;
    }

    try {
      return SleepDurationCalculator.calculate(
        startTime: startTime,
        endTime: endTime,
      );
    } on ArgumentError {
      return null;
    }
  }

  String? get formattedDuration {
    final minutes = durationMinutes;

    if (minutes == null) {
      return null;
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours == 0) {
      return '$remainingMinutes min';
    }

    if (remainingMinutes == 0) {
      return '$hours h';
    }

    return '$hours h $remainingMinutes min';
  }

  String? errorFor(String field) {
    return _fieldErrors[field];
  }

  void setDate(DateTime date) {
    _selectedDate = _dateOnly(date);

    _clearGeneralMessages();

    notifyListeners();
  }

  void setStartTime({required int hour, required int minute}) {
    _startTime = _formatTime(hour: hour, minute: minute);

    _removeFieldError('startTime');

    _removeEqualTimesErrorIfResolved();

    _clearGeneralMessages();

    notifyListeners();
  }

  void setEndTime({required int hour, required int minute}) {
    _endTime = _formatTime(hour: hour, minute: minute);

    _removeFieldError('endTime');

    _removeEqualTimesErrorIfResolved();

    _clearGeneralMessages();

    notifyListeners();
  }

  Future<bool> save({required String observation}) async {
    if (_isSaving) {
      return false;
    }

    _fieldErrors = {};
    _errorMessage = null;
    _successMessage = null;

    final startTime = _startTime;
    final endTime = _endTime;

    if (startTime == null) {
      _fieldErrors = {
        ..._fieldErrors,
        'startTime': 'Selecciona la hora de inicio.',
      };
    }

    if (endTime == null) {
      _fieldErrors = {
        ..._fieldErrors,
        'endTime': 'Selecciona la hora de finalización.',
      };
    }

    if (_fieldErrors.isNotEmpty) {
      notifyListeners();
      return false;
    }

    _isSaving = true;
    notifyListeners();

    try {
      final record = _recordFactory.create(
        anonymousId: anonymousId,
        date: _selectedDate,
        startTime: startTime!,
        endTime: endTime!,
        observation: observation,
      );

      await _repository.saveSleep(record);

      _successMessage = 'Registro de sueño guardado correctamente.';

      _prepareNextRecord();

      return true;
    } on SleepValidationFailure catch (failure) {
      _fieldErrors = failure.fieldErrors;

      return false;
    } on SleepFailure catch (failure) {
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible guardar el registro de sueño. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _prepareNextRecord() {
    _startTime = null;
    _endTime = null;
    _fieldErrors = {};
  }

  void _removeEqualTimesErrorIfResolved() {
    final startTime = _startTime;
    final endTime = _endTime;

    if (startTime == null || endTime == null || startTime == endTime) {
      return;
    }

    _removeFieldError('endTime');
  }

  void _removeFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) {
      return;
    }

    final updatedErrors = Map<String, String>.from(_fieldErrors);

    updatedErrors.remove(field);

    _fieldErrors = Map.unmodifiable(updatedErrors);
  }

  void _clearGeneralMessages() {
    _errorMessage = null;
    _successMessage = null;
  }

  static String _formatTime({required int hour, required int minute}) {
    return '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
