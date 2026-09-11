import '../models/feeding_record.dart';

abstract interface class FeedingRepository {
  Future<void> saveFeeding(FeedingRecord record);

  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  });
}
