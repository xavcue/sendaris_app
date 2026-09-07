import 'atypical_situation_category.dart';

class AtypicalSituationRecord {
  const AtypicalSituationRecord({
    required this.recordId,
    required this.anonymousId,
    required this.date,
    required this.category,
    required this.observation,
    required this.createdAt,
    required this.updatedAt,
  });

  final String recordId;

  final String anonymousId;

  final DateTime date;

  final AtypicalSituationCategory category;

  final String observation;

  final DateTime createdAt;

  final DateTime updatedAt;
}
