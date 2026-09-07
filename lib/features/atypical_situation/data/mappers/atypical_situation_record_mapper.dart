import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/atypical_situation_category.dart';
import '../../domain/models/atypical_situation_record.dart';

abstract final class AtypicalSituationRecordMapper {
  static const String recordType = 'situacionAtipica';

  static const Set<String> allowedTopLevelFields = {
    'tipoRegistro',
    'fechaEvento',
    'fechaCreacion',
    'fechaActualizacion',
    'uidOperacion',
    'datos',
  };

  static const Set<String> allowedSituationFields = {
    'fecha',
    'categoriaGeneral',
    'observacion',
  };

  static Map<String, dynamic> toFirestore({
    required AtypicalSituationRecord record,
    required String operationUid,
  }) {
    final normalizedUid = operationUid.trim();
    final normalizedObservation = record.observation.trim();

    if (normalizedUid.isEmpty) {
      throw const FormatException('El UID de operación no puede estar vacío.');
    }

    if (normalizedObservation.isEmpty) {
      throw const FormatException(
        'La descripción de la situación no puede estar vacía.',
      );
    }

    final eventDate = DateTime.utc(
      record.date.year,
      record.date.month,
      record.date.day,
    );

    final situationData = <String, dynamic>{
      'fecha': Timestamp.fromDate(eventDate),
      'categoriaGeneral': record.category.code,
      'observacion': normalizedObservation,
    };

    return {
      'tipoRegistro': recordType,
      'fechaEvento': Timestamp.fromDate(eventDate),
      'fechaCreacion': Timestamp.fromDate(record.createdAt.toUtc()),
      'fechaActualizacion': Timestamp.fromDate(record.updatedAt.toUtc()),
      'uidOperacion': normalizedUid,
      'datos': situationData,
    };
  }

  static AtypicalSituationRecord fromFirestore({
    required String recordId,
    required String anonymousId,
    required Map<String, dynamic> data,
  }) {
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
    final rawSituationData = data['datos'];

    if (rawRecordType != recordType) {
      throw const FormatException(
        'El documento no corresponde a una situación.',
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

    if (rawSituationData is! Map) {
      throw const FormatException(
        'Los datos de la situación no tienen un formato válido.',
      );
    }

    final situationData = Map<String, dynamic>.from(rawSituationData);

    final situationKeys = situationData.keys.toSet();

    if (!situationKeys.containsAll(allowedSituationFields) ||
        !allowedSituationFields.containsAll(situationKeys)) {
      throw const FormatException(
        'Los datos de la situación contienen '
        'una estructura no permitida.',
      );
    }

    final rawDate = situationData['fecha'];
    final rawCategory = situationData['categoriaGeneral'];
    final rawObservation = situationData['observacion'];

    if (rawDate is! Timestamp) {
      throw const FormatException('La fecha de la situación no es válida.');
    }

    if (rawCategory is! String || rawCategory.trim().isEmpty) {
      throw const FormatException('La categoría de la situación no es válida.');
    }

    if (rawObservation is! String || rawObservation.trim().isEmpty) {
      throw const FormatException(
        'La descripción de la situación no es válida.',
      );
    }

    final eventDate = rawEventDate.toDate().toUtc();
    final situationDate = rawDate.toDate().toUtc();

    final normalizedEventDate = DateTime.utc(
      eventDate.year,
      eventDate.month,
      eventDate.day,
    );

    final normalizedSituationDate = DateTime.utc(
      situationDate.year,
      situationDate.month,
      situationDate.day,
    );

    if (normalizedEventDate != normalizedSituationDate) {
      throw const FormatException(
        'La fecha del evento no coincide '
        'con la fecha de la situación.',
      );
    }

    return AtypicalSituationRecord(
      recordId: recordId,
      anonymousId: anonymousId.trim(),
      date: DateTime(
        situationDate.year,
        situationDate.month,
        situationDate.day,
      ),
      category: AtypicalSituationCategory.fromCode(rawCategory),
      observation: rawObservation.trim(),
      createdAt: rawCreatedAt.toDate().toUtc(),
      updatedAt: rawUpdatedAt.toDate().toUtc(),
    );
  }
}
