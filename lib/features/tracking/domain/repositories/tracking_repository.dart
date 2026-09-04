import '../models/anonymous_tracking_profile.dart';

abstract interface class TrackingRepository {
  Future<void> persistProfile(AnonymousTrackingProfile profile);

  Future<List<AnonymousTrackingProfile>> recoverProfiles();
}
