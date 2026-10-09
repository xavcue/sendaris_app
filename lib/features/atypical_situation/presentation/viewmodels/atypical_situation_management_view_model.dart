import 'package:flutter/foundation.dart';

import '../../domain/exceptions/atypical_situation_failure.dart';
import '../../domain/models/atypical_situation_record.dart';
import '../../domain/repositories/atypical_situation_management_repository.dart';

class AtypicalSituationManagementViewModel extends ChangeNotifier {
  AtypicalSituationManagementViewModel(
    this._repository, {
    required this.anonymousId,
  });

  final AtypicalSituationManagementRepository _repository;
  final String anonymousId;

  final List<AtypicalSituationRecord> _allRecords = [];

  final Set<String> _deletingRecordIds = {};

  bool _isLoading = false;
  bool _hasLoaded = false;

  String? _loadError;
  String? _actionError;
  String? _filterError;

  DateTime? _pendingStartDate;
  DateTime? _pendingEndDate;

  DateTime? _appliedStartDate;
  DateTime? _appliedEndDate;

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  String? get loadError => _loadError;

  String? get actionError => _actionError;

  String? get filterError => _filterError;

  DateTime? get pendingStartDate => _pendingStartDate;

  DateTime? get pendingEndDate => _pendingEndDate;

  DateTime? get appliedStartDate => _appliedStartDate;

  DateTime? get appliedEndDate => _appliedEndDate;

  bool get hasPendingDateFilter =>
      _pendingStartDate != null || _pendingEndDate != null;

  bool get hasAppliedDateFilter =>
      _appliedStartDate != null || _appliedEndDate != null;

  bool get hasRecords => _allRecords.isNotEmpty;

  bool get isEmpty => _hasLoaded && _allRecords.isEmpty;

  bool get hasNoFilterResults =>
      hasAppliedDateFilter && _allRecords.isNotEmpty && records.isEmpty;

  int get recordCount => records.length;

  int get totalRecordCount => _allRecords.length;

  List<AtypicalSituationRecord> get records {
    final visibleRecords = _allRecords.where(_matchesAppliedDateFilter);

    return List.unmodifiable(visibleRecords);
  }

  bool isDeleting(String recordId) {
    return _deletingRecordIds.contains(recordId);
  }

  Future<bool> load() async {
    if (_isLoading) {
      return false;
    }

    return _loadRecords();
  }

  Future<bool> reload() async {
    if (_isLoading) {
      return false;
    }

    return _loadRecords();
  }

  void setPendingStartDate(DateTime? value) {
    _pendingStartDate = value == null ? null : _dateOnly(value);

    _filterError = null;

    notifyListeners();
  }

  void setPendingEndDate(DateTime? value) {
    _pendingEndDate = value == null ? null : _dateOnly(value);

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

  Future<bool> deleteAtypicalSituation(AtypicalSituationRecord record) async {
    if (_deletingRecordIds.contains(record.recordId)) {
      return false;
    }

    _actionError = null;

    _deletingRecordIds.add(record.recordId);

    notifyListeners();

    try {
      await _repository.deleteAtypicalSituation(
        anonymousId: record.anonymousId,
        recordId: record.recordId,
      );

      _allRecords.removeWhere(
        (currentRecord) => currentRecord.recordId == record.recordId,
      );

      return true;
    } on AtypicalSituationFailure catch (failure) {
      _actionError = failure.message;

      return false;
    } catch (_) {
      _actionError =
          'No fue posible eliminar el registro '
          'de otra situación. '
          'Inténtalo nuevamente.';

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

  Future<bool> _loadRecords() async {
    _isLoading = true;
    _loadError = null;

    notifyListeners();

    try {
      final recoveredRecords = List<AtypicalSituationRecord>.from(
        await _repository.recoverAtypicalSituations(anonymousId: anonymousId),
      );

      recoveredRecords.sort(_compareRecords);

      _allRecords
        ..clear()
        ..addAll(recoveredRecords);

      _hasLoaded = true;

      return true;
    } on AtypicalSituationFailure catch (failure) {
      _loadError = failure.message;

      return false;
    } catch (_) {
      _loadError =
          'No fue posible cargar los registros '
          'de otra situación. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _isLoading = false;

      notifyListeners();
    }
  }

  bool _matchesAppliedDateFilter(AtypicalSituationRecord record) {
    final recordDate = _dateOnly(record.date);

    final startDate = _appliedStartDate;

    if (startDate != null && recordDate.isBefore(startDate)) {
      return false;
    }

    final endDate = _appliedEndDate;

    if (endDate != null && recordDate.isAfter(endDate)) {
      return false;
    }

    return true;
  }

  int _compareRecords(
    AtypicalSituationRecord first,
    AtypicalSituationRecord second,
  ) {
    final dateComparison = _dateOnly(second.date)
        .compareTo(_dateOnly(first.date));

    if (dateComparison != 0) {
      return dateComparison;
    }

    return second.createdAt.compareTo(first.createdAt);
  }

  DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
