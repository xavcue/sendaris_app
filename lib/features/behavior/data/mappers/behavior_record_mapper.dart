import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/behavior_category.dart';
import '../../domain/models/behavior_intensity.dart';
import '../../domain/models/behavior_record.dart';

abstract final class BehaviorRecordMapper {
  static const String recordType = 'conducta';

  static const Set<String> allowedTopLevelFields = {
    'tipoRegistro',
    'fechaEvento',
    'fechaCreacion',
    'fechaActualizacion',
    'uidOperacion',
    'datos',
  };

  static const Set<String> allowedBehaviorFields = {
    'fecha',
    'hora',
    'categoria',
    'duracionMin',
    'intensidad',
    'contexto',
    'observacion',
  };

  static Map<String, dynamic> toFirestore({
    required BehaviorRecord record,
    required String operationUid,
  }) {
    final normalizedUid = operationUid.trim();

    if (normalizedUid.isEmpty) {
      throw const FormatException('El UID de operación no puede estar vacío.');
    }

    final behaviorData = <String, dynamic>{
      'fecha': Timestamp.fromDate(
        DateTime.utc(record.date.year, record.date.month, record.date.day),
      ),
      'categoria': record.category.code,
    };

    final time = record.time;

    if (time != null) {
      behaviorData['hora'] = time;
    }

    final durationMinutes = record.durationMinutes;

    if (durationMinutes != null) {
      behaviorData['duracionMin'] = durationMinutes;
    }

    final intensity = record.intensity;

    if (intensity != null) {
      behaviorData['intensidad'] = intensity.code;
    }

    final context = record.context;

    if (context != null) {
      behaviorData['contexto'] = context;
    }

    final observation = record.observation;

    if (observation != null) {
      behaviorData['observacion'] = observation;
    }

    return {
      'tipoRegistro': recordType,
      'fechaEvento': Timestamp.fromDate(record.eventDateTime.toUtc()),
      'fechaCreacion': Timestamp.fromDate(record.createdAt.toUtc()),
      'fechaActualizacion': Timestamp.fromDate(record.updatedAt.toUtc()),
      'uidOperacion': normalizedUid,
      'datos': behaviorData,
    };
  }

  static BehaviorRecord fromFirestore({
    required String recordId,
    required String anonymousId,
    required Map<String, dynamic> data,
  }) {
    final recordTypeValue = data['tipoRegistro'];
    final eventDate = data['fechaEvento'];
    final createdAt = data['fechaCreacion'];
    final updatedAt = data['fechaActualizacion'];
    final operationUid = data['uidOperacion'];
    final rawBehaviorData = data['datos'];

    if (recordTypeValue != recordType) {
      throw const FormatException(
        'El documento no corresponde a un registro de conducta.',
      );
    }

    if (eventDate is! Timestamp) {
      throw const FormatException('La fecha del evento no es válida.');
    }

    if (createdAt is! Timestamp) {
      throw const FormatException('La fecha de creación no es válida.');
    }

    if (updatedAt is! Timestamp) {
      throw const FormatException('La fecha de actualización no es válida.');
    }

    if (operationUid is! String || operationUid.trim().isEmpty) {
      throw const FormatException('El UID de operación no es válido.');
    }

    if (rawBehaviorData is! Map) {
      throw const FormatException(
        'Los datos de conducta no tienen un formato válido.',
      );
    }

    final behaviorData = Map<String, dynamic>.from(rawBehaviorData);

    final rawDate = behaviorData['fecha'];
    final rawCategory = behaviorData['categoria'];

    if (rawDate is! Timestamp) {
      throw const FormatException('La fecha de la conducta no es válida.');
    }

    if (rawCategory is! String) {
      throw const FormatException('La categoría de conducta no es válida.');
    }

    final rawTime = behaviorData['hora'];
    final rawDuration = behaviorData['duracionMin'];
    final rawIntensity = behaviorData['intensidad'];
    final rawContext = behaviorData['contexto'];
    final rawObservation = behaviorData['observacion'];

    if (rawTime != null && rawTime is! String) {
      throw const FormatException('La hora de la conducta no es válida.');
    }

    if (rawDuration != null && rawDuration is! int) {
      throw const FormatException('La duración de la conducta no es válida.');
    }

    if (rawIntensity != null && rawIntensity is! String) {
      throw const FormatException('La intensidad de la conducta no es válida.');
    }

    if (rawContext != null && rawContext is! String) {
      throw const FormatException('El contexto de la conducta no es válido.');
    }

    if (rawObservation != null && rawObservation is! String) {
      throw const FormatException(
        'La observación de la conducta no es válida.',
      );
    }

    final dateUtc = rawDate.toDate().toUtc();

    return BehaviorRecord(
      recordId: recordId,
      anonymousId: anonymousId,
      date: DateTime(dateUtc.year, dateUtc.month, dateUtc.day),
      time: rawTime as String?,
      category: BehaviorCategory.fromCode(rawCategory),
      durationMinutes: rawDuration as int?,
      intensity: rawIntensity == null
          ? null
          : BehaviorIntensity.fromCode(rawIntensity as String),
      context: rawContext as String?,
      observation: rawObservation as String?,
      createdAt: createdAt.toDate().toUtc(),
      updatedAt: updatedAt.toDate().toUtc(),
    );
  }
}
