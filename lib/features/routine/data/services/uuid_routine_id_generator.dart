import 'package:uuid/uuid.dart';

import '../../domain/services/routine_id_generator.dart';

class UuidRoutineIdGenerator implements RoutineIdGenerator {
  UuidRoutineIdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String generate() {
    return _uuid.v4();
  }
}
