import 'feeding_category.dart';

class FeedingRecord {
  const FeedingRecord({
    required this.recordId,
    required this.anonymousId,
    required this.date,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.observation,
  });

  final String recordId;

  final String anonymousId;

  final DateTime date;

  final FeedingCategory category;

  final String? observation;

  final DateTime createdAt;

  final DateTime updatedAt;
}
