import 'package:flutter/foundation.dart';

import '../../domain/exceptions/social_interaction_failure.dart';
import '../../domain/exceptions/social_interaction_validation_failure.dart';
import '../../domain/models/social_interaction_category.dart';
import '../../domain/models/social_interaction_record.dart';
import '../../domain/repositories/social_interaction_management_repository.dart';
import '../../domain/repositories/social_interaction_repository.dart';
import '../../domain/services/social_interaction_record_factory.dart';

class SocialInteractionFormViewModel extends ChangeNotifier {
  SocialInteractionFormViewModel(
    this._repository,
    this._recordFactory, {
    required this.anonymousId,
    DateTime? initialDate,
    SocialInteractionRecord? initialRecord,
  }) : _initialRecord = initialRecord,
       _selectedDate = initialRecord != null
           ? _dateOnly(initialRecord.date)
           : initialDate == null
           ? null
           : _dateOnly(initialDate),
       _selectedCategory = initialRecord?.category;

  final SocialInteractionRepository _repository;

  final SocialInteractionRecordFactory _recordFactory;

  final String anonymousId;

  final SocialInteractionRecord? _initialRecord;

  DateTime? _selectedDate;

  SocialInteractionCategory? _selectedCategory;

  bool _isSaving = false;

  String? _errorMessage;

  String? _successMessage;

  Map<String, String> _fieldErrors = const {};

  DateTime? get selectedDate => _selectedDate;

  SocialInteractionCategory? get selectedCategory => _selectedCategory;

  bool get isSaving => _isSaving;

  bool get isEditing => _initialRecord != null;

  String get initialContext => _initialRecord?.context ?? '';

  String get initialObservation => _initialRecord?.observation ?? '';

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);

  String? errorFor(String field) {
    return _fieldErrors[field];
  }

  void setDate(DateTime date) {
    _selectedDate = _dateOnly(date);

    _removeFieldError('date');

    _clearGeneralMessages();

    notifyListeners();
  }

  void setCategory(SocialInteractionCategory category) {
    if (_selectedCategory == category) {
      _selectedCategory = null;
    } else {
      _selectedCategory = category;

      _removeFieldError('category');
    }

    _clearGeneralMessages();

    notifyListeners();
  }

  Future<bool> save({
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
    final category = _selectedCategory;

    if (date == null) {
      _fieldErrors = {..._fieldErrors, 'date': 'Selecciona una fecha.'};
    }

    if (category == null) {
      _fieldErrors = {
        ..._fieldErrors,
        'category': 'Selecciona una categoría de interacción social.',
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
          anonymousId: anonymousId,
          date: date!,
          category: category!,
          context: context,
          observation: observation,
        );

        await _repository.saveSocialInteraction(record);

        _successMessage =
            'Registro de interacción social guardado correctamente.';

        _prepareNextRecord();

        return true;
      }

      final managementRepository = _repository;

      if (managementRepository is! SocialInteractionManagementRepository) {
        _errorMessage =
            'No fue posible actualizar el registro de interacción social. '
            'Inténtalo nuevamente.';

        return false;
      }

      final updatedRecord = _recordFactory.update(
        currentRecord: currentRecord,
        date: date!,
        category: category!,
        context: context,
        observation: observation,
      );

      await managementRepository.updateSocialInteraction(updatedRecord);

      _successMessage =
          'Registro de interacción social actualizado correctamente.';

      return true;
    } on SocialInteractionValidationFailure catch (failure) {
      _fieldErrors = failure.fieldErrors;

      return false;
    } on SocialInteractionFailure catch (failure) {
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _errorMessage = isEditing
          ? 'No fue posible actualizar el registro de interacción social. '
                'Inténtalo nuevamente.'
          : 'No fue posible guardar el registro de interacción social. '
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

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
