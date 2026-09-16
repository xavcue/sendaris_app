import '../exceptions/history_filter_validation_failure.dart';
import '../validation/history_filter_validator.dart';
import 'history_record.dart';
import 'history_record_type.dart';

class HistoryFilter {
  HistoryFilter._({
    required this.startDate,
    required this.endDate,
    required Set<HistoryRecordType> selectedTypes,
  }) : selectedTypes = Set.unmodifiable(selectedTypes);

  factory HistoryFilter.empty() {
    return HistoryFilter._(
      startDate: null,
      endDate: null,
      selectedTypes: const <HistoryRecordType>{},
    );
  }

  factory HistoryFilter.create({
    DateTime? startDate,
    DateTime? endDate,
    Iterable<HistoryRecordType> selectedTypes = const [],
  }) {
    final errors = HistoryFilterValidator.validate(
      startDate: startDate,
      endDate: endDate,
    );

    if (errors.isNotEmpty) {
      throw HistoryFilterValidationFailure(errors);
    }

    return HistoryFilter._(
      startDate: startDate == null ? null : _dateOnly(startDate),
      endDate: endDate == null ? null : _dateOnly(endDate),
      selectedTypes: selectedTypes.toSet(),
    );
  }

  final DateTime? startDate;

  final DateTime? endDate;

  final Set<HistoryRecordType> selectedTypes;

  bool get hasPeriodFilter => startDate != null && endDate != null;

  bool get hasTypeFilter => selectedTypes.isNotEmpty;

  bool get isActive => hasPeriodFilter || hasTypeFilter;

  bool matches(HistoryRecord record) {
    final localEventDate = _dateOnly(record.eventDate.toLocal());

    final currentStartDate = startDate;

    if (currentStartDate != null && localEventDate.isBefore(currentStartDate)) {
      return false;
    }

    final currentEndDate = endDate;

    if (currentEndDate != null && localEventDate.isAfter(currentEndDate)) {
      return false;
    }

    if (selectedTypes.isNotEmpty && !selectedTypes.contains(record.type)) {
      return false;
    }

    return true;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }
}
