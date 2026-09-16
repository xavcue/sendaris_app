import 'history_record_type.dart';

class HistoryRecord {
  const HistoryRecord({
    required this.recordId,
    required this.anonymousId,
    required this.type,
    required this.eventDate,
  });

  final String recordId;
  final String anonymousId;
  final HistoryRecordType type;
  final DateTime eventDate;
}
