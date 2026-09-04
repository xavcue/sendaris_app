import '../../domain/models/anonymous_tracking_profile.dart';

abstract interface class TrackingRemoteService {
  Future<void> persistProfile(AnonymousTrackingProfile profile);

  Future<List<AnonymousTrackingProfile>> recoverProfiles();
}
