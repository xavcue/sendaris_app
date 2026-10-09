import '../../domain/models/behavior_record.dart';

abstract interface class BehaviorRemoteService {
  Future<void> saveBehavior(BehaviorRecord record);

  Future<List<BehaviorRecord>> recoverBehaviors({required String anonymousId});
}

abstract interface class BehaviorManagementRemoteService
    implements BehaviorRemoteService {
  Future<void> updateBehavior(BehaviorRecord record);

  Future<void> deleteBehavior({
    required String anonymousId,
    required String recordId,
  });
}
