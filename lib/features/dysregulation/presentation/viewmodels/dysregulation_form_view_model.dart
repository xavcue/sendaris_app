import 'package:flutter/foundation.dart';

import '../../domain/exceptions/dysregulation_failure.dart';
import '../../domain/exceptions/dysregulation_validation_failure.dart';
import '../../domain/models/dysregulation_intensity.dart';
import '../../domain/repositories/dysregulation_repository.dart';
import '../../domain/services/dysregulation_record_factory.dart';

class DysregulationFormViewModel extends ChangeNotifier {
  DysregulationFormViewModel(
    this._repository,
    this._recordFactory, {
    required this.anonymousId,
    DateTime? initialDate,
  }) : _selectedDate = _dateOnly(initialDate ?? DateTime.now());

  final DysregulationRepository _repository;
  final DysregulationRecordFactory _recordFactory;

  final String anonymousId;

  DateTime _selectedDate;
  String? _selectedTime;
  DysregulationIntensity? _selectedIntensity;

  bool _isSaving = false;

  String? _errorMessage;
  String? _successMessage;

  Map<String, String> _fieldErrors = const {};

  DateTime get selectedDate => _selectedDate;

  String? get selectedTime => _selectedTime;

  DysregulationIntensity? get selectedIntensity => _selectedIntensity;

  bool get isSaving => _isSaving;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);

  String? errorFor(String field) {
    return _fieldErrors[field];
  }

  void setDate(DateTime date) {
    _selectedDate = _dateOnly(date);

    _clearGeneralMessages();

    notifyListeners();
  }

  void setTime({required int hour, required int minute}) {
    _selectedTime =
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';

    _removeFieldError('time');
    _clearGeneralMessages();

    notifyListeners();
  }

  void clearTime() {
    if (_selectedTime == null) {
      return;
    }

    _selectedTime = null;

    _removeFieldError('time');
    _clearGeneralMessages();

    notifyListeners();
  }

  void validateDurationCorrection(String value) {
    if (!_fieldErrors.containsKey('durationMinutes')) {
      return;
    }

    final normalizedDuration = value.trim();

    final updatedErrors = Map<String, String>.from(_fieldErrors);

    if (normalizedDuration.isEmpty) {
      updatedErrors.remove('durationMinutes');
    } else {
      final durationMinutes = int.tryParse(normalizedDuration);

      if (durationMinutes == null) {
        updatedErrors['durationMinutes'] =
            'Ingresa la duración usando '
            'solo números enteros.';
      } else if (durationMinutes < 0) {
        updatedErrors['durationMinutes'] = 'La duración no puede ser negativa.';
      } else {
        updatedErrors.remove('durationMinutes');
      }
    }

    _fieldErrors = Map.unmodifiable(updatedErrors);

    _clearGeneralMessages();

    notifyListeners();
  }

  void setIntensity(DysregulationIntensity intensity) {
    if (_selectedIntensity == intensity) {
      _selectedIntensity = null;
    } else {
      _selectedIntensity = intensity;
    }

    _clearGeneralMessages();

    notifyListeners();
  }

  Future<bool> save({
    required String durationText,
    required String context,
    required String observation,
  }) async {
    if (_isSaving) {
      return false;
    }

    _fieldErrors = {};
    _errorMessage = null;
    _successMessage = null;

    final normalizedDuration = durationText.trim();

    int? durationMinutes;

    if (normalizedDuration.isNotEmpty) {
      durationMinutes = int.tryParse(normalizedDuration);

      if (durationMinutes == null) {
        _fieldErrors = {
          ..._fieldErrors,
          'durationMinutes':
              'Ingresa la duración usando '
              'solo números enteros.',
        };
      }
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
        time: _selectedTime,
        durationMinutes: durationMinutes,
        intensity: _selectedIntensity,
        context: context,
        observation: observation,
      );

      await _repository.saveDysregulation(record);

      _successMessage = 'Episodio de desregulación guardado correctamente.';

      _prepareNextRecord();

      return true;
    } on DysregulationValidationFailure catch (failure) {
      _fieldErrors = failure.fieldErrors;

      return false;
    } on DysregulationFailure catch (failure) {
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible guardar el episodio '
          'de desregulación. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _isSaving = false;

      notifyListeners();
    }
  }

  void _prepareNextRecord() {
    _selectedTime = null;
    _selectedIntensity = null;
    _fieldErrors = {};
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

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
