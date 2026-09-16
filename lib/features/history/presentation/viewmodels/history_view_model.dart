import 'package:flutter/foundation.dart';

import '../../domain/exceptions/history_failure.dart';
import '../../domain/exceptions/history_filter_validation_failure.dart';
import '../../domain/models/history_filter.dart';
import '../../domain/models/history_record.dart';
import '../../domain/models/history_record_type.dart';
import '../../domain/repositories/history_repository.dart';

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel(this._repository, {required this.anonymousId});

  final HistoryRepository _repository;

  final String anonymousId;

  List<HistoryRecord> _records = const [];

  HistoryFilter _activeFilter = HistoryFilter.empty();

  DateTime? _pendingStartDate;

  DateTime? _pendingEndDate;

  Set<HistoryRecordType> _pendingSelectedTypes = const <HistoryRecordType>{};

  Map<String, String> _filterErrors = const {};

  bool _isLoading = false;
  bool _hasLoaded = false;

  String? _errorMessage;

  List<HistoryRecord> get records => List.unmodifiable(_records);

  List<HistoryRecord> get filteredRecords {
    if (!_activeFilter.isActive) {
      return records;
    }

    return List.unmodifiable(_records.where(_activeFilter.matches).toList());
  }

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  bool get hasRecords => _records.isNotEmpty;

  bool get isEmpty =>
      _hasLoaded && !_isLoading && _records.isEmpty && _errorMessage == null;

  DateTime? get pendingStartDate => _pendingStartDate;

  DateTime? get pendingEndDate => _pendingEndDate;

  Set<HistoryRecordType> get pendingSelectedTypes =>
      Set.unmodifiable(_pendingSelectedTypes);

  bool get hasActiveFilters => _activeFilter.isActive;

  bool get hasPeriodFilter => _activeFilter.hasPeriodFilter;

  bool get hasTypeFilter => _activeFilter.hasTypeFilter;

  int get filteredRecordCount => filteredRecords.length;

  bool get hasNoFilterResults =>
      _hasLoaded &&
      !_isLoading &&
      _records.isNotEmpty &&
      hasActiveFilters &&
      filteredRecords.isEmpty &&
      _errorMessage == null;

  Map<String, String> get filterErrors => Map.unmodifiable(_filterErrors);

  String? filterErrorFor(String field) {
    return _filterErrors[field];
  }

  bool get hasFilterErrors => _filterErrors.isNotEmpty;

  Future<void> initialize() async {
    if (_hasLoaded || _isLoading) {
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
      final recovered = await _repository.recoverHistory(
        anonymousId: anonymousId,
      );

      _records = _sortByEventDate(recovered);

      _hasLoaded = true;

      return true;
    } on HistoryFailure catch (failure) {
      _errorMessage = failure.message;

      _hasLoaded = true;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible cargar el historial. '
          'Inténtalo nuevamente.';

      _hasLoaded = true;

      return false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  void setPendingStartDate(DateTime? value) {
    _pendingStartDate = value == null ? null : _dateOnly(value);

    _clearFilterErrors();

    notifyListeners();
  }

  void setPendingEndDate(DateTime? value) {
    _pendingEndDate = value == null ? null : _dateOnly(value);

    _clearFilterErrors();

    notifyListeners();
  }

  void togglePendingType(HistoryRecordType type) {
    final updated = Set<HistoryRecordType>.from(_pendingSelectedTypes);

    if (!updated.add(type)) {
      updated.remove(type);
    }

    _pendingSelectedTypes = Set.unmodifiable(updated);

    _clearFilterErrors();

    notifyListeners();
  }

  bool isPendingTypeSelected(HistoryRecordType type) {
    return _pendingSelectedTypes.contains(type);
  }

  bool applyFilters() {
    try {
      final filter = HistoryFilter.create(
        startDate: _pendingStartDate,
        endDate: _pendingEndDate,
        selectedTypes: _pendingSelectedTypes,
      );

      _activeFilter = filter;
      _filterErrors = const {};

      notifyListeners();

      return true;
    } on HistoryFilterValidationFailure catch (failure) {
      _filterErrors = Map.unmodifiable(failure.fieldErrors);

      notifyListeners();

      return false;
    }
  }

  void clearFilters() {
    _activeFilter = HistoryFilter.empty();

    _pendingStartDate = null;
    _pendingEndDate = null;

    _pendingSelectedTypes = const <HistoryRecordType>{};

    _filterErrors = const {};

    notifyListeners();
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;

    notifyListeners();
  }

  void _clearFilterErrors() {
    if (_filterErrors.isEmpty) {
      return;
    }

    _filterErrors = const {};
  }

  List<HistoryRecord> _sortByEventDate(Iterable<HistoryRecord> records) {
    final result = records.toList();

    result.sort((first, second) => second.eventDate.compareTo(first.eventDate));

    return List.unmodifiable(result);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
