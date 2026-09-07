import 'package:flutter/foundation.dart';

import '../../domain/exceptions/atypical_situation_failure.dart';
import '../../domain/exceptions/atypical_situation_validation_failure.dart';
import '../../domain/models/atypical_situation_category.dart';
import '../../domain/repositories/atypical_situation_repository.dart';
import '../../domain/services/atypical_situation_record_factory.dart';

class AtypicalSituationFormViewModel extends ChangeNotifier {
  AtypicalSituationFormViewModel(
    this._repository,
    this._recordFactory, {
    required String anonymousId,
    DateTime? initialDate,
  }) : _anonymousId = anonymousId.trim(),
       _selectedDate = _normalizeDate(initialDate ?? DateTime.now());

  final AtypicalSituationRepository _repository;
  final AtypicalSituationRecordFactory _recordFactory;

  final String _anonymousId;

  DateTime _selectedDate;
  AtypicalSituationCategory? _selectedCategory;

  bool _isSaving = false;

  String? _errorMessage;

  Map<String, String> _fieldErrors = const {};

  DateTime get selectedDate => _selectedDate;

  AtypicalSituationCategory? get selectedCategory => _selectedCategory;

  bool get isSaving => _isSaving;

  String? get errorMessage => _errorMessage;

  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);

  String? errorFor(String field) {
    return _fieldErrors[field];
  }

  void selectDate(DateTime date) {
    _selectedDate = _normalizeDate(date);

    _clearGeneralError();

    notifyListeners();
  }

  void selectCategory(AtypicalSituationCategory category) {
    _selectedCategory = category;

    _removeFieldError('category');

    _clearGeneralError();

    notifyListeners();
  }

  Future<bool> save({required String observation}) async {
    if (_isSaving) {
      return false;
    }

    _fieldErrors = {};
    _errorMessage = null;

    final category = _selectedCategory;
    final normalizedObservation = observation.trim();

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
      final record = _recordFactory.create(
        anonymousId: _anonymousId,
        date: _selectedDate,
        category: category!,
        observation: normalizedObservation,
      );

      await _repository.saveAtypicalSituation(record);

      return true;
    } on AtypicalSituationValidationFailure catch (failure) {
      _fieldErrors = failure.fieldErrors;

      return false;
    } on AtypicalSituationFailure catch (failure) {
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible guardar la situación. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _isSaving = false;

      notifyListeners();
    }
  }

  void _removeFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) {
      return;
    }

    final updatedErrors = Map<String, String>.from(_fieldErrors);

    updatedErrors.remove(field);

    _fieldErrors = Map.unmodifiable(updatedErrors);
  }

  void _clearGeneralError() {
    _errorMessage = null;
  }

  static DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
