import '../../domain/models/dysregulation_record.dart';

abstract interface class DysregulationRemoteService {
  Future<void> saveDysregulation(DysregulationRecord record);

  Future<List<DysregulationRecord>> recoverDysregulations({
    required String anonymousId,
  });
}
