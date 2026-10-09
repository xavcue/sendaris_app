import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/event_record.dart';
import '../../domain/models/event_record_type.dart';

abstract final class EventRecordMapper {
  static const Set<String> allowedTopLevelFields = {
    'tipoRegistro',
    'fechaEvento',
    'fechaCreacion',
    'fechaActualizacion',
    'uidOperacion',
    'datos',
  };

  static EventRecord fromFirestore({
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
      throw const FormatException('El seguimiento actual no es válido.');
    }

    final topLevelKeys = data.keys.toSet();

    if (!topLevelKeys.containsAll(allowedTopLevelFields) ||
        !allowedTopLevelFields.containsAll(topLevelKeys)) {
      throw const FormatException(
        'El evento contiene una estructura no permitida.',
      );
    }

    final rawRecordType = data['tipoRegistro'];

    final rawEventDate = data['fechaEvento'];

    final rawCreatedAt = data['fechaCreacion'];

    final rawUpdatedAt = data['fechaActualizacion'];

    final rawOperationUid = data['uidOperacion'];

    final rawRecordData = data['datos'];

    if (rawRecordType is! String || rawRecordType.isEmpty) {
      throw const FormatException('El tipo de evento no es válido.');
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
        'Los datos del evento no tienen un formato válido.',
      );
    }

    final type = EventRecordType.fromCode(rawRecordType);

    final eventDateUtc = rawEventDate.toDate().toUtc();

    final eventDate = _normalizeEventDate(
      type: type,
      eventDateUtc: eventDateUtc,
    );

    final createdAt = rawCreatedAt.toDate().toUtc();

    final details = Map<String, dynamic>.from(rawRecordData);

    return EventRecord(
      recordId: normalizedRecordId,
      anonymousId: normalizedAnonymousId,
      type: type,
      eventDate: eventDate,
      createdAt: createdAt,
      details: details,
    );
  }

  static DateTime _normalizeEventDate({
    required EventRecordType type,
    required DateTime eventDateUtc,
  }) {
    switch (type) {
      case EventRecordType.behavior:
      case EventRecordType.sleep:
      case EventRecordType.dysregulation:
        return eventDateUtc;

      case EventRecordType.feeding:
      case EventRecordType.socialInteraction:
      case EventRecordType.atypicalSituation:
        return DateTime(
          eventDateUtc.year,
          eventDateUtc.month,
          eventDateUtc.day,
        );
    }
  }
}
