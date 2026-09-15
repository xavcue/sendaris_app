import 'package:uuid/uuid.dart';

import '../../domain/services/dysregulation_record_id_generator.dart';

class UuidDysregulationRecordIdGenerator
    implements DysregulationRecordIdGenerator {
  UuidDysregulationRecordIdGenerator({Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String generate() {
    return _uuid.v4();
  }
}
