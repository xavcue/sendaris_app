import 'package:uuid/uuid.dart';

import '../../domain/services/atypical_situation_record_id_generator.dart';

class UuidAtypicalSituationRecordIdGenerator
    implements AtypicalSituationRecordIdGenerator {
  UuidAtypicalSituationRecordIdGenerator({Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String generate() {
    return _uuid.v4();
  }
}
