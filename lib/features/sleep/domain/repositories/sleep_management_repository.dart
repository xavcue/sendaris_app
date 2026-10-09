import '../models/sleep_record.dart';
import 'sleep_repository.dart';

abstract interface class SleepManagementRepository implements SleepRepository {
  Future<void> updateSleep(SleepRecord record);

  Future<void> deleteSleep({
    required String anonymousId,
    required String recordId,
  });
}
