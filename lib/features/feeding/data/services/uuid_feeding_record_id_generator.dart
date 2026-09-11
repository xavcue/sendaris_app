import 'package:uuid/uuid.dart';

import '../../domain/services/feeding_record_id_generator.dart';

class UuidFeedingRecordIdGenerator implements FeedingRecordIdGenerator {
  UuidFeedingRecordIdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String generate() {
    return _uuid.v4();
  }
}
