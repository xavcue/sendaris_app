import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/sleep/data/mappers/sleep_record_mapper.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';

void main() {
  group('SleepRecordMapper', () {
    test('persiste los datos temporales obligatorios', () {
      final record = SleepRecord(
        recordId: 'registro-sueno-1',
        anonymousId: 'anonimo-1',
        date: DateTime(2026, 9, 9),
        startTime: '22:00',
        endTime: '06:00',
        durationMinutes: 480,
        createdAt: DateTime.utc(2026, 9, 10, 10),
        updatedAt: DateTime.utc(2026, 9, 10, 10),
      );

      final data = SleepRecordMapper.toFirestore(
        record: record,
        operationUid: 'usuario-a',
      );

      expect(data.keys.toSet(), SleepRecordMapper.allowedTopLevelFields);

      expect(data['tipoRegistro'], 'sueno');

      final sleepData = data['datos'] as Map<String, dynamic>;

      expect(sleepData.keys.toSet(), {
        'fecha',
        'horaInicio',
        'horaFin',
        'duracionMin',
      });

      expect(sleepData['horaInicio'], '22:00');

      expect(sleepData['horaFin'], '06:00');

      expect(sleepData['duracionMin'], 480);

      expect(sleepData.containsKey('observacion'), false);
    });

    test('persiste observación cuando existe', () {
      final record = SleepRecord(
        recordId: 'registro-sueno-1',
        anonymousId: 'anonimo-1',
        date: DateTime(2026, 9, 9),
        startTime: '22:00',
        endTime: '06:00',
        durationMinutes: 480,
        observation: 'Registro ficticio.',
        createdAt: DateTime.utc(2026, 9, 10, 10),
        updatedAt: DateTime.utc(2026, 9, 10, 10),
      );

      final data = SleepRecordMapper.toFirestore(
        record: record,
        operationUid: 'usuario-a',
      );

      final sleepData = data['datos'] as Map<String, dynamic>;

      expect(sleepData['observacion'], 'Registro ficticio.');
    });

    test('recupera un registro válido sin alterar la duración', () {
      final data = <String, dynamic>{
        'tipoRegistro': 'sueno',
        'fechaEvento': Timestamp.fromDate(DateTime.utc(2026, 9, 9, 22)),
        'fechaCreacion': Timestamp.fromDate(DateTime.utc(2026, 9, 10, 10)),
        'fechaActualizacion': Timestamp.fromDate(DateTime.utc(2026, 9, 10, 10)),
        'uidOperacion': 'usuario-a',
        'datos': {
          'fecha': Timestamp.fromDate(DateTime.utc(2026, 9, 9)),
          'horaInicio': '22:00',
          'horaFin': '06:00',
          'duracionMin': 480,
          'observacion': 'Registro ficticio.',
        },
      };

      final record = SleepRecordMapper.fromFirestore(
        recordId: 'registro-sueno-1',
        anonymousId: 'anonimo-1',
        data: data,
      );

      expect(record.recordId, 'registro-sueno-1');

      expect(record.anonymousId, 'anonimo-1');

      expect(record.startTime, '22:00');

      expect(record.endTime, '06:00');

      expect(record.durationMinutes, 480);

      expect(record.observation, 'Registro ficticio.');

      expect(record.endDateTime, DateTime(2026, 9, 10, 6));
    });

    test('rechaza una duración que no coincide con el horario', () {
      final data = <String, dynamic>{
        'tipoRegistro': 'sueno',
        'fechaEvento': Timestamp.fromDate(DateTime.utc(2026, 9, 9, 22)),
        'fechaCreacion': Timestamp.fromDate(DateTime.utc(2026, 9, 10, 10)),
        'fechaActualizacion': Timestamp.fromDate(DateTime.utc(2026, 9, 10, 10)),
        'uidOperacion': 'usuario-a',
        'datos': {
          'fecha': Timestamp.fromDate(DateTime.utc(2026, 9, 9)),
          'horaInicio': '22:00',
          'horaFin': '06:00',
          'duracionMin': 60,
        },
      };

      expect(
        () => SleepRecordMapper.fromFirestore(
          recordId: 'registro-sueno-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza documentos de otro tipo de registro', () {
      expect(
        () => SleepRecordMapper.fromFirestore(
          recordId: 'registro-sueno-1',
          anonymousId: 'anonimo-1',
          data: {'tipoRegistro': 'conducta'},
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
