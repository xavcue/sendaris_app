abstract interface class TrackingDeletionRepository {
  Future<void> deleteProfile(String anonymousId);
}
