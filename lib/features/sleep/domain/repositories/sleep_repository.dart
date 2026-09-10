import '../models/sleep_record.dart';

abstract interface class SleepRepository {
  Future<void> saveSleep(SleepRecord record);

  Future<List<SleepRecord>> recoverSleepRecords({required String anonymousId});
}
