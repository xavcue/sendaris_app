import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/dysregulation_intensity.dart';
import '../../domain/models/dysregulation_record.dart';
import '../../domain/validation/dysregulation_record_validator.dart';

abstract final class DysregulationRecordMapper {
  static const String recordType = 'desregulacion';

  static const Set<String> allowedTopLevelFields = {
    'tipoRegistro',
    'fechaEvento',
    'fechaCreacion',
    'fechaActualizacion',
    'uidOperacion',
    'datos',
  };

  static const Set<String> allowedDysregulationFields = {
    'fecha',
    'hora',
    'duracionMin',
    'intensidad',
    'contexto',
    'observacion',
  };

  static Map<String, dynamic> toFirestore({
    required DysregulationRecord record,
    required String operationUid,
  }) {
    final normalizedUid = operationUid.trim();

    if (normalizedUid.isEmpty) {
      throw const FormatException('El UID de operación no puede estar vacío.');
    }

    final episodeData = <String, dynamic>{
      'fecha': Timestamp.fromDate(
        DateTime.utc(record.date.year, record.date.month, record.date.day),
      ),
    };

    final time = record.time;

    if (time != null) {
      episodeData['hora'] = time;
    }

    final durationMinutes = record.durationMinutes;

    if (durationMinutes != null) {
      episodeData['duracionMin'] = durationMinutes;
    }

    final intensity = record.intensity;

    if (intensity != null) {
      episodeData['intensidad'] = intensity.code;
    }

    final context = record.context;

    if (context != null) {
      episodeData['contexto'] = context;
    }

    final observation = record.observation;

    if (observation != null) {
      episodeData['observacion'] = observation;
    }

    return {
      'tipoRegistro': recordType,
      'fechaEvento': Timestamp.fromDate(record.eventDateTime.toUtc()),
      'fechaCreacion': Timestamp.fromDate(record.createdAt.toUtc()),
      'fechaActualizacion': Timestamp.fromDate(record.updatedAt.toUtc()),
      'uidOperacion': normalizedUid,
      'datos': episodeData,
    };
  }

  static DysregulationRecord fromFirestore({
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
    final rawEpisodeData = data['datos'];

    if (rawRecordType != recordType) {
      throw const FormatException(
        'El documento no corresponde a un registro de desregulación.',
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

    if (rawEpisodeData is! Map) {
      throw const FormatException(
        'Los datos de desregulación no tienen un formato válido.',
      );
    }

    final episodeData = Map<String, dynamic>.from(rawEpisodeData);

    final episodeKeys = episodeData.keys.toSet();

    const requiredFields = {'fecha'};

    if (!episodeKeys.containsAll(requiredFields) ||
        !allowedDysregulationFields.containsAll(episodeKeys)) {
      throw const FormatException(
        'Los datos de desregulación contienen una estructura no permitida.',
      );
    }

    final rawDate = episodeData['fecha'];
    final rawTime = episodeData['hora'];
    final rawDuration = episodeData['duracionMin'];
    final rawIntensity = episodeData['intensidad'];
    final rawContext = episodeData['contexto'];
    final rawObservation = episodeData['observacion'];

    if (rawDate is! Timestamp) {
      throw const FormatException('La fecha del episodio no es válida.');
    }

    if (rawTime != null && (rawTime is! String || rawTime.trim().isEmpty)) {
      throw const FormatException('La hora del episodio no es válida.');
    }

    if (rawDuration != null && rawDuration is! int) {
      throw const FormatException('La duración del episodio no es válida.');
    }

    if (rawIntensity != null &&
        (rawIntensity is! String || rawIntensity.trim().isEmpty)) {
      throw const FormatException(
        'La intensidad descriptiva del episodio no es válida.',
      );
    }

    if (rawContext != null &&
        (rawContext is! String || rawContext.trim().isEmpty)) {
      throw const FormatException('El contexto del episodio no es válido.');
    }

    if (rawObservation != null &&
        (rawObservation is! String || rawObservation.trim().isEmpty)) {
      throw const FormatException('La observación del episodio no es válida.');
    }

    final normalizedTime = rawTime is String ? rawTime.trim() : null;

    final validationErrors = DysregulationRecordValidator.validate(
      anonymousId: normalizedAnonymousId,
      time: normalizedTime,
      durationMinutes: rawDuration as int?,
    );

    if (validationErrors.isNotEmpty) {
      throw const FormatException(
        'El registro de desregulación contiene valores no válidos.',
      );
    }

    DysregulationIntensity? intensity;

    if (rawIntensity != null) {
      intensity = DysregulationIntensity.fromCode(rawIntensity.trim());
    }

    final dateUtc = rawDate.toDate().toUtc();

    return DysregulationRecord(
      recordId: normalizedRecordId,
      anonymousId: normalizedAnonymousId,
      date: DateTime(dateUtc.year, dateUtc.month, dateUtc.day),
      time: normalizedTime,
      durationMinutes: rawDuration,
      intensity: intensity,
      context: rawContext is String ? rawContext.trim() : null,
      observation: rawObservation is String ? rawObservation.trim() : null,
      createdAt: rawCreatedAt.toDate().toUtc(),
      updatedAt: rawUpdatedAt.toDate().toUtc(),
    );
  }
}
