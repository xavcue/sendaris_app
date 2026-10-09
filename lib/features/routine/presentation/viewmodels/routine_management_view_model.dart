import 'package:flutter/foundation.dart';

import '../../domain/exceptions/routine_failure.dart';
import '../../domain/models/routine.dart';
import '../../domain/repositories/routine_repository.dart';

class RoutineManagementViewModel extends ChangeNotifier {
  RoutineManagementViewModel(this._repository, {required this.anonymousId});

  final RoutineRepository _repository;

  final String anonymousId;

  List<Routine> _routines = const [];

  String _searchQuery = '';

  bool _isLoading = false;

  bool _isUpdating = false;

  String? _errorMessage;

  List<Routine> get routines {
    return List.unmodifiable(_routines);
  }

  String get searchQuery => _searchQuery;

  bool get hasSearchQuery {
    return _searchQuery.trim().isNotEmpty;
  }

  List<Routine> get searchedRoutines {
    if (!hasSearchQuery) {
      return routines;
    }

    final query = _normalizeSearchText(_searchQuery);

    return List.unmodifiable(
      _routines.where(
        (routine) => _normalizeSearchText(routine.name).contains(query),
      ),
    );
  }

  int get searchedRoutineCount {
    return searchedRoutines.length;
  }

  bool get hasNoSearchResults {
    return hasSearchQuery && _routines.isNotEmpty && searchedRoutines.isEmpty;
  }

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

      final currentRoutines = recovered.where(
        (routine) => routine.anonymousId == anonymousId,
      );

      _routines = _sortRoutines(currentRoutines);

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

  void setSearchQuery(String value) {
    if (_searchQuery == value) {
      return;
    }

    _searchQuery = value;

    notifyListeners();
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) {
      return;
    }

    _searchQuery = '';

    notifyListeners();
  }

  Future<bool> deleteRoutine(Routine routine) async {
    if (_isUpdating ||
        routine.anonymousId != anonymousId ||
        !_routines.any((current) => current.routineId == routine.routineId)) {
      return false;
    }

    _isUpdating = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await _repository.deleteRoutine(
        anonymousId: anonymousId,
        routineId: routine.routineId,
      );

      _routines = List.unmodifiable(
        _routines
            .where((current) => current.routineId != routine.routineId)
            .toList(),
      );

      return true;
    } on RoutineFailure catch (failure) {
      _errorMessage = failure.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible eliminar la rutina. '
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

    result.sort(
      (first, second) =>
          first.name.toLowerCase().compareTo(second.name.toLowerCase()),
    );

    return List.unmodifiable(result);
  }

  static String _normalizeSearchText(String value) {
    var normalized = value.trim().toLowerCase();

    const replacements = <String, String>{
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'ã': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'õ': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };

    for (final entry in replacements.entries) {
      normalized = normalized.replaceAll(entry.key, entry.value);
    }

    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }
}
