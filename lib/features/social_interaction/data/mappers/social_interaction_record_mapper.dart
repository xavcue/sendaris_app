import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/social_interaction_category.dart';
import '../../domain/models/social_interaction_record.dart';

abstract final class SocialInteractionRecordMapper {
  static const String recordType = 'interaccionSocial';

  static const Set<String> allowedTopLevelFields = {
    'tipoRegistro',
    'fechaEvento',
    'fechaCreacion',
    'fechaActualizacion',
    'uidOperacion',
    'datos',
  };

  static const Set<String> allowedSocialInteractionFields = {
    'fecha',
    'categoria',
    'contexto',
    'observacion',
  };

  static Map<String, dynamic> toFirestore({
    required SocialInteractionRecord record,
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

    final interactionData = <String, dynamic>{
      'fecha': Timestamp.fromDate(eventDate),
      'categoria': record.category.code,
    };

    final context = record.context;

    if (context != null) {
      interactionData['contexto'] = context;
    }

    final observation = record.observation;

    if (observation != null) {
      interactionData['observacion'] = observation;
    }

    return {
      'tipoRegistro': recordType,
      'fechaEvento': Timestamp.fromDate(eventDate),
      'fechaCreacion': Timestamp.fromDate(record.createdAt.toUtc()),
      'fechaActualizacion': Timestamp.fromDate(record.updatedAt.toUtc()),
      'uidOperacion': normalizedUid,
      'datos': interactionData,
    };
  }

  static SocialInteractionRecord fromFirestore({
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

    final rawInteractionData = data['datos'];

    if (rawRecordType != recordType) {
      throw const FormatException(
        'El documento no corresponde a un registro de interacción social.',
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

    if (rawInteractionData is! Map) {
      throw const FormatException(
        'Los datos de interacción social no tienen un formato válido.',
      );
    }

    final interactionData = Map<String, dynamic>.from(rawInteractionData);

    final interactionKeys = interactionData.keys.toSet();

    const requiredFields = {'fecha', 'categoria'};

    if (!interactionKeys.containsAll(requiredFields) ||
        !allowedSocialInteractionFields.containsAll(interactionKeys)) {
      throw const FormatException(
        'Los datos de interacción social contienen una estructura no permitida.',
      );
    }

    final rawDate = interactionData['fecha'];

    final rawCategory = interactionData['categoria'];

    final rawContext = interactionData['contexto'];

    final rawObservation = interactionData['observacion'];

    if (rawDate is! Timestamp) {
      throw const FormatException(
        'La fecha del registro de interacción social no es válida.',
      );
    }

    if (rawCategory is! String || rawCategory.trim().isEmpty) {
      throw const FormatException(
        'La categoría de interacción social no es válida.',
      );
    }

    if (rawContext != null &&
        (rawContext is! String || rawContext.trim().isEmpty)) {
      throw const FormatException(
        'El contexto del registro de interacción social no es válido.',
      );
    }

    if (rawObservation != null &&
        (rawObservation is! String || rawObservation.trim().isEmpty)) {
      throw const FormatException(
        'La observación del registro de interacción social no es válida.',
      );
    }

    final eventDate = rawEventDate.toDate().toUtc();

    final interactionDate = rawDate.toDate().toUtc();

    final normalizedEventDate = DateTime.utc(
      eventDate.year,
      eventDate.month,
      eventDate.day,
    );

    final normalizedInteractionDate = DateTime.utc(
      interactionDate.year,
      interactionDate.month,
      interactionDate.day,
    );

    if (normalizedEventDate != normalizedInteractionDate) {
      throw const FormatException(
        'La fecha del evento no coincide con la fecha del registro de interacción social.',
      );
    }

    return SocialInteractionRecord(
      recordId: normalizedRecordId,
      anonymousId: normalizedAnonymousId,
      date: DateTime(
        interactionDate.year,
        interactionDate.month,
        interactionDate.day,
      ),
      category: SocialInteractionCategory.fromCode(rawCategory),
      context: rawContext?.trim(),
      observation: rawObservation?.trim(),
      createdAt: rawCreatedAt.toDate().toUtc(),
      updatedAt: rawUpdatedAt.toDate().toUtc(),
    );
  }
}
