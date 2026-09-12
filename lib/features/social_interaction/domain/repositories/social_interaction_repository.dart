import '../models/social_interaction_record.dart';

abstract interface class SocialInteractionRepository {
  Future<void> saveSocialInteraction(SocialInteractionRecord record);

  Future<List<SocialInteractionRecord>> recoverSocialInteractions({
    required String anonymousId,
  });
}
