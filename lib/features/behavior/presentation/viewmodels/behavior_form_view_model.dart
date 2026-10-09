import 'package:flutter/foundation.dart';

import '../../domain/exceptions/behavior_failure.dart';
import '../../domain/exceptions/behavior_validation_failure.dart';
import '../../domain/models/behavior_category.dart';
import '../../domain/models/behavior_intensity.dart';
import '../../domain/models/behavior_record.dart';
import '../../domain/repositories/behavior_management_repository.dart';
import '../../domain/repositories/behavior_repository.dart';
import '../../domain/services/behavior_record_factory.dart';

class BehaviorFormViewModel extends ChangeNotifier {
  BehaviorFormViewModel(
    this._repository,
    this._recordFactory, {
    required this.anonymousId,
    DateTime? initialDate,
    BehaviorRecord? initialRecord,
  }) : _initialRecord = initialRecord,
       _selectedDate = initialRecord != null
           ? _dateOnly(initialRecord.date)
           : initialDate == null
           ? null
           : _dateOnly(initialDate),
       _selectedTime = initialRecord?.time,
       _selectedCategory = initialRecord?.category,
       _selectedIntensity = initialRecord?.intensity;

  final BehaviorRepository _repository;
  final BehaviorRecordFactory _recordFactory;

  final BehaviorRecord? _initialRecord;

  final String anonymousId;

  DateTime? _selectedDate;
  String? _selectedTime;
  BehaviorCategory? _selectedCategory;
  BehaviorIntensity? _selectedIntensity;

  bool _isSaving = false;

  String? _errorMessage;
  String? _successMessage;

  Map<String, String> _fieldErrors = const {};

  DateTime? get selectedDate => _selectedDate;

  String? get selectedTime => _selectedTime;

  BehaviorCategory? get selectedCategory => _selectedCategory;

  BehaviorIntensity? get selectedIntensity => _selectedIntensity;

  bool get isSaving => _isSaving;

  bool get isEditing => _initialRecord != null;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);

  String get initialDurationText {
    return _initialRecord?.durationMinutes?.toString() ?? '';
  }

  String get initialContext {
    return _initialRecord?.context ?? '';
  }

  String get initialObservation {
    return _initialRecord?.observation ?? '';
  }

  String? errorFor(String field) {
    return _fieldErrors[field];
  }

  void setDate(DateTime date) {
    _selectedDate = _dateOnly(date);

    _removeFieldError('date');
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

  void setCategory(BehaviorCategory category) {
    if (_selectedCategory == category) {
      _selectedCategory = null;
    } else {
      _selectedCategory = category;

      _removeFieldError('category');
    }

    _clearGeneralMessages();

    notifyListeners();
  }

  void setIntensity(BehaviorIntensity intensity) {
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

    final date = _selectedDate;

    if (date == null) {
      _fieldErrors = {..._fieldErrors, 'date': 'Selecciona una fecha.'};
    }

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

    final category = _selectedCategory;

    if (category == null) {
      _fieldErrors = {
        ..._fieldErrors,
        'category': 'Selecciona una categoría para continuar.',
      };
    }

    if (_fieldErrors.isNotEmpty) {
      notifyListeners();

      return false;
    }

    _isSaving = true;

    notifyListeners();

    try {
      final currentRecord = _initialRecord;

      if (currentRecord != null) {
        final managementRepository = _repository;

        if (managementRepository is! BehaviorManagementRepository) {
          _errorMessage =
              'No fue posible actualizar la conducta. '
              'Inténtalo nuevamente.';

          return false;
        }

        final updatedRecord = _recordFactory.update(
          currentRecord: currentRecord,
          date: date!,
          time: _selectedTime,
          category: category!,
          durationMinutes: durationMinutes,
          intensity: _selectedIntensity,
          context: context,
          observation: observation,
        );

        await managementRepository.updateBehavior(updatedRecord);

        _successMessage = 'Conducta actualizada correctamente.';

        return true;
      }

      final record = _recordFactory.create(
        anonymousId: anonymousId,
        date: date!,
        time: _selectedTime,
        category: category!,
        durationMinutes: durationMinutes,
        intensity: _selectedIntensity,
        context: context,
        observation: observation,
      );

      await _repository.saveBehavior(record);

      _successMessage = 'Conducta guardada correctamente.';

      _prepareNextRecord();

      return true;
    } on BehaviorValidationFailure catch (failure) {
      _fieldErrors = failure.fieldErrors;

      return false;
    } on BehaviorFailure catch (failure) {
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _errorMessage = isEditing
          ? 'No fue posible actualizar la conducta. '
                'Inténtalo nuevamente.'
          : 'No fue posible guardar la conducta. '
                'Inténtalo nuevamente.';

      return false;
    } finally {
      _isSaving = false;

      notifyListeners();
    }
  }

  void _prepareNextRecord() {
    _selectedDate = null;
    _selectedTime = null;
    _selectedCategory = null;
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
