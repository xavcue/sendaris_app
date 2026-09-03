import 'package:uuid/uuid.dart';

import '../../domain/services/anonymous_id_generator.dart';

class UuidAnonymousIdGenerator implements AnonymousIdGenerator {
  UuidAnonymousIdGenerator({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  String generate() {
    return _uuid.v4();
  }
}
