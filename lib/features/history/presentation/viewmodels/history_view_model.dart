import 'package:flutter/foundation.dart';

import '../../domain/exceptions/history_failure.dart';
import '../../domain/models/history_record.dart';
import '../../domain/repositories/history_repository.dart';

class HistoryViewModel extends ChangeNotifier {
  HistoryViewModel(this._repository, {required this.anonymousId});

  final HistoryRepository _repository;

  final String anonymousId;

  List<HistoryRecord> _records = const [];

  bool _isLoading = false;
  bool _hasLoaded = false;

  String? _errorMessage;

  List<HistoryRecord> get records => List.unmodifiable(_records);

  bool get isLoading => _isLoading;

  bool get hasLoaded => _hasLoaded;

  String? get errorMessage => _errorMessage;

  bool get hasRecords => _records.isNotEmpty;

  bool get isEmpty =>
      _hasLoaded && !_isLoading && _records.isEmpty && _errorMessage == null;

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

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;

    notifyListeners();
  }

  List<HistoryRecord> _sortByEventDate(Iterable<HistoryRecord> records) {
    final result = records.toList();

    result.sort((first, second) => second.eventDate.compareTo(first.eventDate));

    return List.unmodifiable(result);
  }
}
