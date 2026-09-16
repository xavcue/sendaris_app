import '../models/history_record.dart';

abstract interface class HistoryRepository {
  Future<List<HistoryRecord>> recoverHistory({required String anonymousId});
}
