import 'package:flutter/foundation.dart';

import '../../data/repositories/composite_monthly_calendar_repository.dart';
import '../../domain/models/monthly_calendar_record.dart';

class MonthlyCalendarViewModel extends ChangeNotifier {
  MonthlyCalendarViewModel(
    this._repository, {
    required this.anonymousId,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now {
    final today = _dateOnly(_clock());

    _visibleMonth = DateTime(today.year, today.month);
    _selectedDate = today;
  }

  final MonthlyCalendarRepository _repository;
  final DateTime Function() _clock;

  final String anonymousId;

  late DateTime _visibleMonth;
  late DateTime _selectedDate;

  final Set<CalendarRecordType> _selectedTypes = CalendarRecordType.values
      .toSet();

  DateTime? _startDate;
  DateTime? _endDate;

  MonthlyCalendarIndex? _index;

  bool _isLoading = false;
  bool _filtersExpanded = false;
  bool _disposed = false;

  String? _errorMessage;

  int _requestVersion = 0;

  DateTime get visibleMonth => _visibleMonth;
  DateTime get selectedDate => _selectedDate;

  DateTime? get startDate => _startDate;
  DateTime? get endDate => _endDate;

  Set<CalendarRecordType> get selectedTypes =>
      Set<CalendarRecordType>.unmodifiable(_selectedTypes);

  MonthlyCalendarIndex? get index => _index;

  bool get isLoading => _isLoading;
  bool get filtersExpanded => _filtersExpanded;
  bool get isDisposed => _disposed;

  bool get hasDateFilter => _startDate != null || _endDate != null;

  String? get errorMessage => _errorMessage;

  // El límite superior es el año actual y se consulta
  // dinámicamente, sin mantener un año fijo en el código.
  bool get canGoToNextMonth {
    final currentYear = _clock().year;

    return _visibleMonth.year < currentYear ||
        (_visibleMonth.year == currentYear && _visibleMonth.month < 12);
  }

  int get monthCount {
    return _index?.countForMonth(
          _visibleMonth,
          selectedTypes: _selectedTypes,
          startDate: _startDate,
          endDate: _endDate,
        ) ??
        0;
  }

  List<MonthlyCalendarRecord> get selectedDayRecords {
    return _index?.recordsFor(
          _selectedDate,
          selectedTypes: _selectedTypes,
          startDate: _startDate,
          endDate: _endDate,
        ) ??
        const <MonthlyCalendarRecord>[];
  }

  int countForDay(DateTime date) {
    return _index?.countFor(
          date,
          selectedTypes: _selectedTypes,
          startDate: _startDate,
          endDate: _endDate,
        ) ??
        0;
  }

  void changeMonth(int offset) {
    if (_disposed || offset == 0) {
      return;
    }

    final nextMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + offset,
    );

    if (nextMonth.year > _clock().year) {
      return;
    }

    _visibleMonth = nextMonth;
    _selectedDate = DateTime(_visibleMonth.year, _visibleMonth.month);

    notifyListeners();
  }

  void selectDate(DateTime date) {
    if (_disposed) {
      return;
    }

    final normalized = _dateOnly(date);

    if (normalized.year > _clock().year) {
      return;
    }

    if (_selectedDate == normalized) {
      return;
    }

    _selectedDate = normalized;
    _visibleMonth = DateTime(normalized.year, normalized.month);

    notifyListeners();
  }

  void toggleFilters() {
    if (_disposed) {
      return;
    }

    _filtersExpanded = !_filtersExpanded;

    notifyListeners();
  }

  void setTypeSelected(CalendarRecordType type, {required bool selected}) {
    if (_disposed) {
      return;
    }

    final changed = selected
        ? _selectedTypes.add(type)
        : _selectedTypes.remove(type);

    if (changed) {
      notifyListeners();
    }
  }

  void selectAllTypes() {
    if (_disposed) {
      return;
    }

    if (_selectedTypes.length == CalendarRecordType.values.length) {
      return;
    }

    _selectedTypes.addAll(CalendarRecordType.values);

    notifyListeners();
  }

  void selectStartDate(DateTime date) {
    if (_disposed) {
      return;
    }

    final normalized = _dateOnly(date);

    _startDate = normalized;

    if (_endDate != null && _endDate!.isBefore(normalized)) {
      _endDate = normalized;
    }

    _selectedDate = normalized;
    _visibleMonth = DateTime(normalized.year, normalized.month);

    notifyListeners();
  }

  void selectEndDate(DateTime date) {
    if (_disposed) {
      return;
    }

    final normalized = _dateOnly(date);

    _endDate = normalized;

    if (_startDate != null && _startDate!.isAfter(normalized)) {
      _startDate = normalized;
    }

    _selectedDate = normalized;
    _visibleMonth = DateTime(normalized.year, normalized.month);

    notifyListeners();
  }

  void clearDateFilters() {
    if (_disposed || !hasDateFilter) {
      return;
    }

    _startDate = null;
    _endDate = null;

    notifyListeners();
  }

  Future<void> load() async {
    if (_disposed) {
      return;
    }

    final request = ++_requestVersion;
    final expectedId = anonymousId.trim();

    _isLoading = true;
    _errorMessage = null;
    _index = null;

    notifyListeners();

    try {
      final result = await _repository.recover(anonymousId: expectedId);

      if (!_isRequestCurrent(request)) {
        return;
      }

      if (result.anonymousId != expectedId) {
        _showError(request, 'No se pudo validar el seguimiento.');
        return;
      }

      _index = result;
      _isLoading = false;
      _errorMessage = null;

      notifyListeners();
    } catch (_) {
      _showError(
        request,
        'No fue posible cargar los registros. '
        'Comprueba tu conexión e inténtalo nuevamente.',
      );
    }
  }

  void _showError(int request, String message) {
    if (!_isRequestCurrent(request)) {
      return;
    }

    _index = null;
    _isLoading = false;
    _errorMessage = message;

    notifyListeners();
  }

  bool _isRequestCurrent(int request) {
    return !_disposed && request == _requestVersion;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _requestVersion++;

    super.dispose();
  }
}
