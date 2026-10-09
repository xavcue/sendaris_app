import '../../domain/models/social_interaction_record.dart';

abstract interface class SocialInteractionRemoteService {
  Future<void> saveSocialInteraction(SocialInteractionRecord record);

  Future<List<SocialInteractionRecord>> recoverSocialInteractions({
    required String anonymousId,
  });
}

abstract interface class SocialInteractionManagementRemoteService
    implements SocialInteractionRemoteService {
  Future<void> updateSocialInteraction(SocialInteractionRecord record);

  Future<void> deleteSocialInteraction({
    required String anonymousId,
    required String recordId,
  });
}
