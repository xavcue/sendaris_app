import 'package:flutter/foundation.dart';

import '../../domain/exceptions/atypical_situation_failure.dart';
import '../../domain/exceptions/atypical_situation_validation_failure.dart';
import '../../domain/models/atypical_situation_category.dart';
import '../../domain/models/atypical_situation_record.dart';
import '../../domain/repositories/atypical_situation_management_repository.dart';
import '../../domain/repositories/atypical_situation_repository.dart';
import '../../domain/services/atypical_situation_record_factory.dart';

class AtypicalSituationFormViewModel extends ChangeNotifier {
  AtypicalSituationFormViewModel(
    this._repository,
    this._recordFactory, {
    required String anonymousId,
    DateTime? initialDate,
    AtypicalSituationRecord? initialRecord,
  }) : _anonymousId = anonymousId.trim(),
       _initialRecord = initialRecord,
       _selectedDate = initialRecord != null
           ? _normalizeDate(initialRecord.date)
           : initialDate == null
           ? null
           : _normalizeDate(initialDate),
       _selectedCategory = initialRecord?.category;

  final AtypicalSituationRepository _repository;
  final AtypicalSituationRecordFactory _recordFactory;

  final String _anonymousId;
  final AtypicalSituationRecord? _initialRecord;

  DateTime? _selectedDate;
  AtypicalSituationCategory? _selectedCategory;

  bool _isSaving = false;

  String? _errorMessage;
  String? _successMessage;

  Map<String, String> _fieldErrors = const {};

  DateTime? get selectedDate => _selectedDate;

  AtypicalSituationCategory? get selectedCategory => _selectedCategory;

  bool get isSaving => _isSaving;

  bool get isEditing => _initialRecord != null;

  String get initialObservation => _initialRecord?.observation ?? '';

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);

  String? errorFor(String field) {
    return _fieldErrors[field];
  }

  void selectDate(DateTime date) {
    _selectedDate = _normalizeDate(date);

    _removeFieldError('date');

    _clearGeneralMessages();

    notifyListeners();
  }

  void selectCategory(AtypicalSituationCategory category) {
    if (_selectedCategory == category) {
      _selectedCategory = null;
    } else {
      _selectedCategory = category;

      _removeFieldError('category');
    }

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

    final date = _selectedDate;
    final category = _selectedCategory;
    final normalizedObservation = observation.trim();

    if (date == null) {
      _fieldErrors = {..._fieldErrors, 'date': 'Selecciona una fecha.'};
    }

    if (category == null) {
      _fieldErrors = {
        ..._fieldErrors,
        'category': 'Selecciona una categoría para continuar.',
      };
    }

    if (normalizedObservation.isEmpty) {
      _fieldErrors = {
        ..._fieldErrors,
        'observation': 'Describe brevemente lo ocurrido.',
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

      if (currentRecord == null) {
        final record = _recordFactory.create(
          anonymousId: _anonymousId,
          date: date!,
          category: category!,
          observation: normalizedObservation,
        );

        await _repository.saveAtypicalSituation(record);

        _successMessage = 'Situación guardada correctamente.';

        _prepareNextRecord();

        return true;
      }

      final managementRepository = _repository;

      if (managementRepository is! AtypicalSituationManagementRepository) {
        _errorMessage =
            'No fue posible actualizar el registro '
            'de otra situación. '
            'Inténtalo nuevamente.';

        return false;
      }

      final updatedRecord = _recordFactory.update(
        currentRecord: currentRecord,
        date: date!,
        category: category!,
        observation: normalizedObservation,
      );

      await managementRepository.updateAtypicalSituation(updatedRecord);

      _successMessage =
          'Registro de otra situación '
          'actualizado correctamente.';

      return true;
    } on AtypicalSituationValidationFailure catch (failure) {
      _fieldErrors = failure.fieldErrors;

      return false;
    } on AtypicalSituationFailure catch (failure) {
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _errorMessage = isEditing
          ? 'No fue posible actualizar el registro '
                'de otra situación. '
                'Inténtalo nuevamente.'
          : 'No fue posible guardar la situación. '
                'Inténtalo nuevamente.';

      return false;
    } finally {
      _isSaving = false;

      notifyListeners();
    }
  }

  void _prepareNextRecord() {
    _selectedDate = null;
    _selectedCategory = null;
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

  static DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
