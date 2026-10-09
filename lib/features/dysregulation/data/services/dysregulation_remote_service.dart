import '../../domain/models/dysregulation_record.dart';

abstract interface class DysregulationRemoteService {
  Future<void> saveDysregulation(DysregulationRecord record);

  Future<List<DysregulationRecord>> recoverDysregulations({
    required String anonymousId,
  });
}

abstract interface class DysregulationManagementRemoteService
    implements DysregulationRemoteService {
  Future<void> updateDysregulation(DysregulationRecord record);

  Future<void> deleteDysregulation({
    required String anonymousId,
    required String recordId,
  });
}
