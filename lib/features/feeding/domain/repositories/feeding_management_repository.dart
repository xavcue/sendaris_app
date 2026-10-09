import '../models/feeding_record.dart';
import 'feeding_repository.dart';

abstract interface class FeedingManagementRepository
    implements FeedingRepository {
  Future<void> updateFeeding(FeedingRecord record);

  Future<void> deleteFeeding({
    required String anonymousId,
    required String recordId,
  });
}
