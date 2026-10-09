import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../routine/domain/exceptions/routine_failure.dart';
import '../../../routine/domain/models/routine.dart';
import '../../../routine/domain/repositories/routine_repository.dart';
import '../../domain/exceptions/routine_status_failure.dart';
import '../../domain/exceptions/routine_status_validation_failure.dart';
import '../../domain/models/routine_status.dart';
import '../../domain/models/routine_status_record.dart';
import '../../domain/repositories/routine_status_management_repository.dart';
import '../../domain/repositories/routine_status_repository.dart';
import '../../domain/services/routine_status_record_factory.dart';

class RoutineStatusFormViewModel extends ChangeNotifier {
  RoutineStatusFormViewModel(
    this._routineRepository,
    this._routineStatusRepository,
    this._recordFactory, {
    required String anonymousId,
    RoutineStatusRecord? initialRecord,
  }) : _anonymousId = anonymousId.trim(),
       _initialRecord = initialRecord,
       _selectedRoutineId = initialRecord?.routineId,
       _selectedDate = initialRecord == null
           ? null
           : _normalizeDate(initialRecord.date),
       _selectedStatus = initialRecord?.status,
       _observation = initialRecord?.observation;

  final RoutineRepository _routineRepository;

  final RoutineStatusRepository _routineStatusRepository;

  final RoutineStatusRecordFactory _recordFactory;

  final String _anonymousId;

  final RoutineStatusRecord? _initialRecord;

  List<Routine> _routines = const [];

  String? _selectedRoutineId;
  DateTime? _selectedDate;
  RoutineStatus? _selectedStatus;
  String? _observation;

  bool _isLoading = false;
  bool _isSaving = false;

  String? _errorMessage;
  String? _routineError;
  String? _dateError;
  String? _statusError;

  Timer? _validationTimer;

  List<Routine> get routines => List.unmodifiable(_routines);

  bool get hasRoutines => _routines.isNotEmpty;

  bool get isEditing => _initialRecord != null;

  String? get selectedRoutineId => _selectedRoutineId;

  Routine? get selectedRoutine {
    final selectedId = _selectedRoutineId;

    if (selectedId == null) {
      return null;
    }

    for (final routine in _routines) {
      if (routine.routineId == selectedId) {
        return routine;
      }
    }

    return null;
  }

  DateTime? get selectedDate => _selectedDate;

  RoutineStatus? get selectedStatus => _selectedStatus;

  String? get observation => _observation;

  String get initialObservation => _initialRecord?.observation ?? '';

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  String? get errorMessage => _errorMessage;

  String? get routineError => _routineError;

  String? get dateError => _dateError;

  String? get statusError => _statusError;

  Future<bool> initialize() async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final recovered = await _routineRepository.recoverRoutines(
        anonymousId: _anonymousId,
      );

      final routines =
          recovered
              .where((routine) => routine.anonymousId == _anonymousId)
              .toList()
            ..sort(
              (first, second) =>
                  first.name.toLowerCase().compareTo(second.name.toLowerCase()),
            );

      _routines = List.unmodifiable(routines);

      final selectedId = _selectedRoutineId;

      if (selectedId != null &&
          !_routines.any((routine) => routine.routineId == selectedId)) {
        _selectedRoutineId = null;
      }

