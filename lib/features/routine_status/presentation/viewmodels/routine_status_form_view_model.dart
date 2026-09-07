import 'package:flutter/foundation.dart';

import '../../../routine/domain/exceptions/routine_failure.dart';
import '../../../routine/domain/models/routine.dart';
import '../../../routine/domain/repositories/routine_repository.dart';
import '../../domain/exceptions/routine_status_failure.dart';
import '../../domain/exceptions/routine_status_validation_failure.dart';
import '../../domain/models/routine_status.dart';
import '../../domain/repositories/routine_status_repository.dart';
import '../../domain/services/routine_status_record_factory.dart';

class RoutineStatusFormViewModel extends ChangeNotifier {
  RoutineStatusFormViewModel(
    this._routineRepository,
    this._routineStatusRepository,
    this._recordFactory, {
    required String anonymousId,
    DateTime? initialDate,
  }) : _anonymousId = anonymousId.trim(),
       _selectedDate = _normalizeDate(initialDate ?? DateTime.now());

  final RoutineRepository _routineRepository;
  final RoutineStatusRepository _routineStatusRepository;
  final RoutineStatusRecordFactory _recordFactory;

  final String _anonymousId;

  List<Routine> _activeRoutines = const [];

  String? _selectedRoutineId;
  DateTime _selectedDate;
  RoutineStatus? _selectedStatus;
  String? _observation;

  bool _isLoading = false;
  bool _isSaving = false;

  String? _errorMessage;
  String? _routineError;
  String? _statusError;

  List<Routine> get activeRoutines => List.unmodifiable(_activeRoutines);

  bool get hasActiveRoutines => _activeRoutines.isNotEmpty;

  String? get selectedRoutineId => _selectedRoutineId;

  DateTime get selectedDate => _selectedDate;

  RoutineStatus? get selectedStatus => _selectedStatus;

  String? get observation => _observation;

  bool get isLoading => _isLoading;

  bool get isSaving => _isSaving;

  String? get errorMessage => _errorMessage;

  String? get routineError => _routineError;

  String? get statusError => _statusError;

  Future<bool> initialize() async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final routines = await _routineRepository.recoverRoutines(
        anonymousId: _anonymousId,
      );

      final activeRoutines = routines
          .where(
            (routine) =>
                routine.isActive && routine.anonymousId == _anonymousId,
          )
          .toList();

      activeRoutines.sort(
        (first, second) =>
            first.name.toLowerCase().compareTo(second.name.toLowerCase()),
      );

      _activeRoutines = List.unmodifiable(activeRoutines);

      final selectedRoutineId = _selectedRoutineId;

      if (selectedRoutineId != null &&
          !_activeRoutines.any(
            (routine) => routine.routineId == selectedRoutineId,
          )) {
        _selectedRoutineId = null;
      }

      return true;
    } on RoutineFailure catch (failure) {
      _activeRoutines = const [];
      _selectedRoutineId = null;
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _activeRoutines = const [];
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

    if (!_activeRoutines.any((routine) => routine.routineId == normalizedId)) {
      return;
    }

    _selectedRoutineId = normalizedId;

    _routineError = null;

    _clearGeneralError();

    notifyListeners();
  }

  void selectDate(DateTime date) {
    _selectedDate = _normalizeDate(date);

    _clearGeneralError();

    notifyListeners();
  }

  void selectStatus(RoutineStatus status) {
    _selectedStatus = status;

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

    _routineError = null;
    _statusError = null;
    _errorMessage = null;

    final routineId = _selectedRoutineId;

    final status = _selectedStatus;

    var hasValidationError = false;

    if (routineId == null ||
        !_activeRoutines.any(
          (routine) => routine.routineId == routineId && routine.isActive,
        )) {
      _routineError = 'Selecciona una rutina activa.';

      hasValidationError = true;
    }

    if (status == null) {
      _statusError = 'Selecciona el estado de la rutina.';

      hasValidationError = true;
    }

    if (hasValidationError) {
      notifyListeners();

      return false;
    }

    // En este punto las validaciones anteriores
    // garantizan que ambos valores existen.
    final validRoutineId = routineId!;

    final validStatus = status!;

    _isSaving = true;

    notifyListeners();

    try {
      final existingRecords = await _routineStatusRepository
          .recoverRoutineStatuses(anonymousId: _anonymousId);

      final duplicateExists = existingRecords.any(
        (record) =>
            record.routineId == validRoutineId &&
            _isSameDate(record.date, _selectedDate),
      );

      if (duplicateExists) {
        _errorMessage =
            'Ya existe un estado registrado '
            'para esta rutina en la fecha '
            'seleccionada.';

        return false;
      }

      final record = _recordFactory.create(
        anonymousId: _anonymousId,
        routineId: validRoutineId,
        date: _selectedDate,
        status: validStatus,
        observation: _observation,
      );

      await _routineStatusRepository.saveRoutineStatus(record);

      return true;
    } on RoutineStatusValidationFailure catch (_) {
      _errorMessage =
          'No fue posible validar el estado '
          'de la rutina. Revisa la información '
          'ingresada.';

      return false;
    } on RoutineStatusFailure catch (failure) {
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible guardar el estado '
          'de la rutina. Inténtalo nuevamente.';

      return false;
    } finally {
      _isSaving = false;

      notifyListeners();
    }
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
}
