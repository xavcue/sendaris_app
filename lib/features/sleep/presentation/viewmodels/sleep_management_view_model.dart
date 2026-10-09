import 'package:flutter/foundation.dart';

import '../../domain/exceptions/sleep_failure.dart';
import '../../domain/models/sleep_record.dart';
import '../../domain/repositories/sleep_management_repository.dart';

class SleepManagementViewModel extends ChangeNotifier {
  SleepManagementViewModel(this._repository, {required this.anonymousId});

  final SleepManagementRepository _repository;

  final String anonymousId;

  List<SleepRecord> _allRecords = const [];

  DateTime? _pendingStartDate;
  DateTime? _pendingEndDate;

  DateTime? _appliedStartDate;
  DateTime? _appliedEndDate;

  bool _isLoading = false;
  bool _hasLoaded = false;

  String? _loadError;
  String? _filterError;
  String? _actionError;

  final Set<String> _deletingRecordIds = {};

  List<SleepRecord> get records {
    return List.unmodifiable(_filteredRecords());
  }

  int get recordCount => records.length;

  int get totalRecordCount => _allRecords.length;

  DateTime? get pendingStartDate => _pendingStartDate;

  DateTime? get pendingEndDate => _pendingEndDate;

  DateTime? get appliedStartDate => _appliedStartDate;

  DateTime? get appliedEndDate => _appliedEndDate;

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  String? get loadError => _loadError;

  String? get filterError => _filterError;

  String? get actionError => _actionError;

  bool get hasAppliedDateFilter {
    return _appliedStartDate != null || _appliedEndDate != null;
  }

  bool get hasPendingDateFilter {
    return _pendingStartDate != null || _pendingEndDate != null;
  }

  bool isDeleting(String recordId) {
    return _deletingRecordIds.contains(recordId);
  }

  Future<bool> load() {
    return _recoverRecords();
  }

  Future<bool> reload() {
    return _recoverRecords();
  }

  void setPendingStartDate(DateTime? date) {
    _pendingStartDate = date == null ? null : _dateOnly(date);

    _filterError = null;

    notifyListeners();
  }

  void setPendingEndDate(DateTime? date) {
    _pendingEndDate = date == null ? null : _dateOnly(date);

    _filterError = null;

    notifyListeners();
  }

  bool applyDateFilter() {
    final startDate = _pendingStartDate;
    final endDate = _pendingEndDate;

    if (startDate != null && endDate != null && startDate.isAfter(endDate)) {
      _filterError =
          'La fecha inicial no puede ser posterior '
          'a la fecha final.';

      notifyListeners();

      return false;
    }

    _appliedStartDate = startDate;
    _appliedEndDate = endDate;

    _filterError = null;

    notifyListeners();

    return true;
  }

  void clearDateFilter() {
    _pendingStartDate = null;
    _pendingEndDate = null;

    _appliedStartDate = null;
    _appliedEndDate = null;

    _filterError = null;

    notifyListeners();
  }

  Future<bool> deleteSleep(SleepRecord record) async {
    if (_deletingRecordIds.contains(record.recordId)) {
      return false;
    }

    _deletingRecordIds.add(record.recordId);

    _actionError = null;

    notifyListeners();

    try {
      await _repository.deleteSleep(
        anonymousId: anonymousId,
        recordId: record.recordId,
      );

      _allRecords = _allRecords
          .where((current) => current.recordId != record.recordId)
          .toList(growable: false);

      return true;
    } on SleepFailure catch (failure) {
      _actionError = failure.message;

      return false;
    } finally {
      _deletingRecordIds.remove(record.recordId);

      notifyListeners();
    }
  }

  void clearActionError() {
    if (_actionError == null) {
      return;
    }

    _actionError = null;

    notifyListeners();
  }

  Future<bool> _recoverRecords() async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _loadError = null;

    notifyListeners();

    try {
      final recovered = await _repository.recoverSleepRecords(
        anonymousId: anonymousId,
      );

      final matchingRecords = recovered
          .where((record) => record.anonymousId == anonymousId)
          .toList();

      matchingRecords.sort(_compareRecords);

      _allRecords = List.unmodifiable(matchingRecords);

      _hasLoaded = true;

      return true;
    } on SleepFailure catch (failure) {
      _loadError = failure.message;

      return false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  List<SleepRecord> _filteredRecords() {
    final startDate = _appliedStartDate;
    final endDate = _appliedEndDate;

    if (startDate == null && endDate == null) {
      return List<SleepRecord>.from(_allRecords);
    }

    return _allRecords
        .where((record) {
          final recordDate = _dateOnly(record.date);

          if (startDate != null && recordDate.isBefore(startDate)) {
            return false;
          }

          if (endDate != null && recordDate.isAfter(endDate)) {
            return false;
          }

          return true;
        })
        .toList(growable: false);
  }

  static int _compareRecords(SleepRecord first, SleepRecord second) {
    final eventComparison = second.eventDateTime.compareTo(first.eventDateTime);

    if (eventComparison != 0) {
      return eventComparison;
    }

    return second.createdAt.compareTo(first.createdAt);
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
