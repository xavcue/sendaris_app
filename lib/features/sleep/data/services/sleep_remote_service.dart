import '../../domain/models/sleep_record.dart';

abstract interface class SleepRemoteService {
  Future<void> saveSleep(SleepRecord record);

  Future<List<SleepRecord>> recoverSleepRecords({required String anonymousId});
}
