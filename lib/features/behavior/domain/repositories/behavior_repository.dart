import '../models/behavior_record.dart';

abstract interface class BehaviorRepository {
  Future<void> saveBehavior(BehaviorRecord record);

  Future<List<BehaviorRecord>> recoverBehaviors({required String anonymousId});
}
