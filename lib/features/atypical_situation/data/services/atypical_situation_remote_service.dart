import '../../domain/models/atypical_situation_record.dart';

abstract interface class AtypicalSituationRemoteService {
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record);

  Future<List<AtypicalSituationRecord>> recoverAtypicalSituations({
    required String anonymousId,
  });
}

abstract interface class AtypicalSituationManagementRemoteService
    implements AtypicalSituationRemoteService {
  Future<void> updateAtypicalSituation(AtypicalSituationRecord record);

  Future<void> deleteAtypicalSituation({
    required String anonymousId,
    required String recordId,
  });
}
