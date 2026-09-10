import 'package:uuid/uuid.dart';

import '../../domain/services/sleep_record_id_generator.dart';

class UuidSleepRecordIdGenerator implements SleepRecordIdGenerator {
  UuidSleepRecordIdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String generate() {
    return _uuid.v4();
  }
}
