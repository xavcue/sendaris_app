import '../../domain/models/history_record.dart';

abstract interface class HistoryRemoteService {
  Future<List<HistoryRecord>> recoverHistory({required String anonymousId});
}
