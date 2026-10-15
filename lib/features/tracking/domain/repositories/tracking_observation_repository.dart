import '../models/anonymous_tracking_profile.dart';

abstract interface class TrackingObservationRepository {
  Stream<List<AnonymousTrackingProfile>> watchProfiles();
}
