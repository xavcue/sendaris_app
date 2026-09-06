import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/routine_status.dart';
import '../../domain/models/routine_status_record.dart';

abstract final class RoutineStatusRecordMapper {
  static const String recordType = 'estadoRutina';

  static const Set<String> allowedTopLevelFields = {
    'tipoRegistro',
    'fechaEvento',
    'fechaCreacion',
    'fechaActualizacion',
    'uidOperacion',
    'datos',
  };

  static const Set<String> allowedStatusFields = {
    'fecha',
    'idRutina',
    'estado',
    'observacion',
  };

  static Map<String, dynamic> toFirestore({
    required RoutineStatusRecord record,
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

    final statusData = <String, dynamic>{
      'fecha': Timestamp.fromDate(eventDate),
      'idRutina': record.routineId,
      'estado': record.status.code,
    };

    final observation = record.observation;

    if (observation != null) {
      statusData['observacion'] = observation;
    }

    return {
      'tipoRegistro': recordType,
      'fechaEvento': Timestamp.fromDate(eventDate),
      'fechaCreacion': Timestamp.fromDate(record.createdAt.toUtc()),
      'fechaActualizacion': Timestamp.fromDate(record.updatedAt.toUtc()),
      'uidOperacion': normalizedUid,
      'datos': statusData,
    };
  }

  static RoutineStatusRecord fromFirestore({
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

    final rawStatusData = data['datos'];

    if (rawRecordType != recordType) {
      throw const FormatException(
        'El documento no corresponde a un estado de rutina.',
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

    if (rawStatusData is! Map) {
      throw const FormatException(
        'Los datos del estado de rutina '
        'no tienen un formato válido.',
      );
    }

    final statusData = Map<String, dynamic>.from(rawStatusData);

    final statusKeys = statusData.keys.toSet();

    const requiredStatusFields = {'fecha', 'idRutina', 'estado'};

    if (!statusKeys.containsAll(requiredStatusFields) ||
        !allowedStatusFields.containsAll(statusKeys)) {
      throw const FormatException(
        'Los datos del estado de rutina '
        'contienen una estructura no permitida.',
      );
    }

    final rawDate = statusData['fecha'];

    final rawRoutineId = statusData['idRutina'];

    final rawStatus = statusData['estado'];

    final rawObservation = statusData['observacion'];

    if (rawDate is! Timestamp) {
      throw const FormatException(
        'La fecha del estado de rutina no es válida.',
      );
    }

    if (rawRoutineId is! String || rawRoutineId.trim().isEmpty) {
      throw const FormatException('El identificador de rutina no es válido.');
    }

    if (rawStatus is! String) {
      throw const FormatException('El estado de la rutina no es válido.');
    }

    if (rawObservation != null &&
        (rawObservation is! String || rawObservation.trim().isEmpty)) {
      throw const FormatException(
        'La observación del estado de rutina no es válida.',
      );
    }

    final eventDate = rawEventDate.toDate().toUtc();

    final date = rawDate.toDate().toUtc();

    final normalizedEventDate = DateTime.utc(
      eventDate.year,
      eventDate.month,
      eventDate.day,
    );

    final normalizedDate = DateTime.utc(date.year, date.month, date.day);

    if (normalizedEventDate != normalizedDate) {
      throw const FormatException(
        'La fecha del evento no coincide '
        'con la fecha del estado de rutina.',
      );
    }

    return RoutineStatusRecord(
      recordId: recordId,
      anonymousId: anonymousId.trim(),
      routineId: rawRoutineId.trim(),
      date: DateTime(date.year, date.month, date.day),
      status: RoutineStatus.fromCode(rawStatus),
      observation: (rawObservation as String?)?.trim(),
      createdAt: rawCreatedAt.toDate().toUtc(),
      updatedAt: rawUpdatedAt.toDate().toUtc(),
    );
  }
}
