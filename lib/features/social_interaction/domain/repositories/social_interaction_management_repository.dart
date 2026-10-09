import '../models/social_interaction_record.dart';
import 'social_interaction_repository.dart';

abstract interface class SocialInteractionManagementRepository
    implements SocialInteractionRepository {
  Future<void> updateSocialInteraction(SocialInteractionRecord record);

  Future<void> deleteSocialInteraction({
    required String anonymousId,
    required String recordId,
  });
}
