import 'package:flutter/foundation.dart';

import '../../domain/exceptions/routine_failure.dart';
import '../../domain/models/routine.dart';
import '../../domain/repositories/routine_repository.dart';

class RoutineManagementViewModel extends ChangeNotifier {
  RoutineManagementViewModel(this._repository, {required this.anonymousId});

  final RoutineRepository _repository;

  final String anonymousId;

  List<Routine> _routines = const [];

  bool _isLoading = false;
  bool _isUpdating = false;

  String? _errorMessage;

  List<Routine> get routines => List.unmodifiable(_routines);

  List<Routine> get activeRoutines =>
      List.unmodifiable(_routines.where((routine) => routine.isActive));

  List<Routine> get inactiveRoutines =>
      List.unmodifiable(_routines.where((routine) => !routine.isActive));

  bool get isLoading => _isLoading;

  bool get isUpdating => _isUpdating;

  String? get errorMessage => _errorMessage;

  bool get hasRoutines => _routines.isNotEmpty;

  Future<void> initialize() async {
    if (_routines.isNotEmpty || _isLoading) {
      return;
    }

    await reload();
  }

  Future<bool> reload() async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final recovered = await _repository.recoverRoutines(
        anonymousId: anonymousId,
      );

      _routines = _sortRoutines(recovered);

      return true;
    } on RoutineFailure catch (failure) {
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible cargar las rutinas. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  Future<bool> deactivateRoutine(Routine routine) async {
    if (_isUpdating || !routine.isActive) {
      return false;
    }

    _isUpdating = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await _repository.deactivateRoutine(
        anonymousId: routine.anonymousId,
        routineId: routine.routineId,
      );

      final updated = routine.copyWith(isActive: false);

      _routines = _sortRoutines(
        _routines
            .map(
              (current) =>
                  current.routineId == routine.routineId ? updated : current,
            )
            .toList(),
      );

      return true;
    } on RoutineFailure catch (failure) {
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible desactivar la rutina. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _isUpdating = false;

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

  List<Routine> _sortRoutines(Iterable<Routine> routines) {
    final result = routines.toList();

    result.sort((first, second) {
      if (first.isActive != second.isActive) {
        return first.isActive ? -1 : 1;
      }

      return first.name.toLowerCase().compareTo(second.name.toLowerCase());
    });

    return List.unmodifiable(result);
  }
}
