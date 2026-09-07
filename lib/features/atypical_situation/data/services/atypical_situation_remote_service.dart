import '../../domain/models/atypical_situation_record.dart';

abstract interface class AtypicalSituationRemoteService {
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record);

  Future<List<AtypicalSituationRecord>> recoverAtypicalSituations({
    required String anonymousId,
  });
}
