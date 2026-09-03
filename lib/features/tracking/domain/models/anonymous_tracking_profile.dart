class AnonymousTrackingProfile {
  const AnonymousTrackingProfile({
    required this.anonymousId,
    required this.createdAt,
    this.isActive = true,
  });

  final String anonymousId;
  final DateTime createdAt;
  final bool isActive;
}
