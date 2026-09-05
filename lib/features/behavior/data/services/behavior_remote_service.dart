import '../../domain/models/behavior_record.dart';

abstract interface class BehaviorRemoteService {
  Future<void> saveBehavior(BehaviorRecord record);

  Future<List<BehaviorRecord>> recoverBehaviors({required String anonymousId});
}
