import 'package:uuid/uuid.dart';

import '../../domain/services/behavior_record_id_generator.dart';

class UuidBehaviorRecordIdGenerator implements BehaviorRecordIdGenerator {
  UuidBehaviorRecordIdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String generate() {
    return _uuid.v4();
  }
}
