import 'package:flutter/foundation.dart';

import '../../../routine/domain/exceptions/routine_failure.dart';
import '../../../routine/domain/models/routine.dart';
import '../../../routine/domain/repositories/routine_repository.dart';
import '../../domain/exceptions/routine_status_failure.dart';
import '../../domain/models/routine_status_record.dart';
import '../../domain/repositories/routine_status_management_repository.dart';

class RoutineStatusManagementItem {
  const RoutineStatusManagementItem({
    required this.record,
    required this.routineName,
  });

  final RoutineStatusRecord record;

  final String routineName;
}

class RoutineStatusRoutineGroup {
  RoutineStatusRoutineGroup({
    required this.routineId,
    required this.routineName,
    required List<RoutineStatusManagementItem> items,
  }) : items = List.unmodifiable(items);

  final String routineId;

  final String routineName;

  final List<RoutineStatusManagementItem> items;

  int get recordCount => items.length;

  RoutineStatusManagementItem get latestItem => items.first;

  RoutineStatusRecord get latestRecord => latestItem.record;
}

class RoutineStatusManagementViewModel extends ChangeNotifier {
  RoutineStatusManagementViewModel(
    this._repository,
    this._routineRepository, {
    required this.anonymousId,
    DateTime? initialDateFilter,
  }) {
    if (initialDateFilter == null) {
      return;
    }

    final normalizedDate = _dateOnly(initialDateFilter);

    _startDate = normalizedDate;
    _endDate = normalizedDate;

    _pendingStartDate = normalizedDate;
    _pendingEndDate = normalizedDate;

    _preserveDateFilterAcrossRoutineNavigation = true;
  }

  final RoutineStatusManagementRepository _repository;

  final RoutineRepository _routineRepository;

  final String anonymousId;

  List<RoutineStatusRecord> _records = const [];

  Map<String, Routine> _routinesById = const {};

  DateTime? _startDate;

  DateTime? _endDate;

  DateTime? _pendingStartDate;

  DateTime? _pendingEndDate;

  String? _selectedRoutineId;

  String _routineSearchQuery = '';

  bool _isLoading = false;

  bool _hasLoaded = false;

  bool _preserveDateFilterAcrossRoutineNavigation = false;

  String? _errorMessage;

  String? _filterErrorMessage;

  String? _actionErrorMessage;

  final Set<String> _deletingRecordIds = <String>{};

  List<RoutineStatusRecord> get records {
    return List.unmodifiable(_records);
  }

  List<RoutineStatusManagementItem> get items {
    return List.unmodifiable(
      _records.map((record) {
        final routine = _routinesById[record.routineId];

        return RoutineStatusManagementItem(
          record: record,
          routineName: routine?.name ?? 'Rutina no disponible',
        );
      }),
    );
  }

  List<RoutineStatusRoutineGroup> get routineGroups {
    return _groupItems(items);
  }

  List<RoutineStatusRoutineGroup> get visibleRoutineGroups {
    if (!hasContextualDateFilter) {
      return routineGroups;
    }

    return _groupItems(filteredItems);
  }

  int get routineGroupCount {
    return routineGroups.length;
  }

  int get visibleRoutineGroupCount {
    return visibleRoutineGroups.length;
  }

  String get routineSearchQuery {
    return _routineSearchQuery;
  }

  bool get hasRoutineSearchQuery {
    return _routineSearchQuery.trim().isNotEmpty;
  }

  List<RoutineStatusRoutineGroup> get searchedRoutineGroups {
    final availableGroups = visibleRoutineGroups;

    if (!hasRoutineSearchQuery) {
      return availableGroups;
    }

    final query = _normalizeSearchText(_routineSearchQuery);

    return List.unmodifiable(
      availableGroups.where((group) {
        return _normalizeSearchText(group.routineName).contains(query);
      }),
    );
  }

  int get searchedRoutineGroupCount {
    return searchedRoutineGroups.length;
  }

  bool get hasNoRoutineSearchResults {
    return hasRoutineSearchQuery &&
        visibleRoutineGroups.isNotEmpty &&
        searchedRoutineGroups.isEmpty;
  }

  bool get hasNoContextualDateFilterResults {
    return hasContextualDateFilter &&
        _records.isNotEmpty &&
        visibleRoutineGroups.isEmpty;
  }

  String? get selectedRoutineId {
    return _selectedRoutineId;
  }

  bool get hasSelectedRoutine {
    return _selectedRoutineId != null;
  }

  RoutineStatusRoutineGroup? get selectedRoutineGroup {
    final selectedRoutineId = _selectedRoutineId;

    if (selectedRoutineId == null) {
      return null;
    }

    for (final group in routineGroups) {
      if (group.routineId == selectedRoutineId) {
        return group;
      }
    }

    return null;
  }

