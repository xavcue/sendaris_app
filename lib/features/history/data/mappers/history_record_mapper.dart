import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/history_record.dart';
import '../../domain/models/history_record_type.dart';

abstract final class HistoryRecordMapper {
  static const Set<String> allowedTopLevelFields = {
    'tipoRegistro',
    'fechaEvento',
    'fechaCreacion',
    'fechaActualizacion',
    'uidOperacion',
    'datos',
  };

  static HistoryRecord fromFirestore({
    required String recordId,
    required String anonymousId,
    required Map<String, dynamic> data,
  }) {
    final normalizedRecordId = recordId.trim();
    final normalizedAnonymousId = anonymousId.trim();

    if (normalizedRecordId.isEmpty || normalizedRecordId.contains('/')) {
      throw const FormatException(
        'El identificador del registro no es válido.',
      );
    }

    if (normalizedAnonymousId.isEmpty || normalizedAnonymousId.contains('/')) {
      throw const FormatException('El perfil activo no es válido.');
    }

    final topLevelKeys = data.keys.toSet();

    if (!topLevelKeys.containsAll(allowedTopLevelFields) ||
        !allowedTopLevelFields.containsAll(topLevelKeys)) {
      throw const FormatException(
        'El registro contiene una estructura no permitida.',
      );
    }

    final rawRecordType = data['tipoRegistro'];

    final rawEventDate = data['fechaEvento'];

    final rawCreatedAt = data['fechaCreacion'];

    final rawUpdatedAt = data['fechaActualizacion'];

    final rawOperationUid = data['uidOperacion'];

    final rawRecordData = data['datos'];

    if (rawRecordType is! String || rawRecordType.isEmpty) {
      throw const FormatException('El tipo de registro no es válido.');
    }

    if (rawEventDate is! Timestamp) {
      throw const FormatException('La fecha del evento no es válida.');
    }

    if (rawCreatedAt is! Timestamp) {
      throw const FormatException('La fecha de creación no es válida.');
    }

    if (rawUpdatedAt is! Timestamp) {
      throw const FormatException('La fecha de actualización no es válida.');
    }

    if (rawOperationUid is! String || rawOperationUid.trim().isEmpty) {
      throw const FormatException('El UID de operación no es válido.');
    }

    if (rawRecordData is! Map) {
      throw const FormatException(
        'Los datos del registro no tienen un formato válido.',
      );
    }

    final type = HistoryRecordType.fromCode(rawRecordType);

    return HistoryRecord(
      recordId: normalizedRecordId,
      anonymousId: normalizedAnonymousId,
      type: type,
      eventDate: rawEventDate.toDate().toUtc(),
    );
  }
}
