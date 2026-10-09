import '../models/dysregulation_record.dart';
import 'dysregulation_repository.dart';

abstract interface class DysregulationManagementRepository
    implements DysregulationRepository {
  Future<void> updateDysregulation(DysregulationRecord record);

  Future<void> deleteDysregulation({
    required String anonymousId,
    required String recordId,
  });
}