      return true;
    } on RoutineFailure catch (failure) {
      _routines = const [];
      _selectedRoutineId = null;
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _routines = const [];
      _selectedRoutineId = null;
      _errorMessage =
          'No fue posible cargar las rutinas. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  void selectRoutine(String routineId) {
    final normalizedId = routineId.trim();

    if (!_routines.any((routine) => routine.routineId == normalizedId)) {
      return;
    }

    _selectedRoutineId = normalizedId;

    _routineError = null;

    _clearGeneralError();

    notifyListeners();
  }

  void selectDate(DateTime date) {
    _selectedDate = _normalizeDate(date);

    _dateError = null;

    _clearGeneralError();

    notifyListeners();
  }

  void selectStatus(RoutineStatus status) {
    if (_selectedStatus == status) {
      _selectedStatus = null;
    } else {
      _selectedStatus = status;
    }

    _statusError = null;

    _clearGeneralError();

    notifyListeners();
  }

  void setObservation(String value) {
    _observation = value;

    _clearGeneralError();
  }

  Future<bool> save() async {
    if (_isSaving) {
      return false;
    }

    _validationTimer?.cancel();

    _routineError = null;
    _dateError = null;
    _statusError = null;
    _errorMessage = null;

    final routineId = _selectedRoutineId;

    final date = _selectedDate;

    final status = _selectedStatus;

    var hasValidationError = false;

    if (routineId == null ||
        !_routines.any((routine) => routine.routineId == routineId)) {
      _routineError = 'Selecciona una rutina.';

      hasValidationError = true;
    }

    if (date == null) {
      _dateError = 'Selecciona una fecha.';

      hasValidationError = true;
    }

    if (status == null) {
      _statusError = 'Selecciona el estado de la rutina.';

      hasValidationError = true;
    }

    if (hasValidationError) {
      _scheduleValidationClear();

      notifyListeners();

      return false;
    }

    final validRoutineId = routineId!;

    final validDate = date!;

    final validStatus = status!;

    _isSaving = true;

    notifyListeners();

    try {
      final existingRecords = await _routineStatusRepository
          .recoverRoutineStatuses(anonymousId: _anonymousId);

      final currentRecord = _initialRecord;

      final duplicateExists = existingRecords.any(
        (record) =>
            record.anonymousId == _anonymousId &&
            record.recordId != currentRecord?.recordId &&
            record.routineId == validRoutineId &&
            _isSameDate(record.date, validDate),
      );

      if (duplicateExists) {
        _errorMessage =
            'Ya existe un estado registrado '
            'para esta rutina en la fecha '
            'seleccionada.';

        _scheduleValidationClear();

        return false;
      }

      if (currentRecord != null) {
        final managementRepository = _routineStatusRepository;

        if (managementRepository is! RoutineStatusManagementRepository) {
          _errorMessage =
              'No fue posible actualizar el estado '
              'de la rutina. Inténtalo nuevamente.';

          _scheduleValidationClear();

          return false;
        }

        final updatedRecord = _recordFactory.update(
          currentRecord: currentRecord,
          routineId: validRoutineId,
          date: validDate,
          status: validStatus,
          observation: _observation,
        );

        await managementRepository.updateRoutineStatus(updatedRecord);

        return true;
      }

      final record = _recordFactory.create(
        anonymousId: _anonymousId,
        routineId: validRoutineId,
        date: validDate,
        status: validStatus,
        observation: _observation,
      );

      await _routineStatusRepository.saveRoutineStatus(record);

      _selectedRoutineId = null;
      _selectedDate = null;
      _selectedStatus = null;
      _observation = null;

      return true;
    } on RoutineStatusValidationFailure {
      _errorMessage =
          'No fue posible validar el estado '
          'de la rutina. Revisa la información '
          'ingresada.';

      _scheduleValidationClear();

      return false;
    } on RoutineStatusFailure catch (failure) {
      _errorMessage = failure.message;

      _scheduleValidationClear();

      return false;
    } catch (_) {
      _errorMessage = isEditing
          ? 'No fue posible actualizar el estado '
                'de la rutina. Inténtalo nuevamente.'
          : 'No fue posible guardar el estado '
                'de la rutina. Inténtalo nuevamente.';

      _scheduleValidationClear();

      return false;
    } finally {
      _isSaving = false;

      notifyListeners();
    }
  }

  void _scheduleValidationClear() {
    _validationTimer?.cancel();

    _validationTimer = Timer(const Duration(seconds: 4), () {
      _routineError = null;
      _dateError = null;
      _statusError = null;
      _errorMessage = null;

      notifyListeners();
    });
  }

  void _clearGeneralError() {
    _errorMessage = null;
  }

  static DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  static bool _isSameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  @override
  void dispose() {
    _validationTimer?.cancel();

    super.dispose();
  }
}
