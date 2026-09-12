import '../../domain/models/social_interaction_record.dart';

abstract interface class SocialInteractionRemoteService {
  Future<void> saveSocialInteraction(SocialInteractionRecord record);

  Future<List<SocialInteractionRecord>> recoverSocialInteractions({
    required String anonymousId,
  });
}
