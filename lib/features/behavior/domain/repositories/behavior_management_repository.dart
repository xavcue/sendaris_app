import '../models/behavior_record.dart';
import 'behavior_repository.dart';

abstract interface class BehaviorManagementRepository
    implements BehaviorRepository {
  Future<void> updateBehavior(BehaviorRecord record);

  Future<void> deleteBehavior({
    required String anonymousId,
    required String recordId,
  });
}
