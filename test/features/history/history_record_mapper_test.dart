import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/history/data/mappers/history_record_mapper.dart';
import 'package:sendaris/features/history/domain/models/history_record_type.dart';

void main() {
  group('HistoryRecordMapper', () {
    test('recupera los siete tipos de registro admitidos', () {
      final cases = {
        'conducta': HistoryRecordType.behavior,
        'sueno': HistoryRecordType.sleep,
        'alimentacion': HistoryRecordType.feeding,
        'interaccionSocial': HistoryRecordType.socialInteraction,
        'desregulacion': HistoryRecordType.dysregulation,
        'situacionAtipica': HistoryRecordType.atypicalSituation,
        'estadoRutina': HistoryRecordType.routineStatus,
      };

      for (final entry in cases.entries) {
        final record = HistoryRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          data: _validFirestoreData(recordType: entry.key),
        );

        expect(record.type, entry.value);
      }
    });

    test('recupera identificadores y fecha de evento', () {
      final eventDate = DateTime.utc(2026, 9, 15, 14, 30);

      final record = HistoryRecordMapper.fromFirestore(
        recordId: 'registro-001',
        anonymousId: 'anonimo-001',
        data: _validFirestoreData(eventDate: eventDate),
      );

      expect(record.recordId, 'registro-001');

      expect(record.anonymousId, 'anonimo-001');

      expect(record.eventDate, eventDate);
    });

    test('rechaza un tipo de registro desconocido', () {
      expect(
        () => HistoryRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          data: _validFirestoreData(recordType: 'diagnostico'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza un identificador de registro inválido', () {
      expect(
        () => HistoryRecordMapper.fromFirestore(
          recordId: 'registro/invalido',
          anonymousId: 'anonimo-1',
          data: _validFirestoreData(),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza un identificador anónimo inválido', () {
      expect(
        () => HistoryRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'perfil/invalido',
          data: _validFirestoreData(),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza campos adicionales en el nivel superior', () {
      final data = _validFirestoreData();

      data['nombreNino'] = 'dato no permitido';

      expect(
        () => HistoryRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza un wrapper incompleto', () {
      final data = _validFirestoreData();

      data.remove('fechaEvento');

      expect(
        () => HistoryRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza una fecha de evento que no sea timestamp', () {
      final data = _validFirestoreData();

      data['fechaEvento'] = '2026-09-15';

      expect(
        () => HistoryRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza un uid de operación inválido', () {
      final data = _validFirestoreData();

      data['uidOperacion'] = '   ';

      expect(
        () => HistoryRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza datos internos con formato inválido', () {
      final data = _validFirestoreData();

      data['datos'] = 'contenido inválido';

      expect(
        () => HistoryRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

Map<String, dynamic> _validFirestoreData({
  String recordType = 'conducta',
  DateTime? eventDate,
}) {
  return {
    'tipoRegistro': recordType,
    'fechaEvento': Timestamp.fromDate(
      eventDate ?? DateTime.utc(2026, 9, 15, 14, 30),
    ),
    'fechaCreacion': Timestamp.fromDate(DateTime.utc(2026, 9, 15, 20)),
    'fechaActualizacion': Timestamp.fromDate(DateTime.utc(2026, 9, 15, 20)),
    'uidOperacion': 'usuario-a',
    'datos': <String, dynamic>{
      'fecha': Timestamp.fromDate(DateTime.utc(2026, 9, 15)),
    },
  };
}
