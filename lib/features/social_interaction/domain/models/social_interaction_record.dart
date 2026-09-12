import 'social_interaction_category.dart';

class SocialInteractionRecord {
  const SocialInteractionRecord({
    required this.recordId,
    required this.anonymousId,
    required this.date,
    required this.category,
    required this.createdAt,
    required this.updatedAt,
    this.context,
    this.observation,
  });

  final String recordId;

  final String anonymousId;

  final DateTime date;

  final SocialInteractionCategory category;

  final String? context;

  final String? observation;

  final DateTime createdAt;

  final DateTime updatedAt;
}
