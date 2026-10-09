import '../models/atypical_situation_record.dart';
import 'atypical_situation_repository.dart';

abstract interface class AtypicalSituationManagementRepository
    implements AtypicalSituationRepository {
  Future<void> updateAtypicalSituation(AtypicalSituationRecord record);

  Future<void> deleteAtypicalSituation({
    required String anonymousId,
    required String recordId,
  });
}
