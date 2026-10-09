import '../../domain/models/sleep_record.dart';

abstract interface class SleepRemoteService {
  Future<void> saveSleep(SleepRecord record);

  Future<List<SleepRecord>> recoverSleepRecords({required String anonymousId});
}

abstract interface class SleepManagementRemoteService
    implements SleepRemoteService {
  Future<void> updateSleep(SleepRecord record);

  Future<void> deleteSleep({
    required String anonymousId,
    required String recordId,
  });
}
