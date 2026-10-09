import 'package:flutter/foundation.dart';

import '../../domain/exceptions/behavior_failure.dart';
import '../../domain/models/behavior_record.dart';
import '../../domain/repositories/behavior_management_repository.dart';

class BehaviorManagementViewModel extends ChangeNotifier {
  BehaviorManagementViewModel(this._repository, {required this.anonymousId});

  final BehaviorManagementRepository _repository;

  final String anonymousId;

  List<BehaviorRecord> _records = const [];

  DateTime? _startDate;
  DateTime? _endDate;

  DateTime? _pendingStartDate;
  DateTime? _pendingEndDate;

  bool _isLoading = false;
  bool _hasLoaded = false;

  String? _errorMessage;
  String? _filterErrorMessage;
  String? _actionErrorMessage;

  final Set<String> _deletingRecordIds = <String>{};

  List<BehaviorRecord> get records => List.unmodifiable(_records);

  List<BehaviorRecord> get filteredRecords {
    final startDate = _startDate;
    final endDate = _endDate;

    if (startDate == null && endDate == null) {
      return List.unmodifiable(_records);
    }

    return List.unmodifiable(
      _records.where((record) {
        final date = _dateOnly(record.date);

        if (startDate != null && date.isBefore(startDate)) {
          return false;
        }

        if (endDate != null && date.isAfter(endDate)) {
          return false;
        }

        return true;
      }),
    );
  }

  int get filteredRecordCount => filteredRecords.length;

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  bool get hasRecords => _records.isNotEmpty;

  bool get isEmpty =>
      _hasLoaded && !_isLoading && _records.isEmpty && _errorMessage == null;

  bool get hasNoFilterResults =>
      hasActiveDateFilter && _records.isNotEmpty && filteredRecords.isEmpty;

  String? get errorMessage => _errorMessage;

  String? get filterErrorMessage => _filterErrorMessage;

  String? get actionErrorMessage => _actionErrorMessage;

  DateTime? get startDate => _startDate;

  DateTime? get endDate => _endDate;

  DateTime? get pendingStartDate => _pendingStartDate;

  DateTime? get pendingEndDate => _pendingEndDate;

  bool get hasActiveDateFilter => _startDate != null || _endDate != null;

  bool get hasPendingDateFilter =>
      _pendingStartDate != null || _pendingEndDate != null;

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
      final recovered = await _repository.recoverBehaviors(
        anonymousId: anonymousId,
      );

      final matching = recovered
          .where((record) => record.anonymousId == anonymousId)
          .toList();

      matching.sort(_compareRecords);

      _records = List.unmodifiable(matching);

      _hasLoaded = true;

      return true;
    } on BehaviorFailure catch (failure) {
      _errorMessage = failure.message;
      _hasLoaded = true;

      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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
    _startDate = null;
    _endDate = null;
    _pendingStartDate = null;
    _pendingEndDate = null;
    _filterErrorMessage = null;

    notifyListeners();
  }

  bool isDeleting(String recordId) {
    return _deletingRecordIds.contains(recordId);
  }

  Future<bool> deleteBehavior(BehaviorRecord record) async {
    if (record.anonymousId != anonymousId) {
      _actionErrorMessage = 'No fue posible eliminar esta conducta.';

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
      await _repository.deleteBehavior(
        anonymousId: anonymousId,
        recordId: record.recordId,
      );

      _records = List.unmodifiable(
        _records
            .where((current) => current.recordId != record.recordId)
            .toList(),
      );

      return true;
    } on BehaviorFailure catch (failure) {
      _actionErrorMessage = failure.message;

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

  static int _compareRecords(BehaviorRecord first, BehaviorRecord second) {
    final byEventDate = second.eventDateTime.compareTo(first.eventDateTime);

    if (byEventDate != 0) {
      return byEventDate;
    }

    return second.createdAt.compareTo(first.createdAt);
  }

  static DateTime _dateOnly(DateTime value) {
    final local = value.toLocal();

    return DateTime(local.year, local.month, local.day);
  }
}
