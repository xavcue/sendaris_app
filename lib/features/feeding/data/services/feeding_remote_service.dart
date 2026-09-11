import '../../domain/models/feeding_record.dart';

abstract interface class FeedingRemoteService {
  Future<void> saveFeeding(FeedingRecord record);

  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  });
}