  List<RoutineStatusManagementItem> get selectedRoutineItems {
    final group = selectedRoutineGroup;

    if (group == null) {
      return const <RoutineStatusManagementItem>[];
    }

    return group.items;
  }

  List<RoutineStatusManagementItem> get filteredItems {
    if (!hasActiveDateFilter) {
      return items;
    }

    return List.unmodifiable(
      items.where((item) {
        return _matchesActiveDateFilter(item.record.date);
      }),
    );
  }

  List<RoutineStatusManagementItem> get filteredSelectedRoutineItems {
    if (!hasSelectedRoutine) {
      return const <RoutineStatusManagementItem>[];
    }

    if (!hasActiveDateFilter) {
      return selectedRoutineItems;
    }

    return List.unmodifiable(
      selectedRoutineItems.where((item) {
        return _matchesActiveDateFilter(item.record.date);
      }),
    );
  }

  int get filteredRecordCount {
    return filteredItems.length;
  }

  int get filteredSelectedRoutineRecordCount {
    return filteredSelectedRoutineItems.length;
  }

  bool get isLoading {
    return _isLoading;
  }

  bool get hasLoaded {
    return _hasLoaded;
  }

  bool get hasRecords {
    return _records.isNotEmpty;
  }

  bool get isEmpty {
    return _hasLoaded &&
        !_isLoading &&
        _records.isEmpty &&
        _errorMessage == null;
  }

  bool get hasNoFilterResults {
    return hasActiveDateFilter && _records.isNotEmpty && filteredItems.isEmpty;
  }

  bool get hasNoSelectedRoutineFilterResults {
    return hasSelectedRoutine &&
        hasActiveDateFilter &&
        selectedRoutineItems.isNotEmpty &&
        filteredSelectedRoutineItems.isEmpty;
  }

  String? get errorMessage {
    return _errorMessage;
  }

  String? get filterErrorMessage {
    return _filterErrorMessage;
  }

  String? get actionErrorMessage {
    return _actionErrorMessage;
  }

  DateTime? get startDate {
    return _startDate;
  }

  DateTime? get endDate {
    return _endDate;
  }

  DateTime? get pendingStartDate {
    return _pendingStartDate;
  }

  DateTime? get pendingEndDate {
    return _pendingEndDate;
  }

  bool get hasActiveDateFilter {
    return _startDate != null || _endDate != null;
  }

  bool get hasPendingDateFilter {
    return _pendingStartDate != null || _pendingEndDate != null;
  }

  bool get hasContextualDateFilter {
    return _preserveDateFilterAcrossRoutineNavigation && hasActiveDateFilter;
  }

  Future<bool> initialize() {
    return reload();
  }

  Future<bool> reload() async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;

    _errorMessage = null;

    notifyListeners();

    try {
      final recoveredRecords = await _repository.recoverRoutineStatuses(
        anonymousId: anonymousId,
      );

      final recoveredRoutines = await _routineRepository.recoverRoutines(
        anonymousId: anonymousId,
      );

      final matchingRecords = recoveredRecords.where((record) {
        return record.anonymousId == anonymousId;
      }).toList();

      matchingRecords.sort(_compareRecords);

      final matchingRoutines = recoveredRoutines.where((routine) {
        return routine.anonymousId == anonymousId;
      });

      final routinesById = <String, Routine>{
        for (final routine in matchingRoutines) routine.routineId: routine,
      };

      _records = List.unmodifiable(matchingRecords);

      _routinesById = Map.unmodifiable(routinesById);

      _synchronizeSelectedRoutine();

      _hasLoaded = true;

      return true;
    } on RoutineStatusFailure catch (failure) {
      _errorMessage = failure.message;

      _hasLoaded = true;

      return false;
    } on RoutineFailure catch (failure) {
      _errorMessage = failure.message;

      _hasLoaded = true;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible cargar los estados '
          'de las rutinas. Inténtalo nuevamente.';

      _hasLoaded = true;

      return false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  void setRoutineSearchQuery(String value) {
    if (_routineSearchQuery == value) {
      return;
    }

    _routineSearchQuery = value;

    notifyListeners();
  }

  void clearRoutineSearch() {
    if (_routineSearchQuery.isEmpty) {
      return;
    }

    _routineSearchQuery = '';

    notifyListeners();
  }

  void selectRoutineGroup(String routineId) {
    final normalizedRoutineId = routineId.trim();

    if (normalizedRoutineId.isEmpty) {
      return;
    }

    final exists = visibleRoutineGroups.any((group) {
      return group.routineId == normalizedRoutineId;
    });

    if (!exists) {
      return;
    }

    if (_selectedRoutineId == normalizedRoutineId) {
      return;
    }

    _selectedRoutineId = normalizedRoutineId;

    if (!_preserveDateFilterAcrossRoutineNavigation) {
      _resetDateFilter();
    }

    notifyListeners();
  }

  void clearSelectedRoutine() {
    if (_selectedRoutineId == null) {
      return;
    }

    _selectedRoutineId = null;

    if (!_preserveDateFilterAcrossRoutineNavigation) {
      _resetDateFilter();
    }

    notifyListeners();
  }

  void setPendingStartDate(DateTime? value) {
    _pendingStartDate = value == null ? null : _dateOnly(value);

    _filterErrorMessage = null;

    notifyListeners();
  }

  void setPendingEndDate(DateTime? value) {
    _pendingEndDate = value == null ? null : _dateOnly(value);

    _filterErrorMessage = null;

    notifyListeners();
  }

  bool applyDateFilter() {
    final startDate = _pendingStartDate;

    final endDate = _pendingEndDate;

    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      _filterErrorMessage =
          'La fecha inicial no puede ser posterior '
          'a la fecha final.';

      notifyListeners();

      return false;
    }

    _startDate = startDate;

    _endDate = endDate;

    _filterErrorMessage = null;

    notifyListeners();

    return true;
  }

