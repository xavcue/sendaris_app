import '../../domain/models/anonymous_tracking_profile.dart';

abstract interface class TrackingObservationRemoteService {
  Stream<List<AnonymousTrackingProfile>> watchProfiles();
}
