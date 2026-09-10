import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/models/sleep_record.dart';
import '../../domain/services/sleep_duration_calculator.dart';

abstract final class SleepRecordMapper {
  static const String recordType = 'sueno';

  static const Set<String> allowedTopLevelFields = {
    'tipoRegistro',
    'fechaEvento',
    'fechaCreacion',
    'fechaActualizacion',
    'uidOperacion',
    'datos',
  };

  static const Set<String> allowedSleepFields = {
    'fecha',
    'horaInicio',
    'horaFin',
    'duracionMin',
    'observacion',
  };

  static Map<String, dynamic> toFirestore({
    required SleepRecord record,
    required String operationUid,
  }) {
    final normalizedUid = operationUid.trim();

    if (normalizedUid.isEmpty) {
      throw const FormatException('El UID de operación no puede estar vacío.');
    }

    final sleepData = <String, dynamic>{
      'fecha': Timestamp.fromDate(
        DateTime.utc(record.date.year, record.date.month, record.date.day),
      ),
      'horaInicio': record.startTime,
      'horaFin': record.endTime,
      'duracionMin': record.durationMinutes,
    };

    final observation = record.observation;

    if (observation != null) {
      sleepData['observacion'] = observation;
    }

    return {
      'tipoRegistro': recordType,
      'fechaEvento': Timestamp.fromDate(record.eventDateTime.toUtc()),
      'fechaCreacion': Timestamp.fromDate(record.createdAt.toUtc()),
      'fechaActualizacion': Timestamp.fromDate(record.updatedAt.toUtc()),
      'uidOperacion': normalizedUid,
      'datos': sleepData,
    };
  }

  static SleepRecord fromFirestore({
    required String recordId,
    required String anonymousId,
    required Map<String, dynamic> data,
  }) {
    final recordTypeValue = data['tipoRegistro'];

    final eventDate = data['fechaEvento'];

    final createdAt = data['fechaCreacion'];

    final updatedAt = data['fechaActualizacion'];

    final operationUid = data['uidOperacion'];

    final rawSleepData = data['datos'];

    if (recordTypeValue != recordType) {
      throw const FormatException(
        'El documento no corresponde a un registro de sueño.',
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

    if (rawSleepData is! Map) {
      throw const FormatException(
        'Los datos de sueño no tienen un formato válido.',
      );
    }

    final sleepData = Map<String, dynamic>.from(rawSleepData);

    final rawDate = sleepData['fecha'];

    final rawStartTime = sleepData['horaInicio'];

    final rawEndTime = sleepData['horaFin'];

    final rawDuration = sleepData['duracionMin'];

    final rawObservation = sleepData['observacion'];

    if (rawDate is! Timestamp) {
      throw const FormatException(
        'La fecha del registro de sueño no es válida.',
      );
    }

    if (rawStartTime is! String) {
      throw const FormatException('La hora de inicio no es válida.');
    }

    if (rawEndTime is! String) {
      throw const FormatException('La hora de finalización no es válida.');
    }

    if (rawDuration is! int || rawDuration <= 0) {
      throw const FormatException(
        'La duración del registro de sueño no es válida.',
      );
    }

    if (rawObservation != null &&
        (rawObservation is! String || rawObservation.trim().isEmpty)) {
      throw const FormatException(
        'La observación del registro de sueño no es válida.',
      );
    }

    late final int calculatedDuration;

    try {
      calculatedDuration = SleepDurationCalculator.calculate(
        startTime: rawStartTime,
        endTime: rawEndTime,
      );
    } on ArgumentError {
      throw const FormatException(
        'El horario del registro de sueño no es válido.',
      );
    }

    if (rawDuration != calculatedDuration) {
      throw const FormatException(
        'La duración del registro de sueño no coincide con el horario registrado.',
      );
    }

    final dateUtc = rawDate.toDate().toUtc();

    return SleepRecord(
      recordId: recordId,
      anonymousId: anonymousId,
      date: DateTime(dateUtc.year, dateUtc.month, dateUtc.day),
      startTime: rawStartTime,
      endTime: rawEndTime,
      durationMinutes: rawDuration,
      observation: rawObservation as String?,
      createdAt: createdAt.toDate().toUtc(),
      updatedAt: updatedAt.toDate().toUtc(),
    );
  }
}
