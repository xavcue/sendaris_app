import 'package:uuid/uuid.dart';

import '../../domain/services/routine_status_record_id_generator.dart';

class UuidRoutineStatusRecordIdGenerator
    implements RoutineStatusRecordIdGenerator {
  UuidRoutineStatusRecordIdGenerator({Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String generate() {
    return _uuid.v4();
  }
}
