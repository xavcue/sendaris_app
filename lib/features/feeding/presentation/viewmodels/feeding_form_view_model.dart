import 'package:flutter/foundation.dart';

import '../../domain/exceptions/feeding_failure.dart';
import '../../domain/exceptions/feeding_validation_failure.dart';
import '../../domain/models/feeding_category.dart';
import '../../domain/repositories/feeding_repository.dart';
import '../../domain/services/feeding_record_factory.dart';

class FeedingFormViewModel extends ChangeNotifier {
  FeedingFormViewModel(
    this._repository,
    this._recordFactory, {
    required this.anonymousId,
    DateTime? initialDate,
  }) : _selectedDate = _dateOnly(initialDate ?? DateTime.now());

  final FeedingRepository _repository;
  final FeedingRecordFactory _recordFactory;

  final String anonymousId;

  DateTime _selectedDate;
  FeedingCategory? _selectedCategory;

  bool _isSaving = false;

  String? _errorMessage;
  String? _successMessage;

  Map<String, String> _fieldErrors = const {};

  DateTime get selectedDate => _selectedDate;

  FeedingCategory? get selectedCategory => _selectedCategory;

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

  void setCategory(FeedingCategory category) {
    _selectedCategory = category;

    _removeFieldError('category');

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

    final category = _selectedCategory;

    if (category == null) {
      _fieldErrors = {
        ..._fieldErrors,
        'category': 'Selecciona una categoría de alimentación.',
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
        category: category!,
        observation: observation,
      );

      await _repository.saveFeeding(record);

      _successMessage = 'Registro de alimentación guardado correctamente.';

      _prepareNextRecord();

      return true;
    } on FeedingValidationFailure catch (failure) {
      _fieldErrors = failure.fieldErrors;

      return false;
    } on FeedingFailure catch (failure) {
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible guardar el registro de alimentación. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  void _prepareNextRecord() {
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

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
