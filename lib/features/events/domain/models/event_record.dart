import 'event_record_type.dart';

class EventRecord {
  const EventRecord({
    required this.recordId,
    required this.anonymousId,
    required this.type,
    required this.eventDate,
    DateTime? createdAt,
    this.details = const <String, dynamic>{},
  }) : createdAt = createdAt ?? eventDate;

  final String recordId;

  final String anonymousId;

  final EventRecordType type;

  final DateTime eventDate;

  final DateTime createdAt;

  final Map<String, dynamic> details;
}
