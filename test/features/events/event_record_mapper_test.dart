import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/events/data/mappers/event_record_mapper.dart';
import 'package:sendaris/features/events/domain/models/event_record_type.dart';

void main() {
  group('EventRecordMapper', () {
    test('recupera únicamente los seis tipos pertenecientes a Eventos', () {
      final cases = {
        'conducta': EventRecordType.behavior,
        'sueno': EventRecordType.sleep,
        'alimentacion': EventRecordType.feeding,
        'interaccionSocial': EventRecordType.socialInteraction,
        'desregulacion': EventRecordType.dysregulation,
        'situacionAtipica': EventRecordType.atypicalSituation,
      };

      for (final entry in cases.entries) {
        final record = EventRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          data: _validFirestoreData(recordType: entry.key),
        );

        expect(record.type, entry.value);
      }
    });

    test('rechaza Estado de rutina porque pertenece al módulo Rutinas', () {
      expect(
        () => EventRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          data: _validFirestoreData(recordType: 'estadoRutina'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('conserva el instante UTC para eventos que pueden incluir hora', () {
      final eventDate = DateTime.utc(2026, 9, 15, 14, 30);

      final record = EventRecordMapper.fromFirestore(
        recordId: 'registro-001',
        anonymousId: 'anonimo-001',
        data: _validFirestoreData(recordType: 'conducta', eventDate: eventDate),
      );

      expect(record.recordId, 'registro-001');

      expect(record.anonymousId, 'anonimo-001');

      expect(record.eventDate, eventDate);

      expect(record.eventDate.isUtc, isTrue);
    });

    test('conserva la fecha de creación como instante UTC', () {
      final record = EventRecordMapper.fromFirestore(
        recordId: 'registro-001',
        anonymousId: 'anonimo-001',
        data: _validFirestoreData(),
      );

      expect(record.createdAt, DateTime.utc(2026, 9, 15, 20));

      expect(record.createdAt.isUtc, isTrue);
    });

    test('conserva el día calendario en eventos que no incluyen hora', () {
      const dateOnlyTypes = [
        'alimentacion',
        'interaccionSocial',
        'situacionAtipica',
      ];

      final selectedDate = DateTime.utc(2026, 9, 21);

      for (final recordType in dateOnlyTypes) {
        final record = EventRecordMapper.fromFirestore(
          recordId: 'registro-$recordType',
          anonymousId: 'anonimo-001',
          data: _validFirestoreData(
            recordType: recordType,
            eventDate: selectedDate,
          ),
        );

        expect(record.eventDate.year, 2026);

        expect(record.eventDate.month, 9);

        expect(record.eventDate.day, 21);

        expect(record.eventDate.isUtc, isFalse);
      }
    });

    test('rechaza un tipo desconocido', () {
      expect(
        () => EventRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          data: _validFirestoreData(recordType: 'diagnostico'),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza un identificador de registro inválido', () {
      expect(
        () => EventRecordMapper.fromFirestore(
          recordId: 'registro/invalido',
          anonymousId: 'anonimo-1',
          data: _validFirestoreData(),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza un identificador de seguimiento inválido', () {
      expect(
        () => EventRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'seguimiento/invalido',
          data: _validFirestoreData(),
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza campos adicionales en el nivel superior', () {
      final data = _validFirestoreData();

      data['nombreNino'] = 'dato no permitido';

      expect(
        () => EventRecordMapper.fromFirestore(
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
        () => EventRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza una fecha de evento que no sea Timestamp', () {
      final data = _validFirestoreData();

      data['fechaEvento'] = '2026-09-15';

      expect(
        () => EventRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza una fecha de creación que no sea Timestamp', () {
      final data = _validFirestoreData();

      data['fechaCreacion'] = '2026-09-15T20:00:00Z';

      expect(
        () => EventRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza un UID de operación inválido', () {
      final data = _validFirestoreData();

      data['uidOperacion'] = '   ';

      expect(
        () => EventRecordMapper.fromFirestore(
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
        () => EventRecordMapper.fromFirestore(
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
  final resolvedEventDate = eventDate ?? DateTime.utc(2026, 9, 15, 14, 30);

  return {
    'tipoRegistro': recordType,
    'fechaEvento': Timestamp.fromDate(resolvedEventDate),
    'fechaCreacion': Timestamp.fromDate(DateTime.utc(2026, 9, 15, 20)),
    'fechaActualizacion': Timestamp.fromDate(DateTime.utc(2026, 9, 15, 20)),
    'uidOperacion': 'usuario-a',
    'datos': <String, dynamic>{
      'fecha': Timestamp.fromDate(
        DateTime.utc(
          resolvedEventDate.year,
          resolvedEventDate.month,
          resolvedEventDate.day,
        ),
      ),
    },
  };
}