  void clearDateFilter() {
    _preserveDateFilterAcrossRoutineNavigation = false;

    _resetDateFilter();

    notifyListeners();
  }

  bool isDeleting(String recordId) {
    return _deletingRecordIds.contains(recordId);
  }

  Future<bool> deleteRoutineStatus(RoutineStatusRecord record) async {
    if (record.anonymousId != anonymousId) {
      _actionErrorMessage = 'No fue posible eliminar este estado de rutina.';

      notifyListeners();

      return false;
    }

    if (_deletingRecordIds.contains(record.recordId)) {
      return false;
    }

    _actionErrorMessage = null;

    _deletingRecordIds.add(record.recordId);

    notifyListeners();

    try {
      await _repository.deleteRoutineStatus(
        anonymousId: anonymousId,
        recordId: record.recordId,
      );

      _records = List.unmodifiable(
        _records.where((current) {
          return current.recordId != record.recordId;
        }).toList(),
      );

      _synchronizeSelectedRoutine();

      return true;
    } on RoutineStatusFailure catch (failure) {
      _actionErrorMessage = failure.message;

      return false;
    } catch (_) {
      _actionErrorMessage =
          'No fue posible eliminar el estado '
          'de la rutina. Inténtalo nuevamente.';

      return false;
    } finally {
      _deletingRecordIds.remove(record.recordId);

      notifyListeners();
    }
  }

  void clearActionError() {
    if (_actionErrorMessage == null) {
      return;
    }

    _actionErrorMessage = null;

    notifyListeners();
  }

  List<RoutineStatusRoutineGroup> _groupItems(
    Iterable<RoutineStatusManagementItem> sourceItems,
  ) {
    final groupedItems = <String, List<RoutineStatusManagementItem>>{};

    for (final item in sourceItems) {
      groupedItems
          .putIfAbsent(
            item.record.routineId,
            () => <RoutineStatusManagementItem>[],
          )
          .add(item);
    }

    return List.unmodifiable(
      groupedItems.entries.map((entry) {
        final groupItems = entry.value;

        return RoutineStatusRoutineGroup(
          routineId: entry.key,
          routineName: groupItems.first.routineName,
          items: groupItems,
        );
      }),
    );
  }

  void _synchronizeSelectedRoutine() {
    final selectedRoutineId = _selectedRoutineId;

    if (selectedRoutineId == null) {
      return;
    }

    final stillExists =
        _preserveDateFilterAcrossRoutineNavigation && hasActiveDateFilter
        ? filteredItems.any((item) {
            return item.record.routineId == selectedRoutineId;
          })
        : _records.any((record) {
            return record.routineId == selectedRoutineId;
          });

    if (stillExists) {
      return;
    }

    _selectedRoutineId = null;

    if (!_preserveDateFilterAcrossRoutineNavigation) {
      _resetDateFilter();
    }
  }

  void _resetDateFilter() {
    _startDate = null;

    _endDate = null;

    _pendingStartDate = null;

    _pendingEndDate = null;

    _filterErrorMessage = null;
  }

  bool _matchesActiveDateFilter(DateTime value) {
    final date = _dateOnly(value);

    final startDate = _startDate;

    final endDate = _endDate;

    if (startDate != null && date.isBefore(startDate)) {
      return false;
    }

    if (endDate != null && date.isAfter(endDate)) {
      return false;
    }

    return true;
  }

  static int _compareRecords(
    RoutineStatusRecord first,
    RoutineStatusRecord second,
  ) {
    final byDate = second.date.compareTo(first.date);

    if (byDate != 0) {
      return byDate;
    }

    return second.createdAt.compareTo(first.createdAt);
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();

    return DateTime(local.year, local.month, local.day);
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
