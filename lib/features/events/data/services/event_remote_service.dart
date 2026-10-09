import '../../domain/models/event_record.dart';

abstract interface class EventRemoteService {
  Future<List<EventRecord>> recoverEvents({required String anonymousId});
}
