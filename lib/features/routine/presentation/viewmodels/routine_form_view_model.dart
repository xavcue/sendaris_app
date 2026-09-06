import 'package:flutter/foundation.dart';

import '../../domain/exceptions/routine_failure.dart';
import '../../domain/exceptions/routine_validation_failure.dart';
import '../../domain/models/routine.dart';
import '../../domain/repositories/routine_repository.dart';
import '../../domain/services/routine_factory.dart';

class RoutineFormViewModel extends ChangeNotifier {
  RoutineFormViewModel(
    this._repository,
    this._routineFactory, {
    required this.anonymousId,
    Routine? initialRoutine,
  }) : _initialRoutine = initialRoutine,
       _selectedTime = initialRoutine?.scheduledTime,
       _selectedRecurrence = initialRoutine?.recurrence;

  final RoutineRepository _repository;
  final RoutineFactory _routineFactory;

  final String anonymousId;

  final Routine? _initialRoutine;

  String? _selectedTime;
  String? _selectedRecurrence;

  bool _isSaving = false;

  String? _errorMessage;
  String? _successMessage;

  Map<String, String> _fieldErrors = const {};

  bool get isEditing => _initialRoutine != null;

  Routine? get initialRoutine => _initialRoutine;

  String? get selectedTime => _selectedTime;

  String? get selectedRecurrence => _selectedRecurrence;

  bool get isSaving => _isSaving;

  String? get errorMessage => _errorMessage;

  String? get successMessage => _successMessage;

  Map<String, String> get fieldErrors => Map.unmodifiable(_fieldErrors);

  String? errorFor(String field) {
    return _fieldErrors[field];
  }

  void setTime({required int hour, required int minute}) {
    _selectedTime =
        '${hour.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')}';

    _removeFieldError('scheduledTime');

    _clearMessages();

    notifyListeners();
  }

  void clearTime() {
    if (_selectedTime == null) {
      return;
    }

    _selectedTime = null;

    _removeFieldError('scheduledTime');

    _clearMessages();

    notifyListeners();
  }

  void setRecurrence(String? recurrence) {
    _selectedRecurrence = recurrence;

    _removeFieldError('recurrence');

    _clearMessages();

    notifyListeners();
  }

  Future<Routine?> save({
    required String name,
    required String description,
  }) async {
    if (_isSaving) {
      return null;
    }

    _fieldErrors = {};
    _errorMessage = null;
    _successMessage = null;

    _isSaving = true;

    notifyListeners();

    try {
      final existing = _initialRoutine;

      late final Routine routine;

      if (existing == null) {
        routine = _routineFactory.create(
          anonymousId: anonymousId,
          name: name,
          description: description,
          scheduledTime: _selectedTime,
          recurrence: _selectedRecurrence,
        );

        await _repository.createRoutine(routine);

        _successMessage = 'Rutina creada correctamente.';
      } else {
        routine = _routineFactory.update(
          routine: existing,
          name: name,
          description: description,
          scheduledTime: _selectedTime,
          recurrence: _selectedRecurrence,
        );

        await _repository.updateRoutine(routine);

        _successMessage = 'Rutina actualizada correctamente.';
      }

      return routine;
    } on RoutineValidationFailure catch (failure) {
      _fieldErrors = Map.unmodifiable(failure.errors);

      return null;
    } on RoutineFailure catch (failure) {
      _errorMessage = failure.message;

      return null;
    } catch (_) {
      _errorMessage = isEditing
          ? 'No fue posible actualizar la rutina. '
                'Inténtalo nuevamente.'
          : 'No fue posible crear la rutina. '
                'Inténtalo nuevamente.';

      return null;
    } finally {
      _isSaving = false;

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

  void _removeFieldError(String field) {
    if (!_fieldErrors.containsKey(field)) {
      return;
    }

    final updatedErrors = Map<String, String>.from(_fieldErrors);

    updatedErrors.remove(field);

    _fieldErrors = Map.unmodifiable(updatedErrors);
  }

  void _clearMessages() {
    _errorMessage = null;
    _successMessage = null;
  }
}
