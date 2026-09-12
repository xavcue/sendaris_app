import 'package:uuid/uuid.dart';

import '../../domain/services/social_interaction_record_id_generator.dart';

class UuidSocialInteractionRecordIdGenerator
    implements SocialInteractionRecordIdGenerator {
  UuidSocialInteractionRecordIdGenerator({Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String generate() {
    return _uuid.v4();
  }
}
