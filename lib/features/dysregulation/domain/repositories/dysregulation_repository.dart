import '../models/dysregulation_record.dart';

abstract interface class DysregulationRepository {
  Future<void> saveDysregulation(DysregulationRecord record);

  Future<List<DysregulationRecord>> recoverDysregulations({
    required String anonymousId,
  });
}
