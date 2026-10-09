import '../models/event_record.dart';

abstract interface class EventRepository {
  Future<List<EventRecord>> recoverEvents({required String anonymousId});
}
