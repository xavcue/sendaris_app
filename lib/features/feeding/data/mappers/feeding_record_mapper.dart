import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/feeding_category.dart';
import '../../domain/models/feeding_record.dart';

abstract final class FeedingRecordMapper {
  static const String recordType = 'alimentacion';

  static const Set<String> allowedTopLevelFields = {
    'tipoRegistro',
    'fechaEvento',
    'fechaCreacion',
    'fechaActualizacion',
    'uidOperacion',
    'datos',
  };

  static const Set<String> allowedFeedingFields = {
    'fecha',
    'categoria',
    'observacion',
  };

  static Map<String, dynamic> toFirestore({
    required FeedingRecord record,
    required String operationUid,
  }) {
    final normalizedUid = operationUid.trim();

    if (normalizedUid.isEmpty) {
      throw const FormatException('El UID de operación no puede estar vacío.');
    }

    final eventDate = DateTime.utc(
      record.date.year,
      record.date.month,
      record.date.day,
    );

    final feedingData = <String, dynamic>{
      'fecha': Timestamp.fromDate(eventDate),
      'categoria': record.category.code,
    };

    final observation = record.observation;

    if (observation != null) {
      feedingData['observacion'] = observation;
    }

    return {
      'tipoRegistro': recordType,
      'fechaEvento': Timestamp.fromDate(eventDate),
      'fechaCreacion': Timestamp.fromDate(record.createdAt.toUtc()),
      'fechaActualizacion': Timestamp.fromDate(record.updatedAt.toUtc()),
      'uidOperacion': normalizedUid,
      'datos': feedingData,
    };
  }

  static FeedingRecord fromFirestore({
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

    final rawFeedingData = data['datos'];

    if (rawRecordType != recordType) {
      throw const FormatException(
        'El documento no corresponde a un registro de alimentación.',
      );
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

    if (rawFeedingData is! Map) {
      throw const FormatException(
        'Los datos de alimentación no tienen un formato válido.',
      );
    }

    final feedingData = Map<String, dynamic>.from(rawFeedingData);

    final feedingKeys = feedingData.keys.toSet();

    final requiredFields = {'fecha', 'categoria'};

    if (!feedingKeys.containsAll(requiredFields) ||
        !allowedFeedingFields.containsAll(feedingKeys)) {
      throw const FormatException(
        'Los datos de alimentación contienen una estructura no permitida.',
      );
    }

    final rawDate = feedingData['fecha'];

    final rawCategory = feedingData['categoria'];

    final rawObservation = feedingData['observacion'];

    if (rawDate is! Timestamp) {
      throw const FormatException(
        'La fecha del registro de alimentación no es válida.',
      );
    }

    if (rawCategory is! String || rawCategory.trim().isEmpty) {
      throw const FormatException('La categoría de alimentación no es válida.');
    }

    if (rawObservation != null &&
        (rawObservation is! String || rawObservation.trim().isEmpty)) {
      throw const FormatException(
        'La observación del registro de alimentación no es válida.',
      );
    }

    final eventDate = rawEventDate.toDate().toUtc();

    final feedingDate = rawDate.toDate().toUtc();

    final normalizedEventDate = DateTime.utc(
      eventDate.year,
      eventDate.month,
      eventDate.day,
    );

    final normalizedFeedingDate = DateTime.utc(
      feedingDate.year,
      feedingDate.month,
      feedingDate.day,
    );

    if (normalizedEventDate != normalizedFeedingDate) {
      throw const FormatException(
        'La fecha del evento no coincide con la fecha del registro de alimentación.',
      );
    }

    return FeedingRecord(
      recordId: normalizedRecordId,
      anonymousId: normalizedAnonymousId,
      date: DateTime(feedingDate.year, feedingDate.month, feedingDate.day),
      category: FeedingCategory.fromCode(rawCategory),
      observation: rawObservation?.trim(),
      createdAt: rawCreatedAt.toDate().toUtc(),
      updatedAt: rawUpdatedAt.toDate().toUtc(),
    );
  }
}
