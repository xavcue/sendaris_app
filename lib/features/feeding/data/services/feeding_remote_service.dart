import '../../domain/models/feeding_record.dart';

abstract interface class FeedingRemoteService {
  Future<void> saveFeeding(FeedingRecord record);

  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  });
}

abstract interface class FeedingManagementRemoteService
    implements FeedingRemoteService {
  Future<void> updateFeeding(FeedingRecord record);

  Future<void> deleteFeeding({
    required String anonymousId,
    required String recordId,
  });
}
