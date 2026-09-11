import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/feeding/data/mappers/feeding_record_mapper.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_record.dart';

void main() {
  group('FeedingRecordMapper', () {
    test(
      'persiste únicamente los campos obligatorios cuando no hay observación',
      () {
        final record = FeedingRecord(
          recordId: 'alimentacion-1',
          anonymousId: 'anonimo-1',
          date: DateTime(2026, 9, 10),
          category: FeedingCategory.lunch,
          createdAt: DateTime.utc(2026, 9, 10, 20),
          updatedAt: DateTime.utc(2026, 9, 10, 20),
        );

        final data = FeedingRecordMapper.toFirestore(
          record: record,
          operationUid: 'usuario-a',
        );

        expect(data.keys.toSet(), FeedingRecordMapper.allowedTopLevelFields);

        expect(data['tipoRegistro'], 'alimentacion');

        expect(data['uidOperacion'], 'usuario-a');

        final feedingData = data['datos'] as Map<String, dynamic>;

        expect(feedingData.keys.toSet(), {'fecha', 'categoria'});

        expect(feedingData['categoria'], 'almuerzo');

        expect(feedingData.containsKey('observacion'), false);
      },
    );

    test('persiste observación descriptiva cuando existe', () {
      final record = FeedingRecord(
        recordId: 'alimentacion-1',
        anonymousId: 'anonimo-1',
        date: DateTime(2026, 9, 10),
        category: FeedingCategory.breakfast,
        observation: 'Comida realizada durante la rutina habitual.',
        createdAt: DateTime.utc(2026, 9, 10, 20),
        updatedAt: DateTime.utc(2026, 9, 10, 20),
      );

      final data = FeedingRecordMapper.toFirestore(
        record: record,
        operationUid: 'usuario-a',
      );

      final feedingData = data['datos'] as Map<String, dynamic>;

      expect(
        feedingData['observacion'],
        'Comida realizada durante la rutina habitual.',
      );
    });

    test('recupera íntegramente un registro válido', () {
      final data = _validFirestoreData();

      final record = FeedingRecordMapper.fromFirestore(
        recordId: 'alimentacion-1',
        anonymousId: 'anonimo-1',
        data: data,
      );

      expect(record.recordId, 'alimentacion-1');

      expect(record.anonymousId, 'anonimo-1');

      expect(record.date, DateTime(2026, 9, 10));

      expect(record.category, FeedingCategory.lunch);

      expect(record.observation, 'Registro ficticio.');

      expect(record.createdAt, DateTime.utc(2026, 9, 10, 20));
    });

    test('rechaza una categoría fuera del catálogo', () {
      final data = _validFirestoreData();

      final feedingData = Map<String, dynamic>.from(data['datos'] as Map);

      feedingData['categoria'] = 'saludable';

      data['datos'] = feedingData;

      expect(
        () => FeedingRecordMapper.fromFirestore(
          recordId: 'alimentacion-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza campos adicionales dentro de datos', () {
      final data = _validFirestoreData();

      final feedingData = Map<String, dynamic>.from(data['datos'] as Map);

      feedingData['calorias'] = 500;

      data['datos'] = feedingData;

      expect(
        () => FeedingRecordMapper.fromFirestore(
          recordId: 'alimentacion-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza cuando fechaEvento no coincide con datos.fecha', () {
      final data = _validFirestoreData();

      data['fechaEvento'] = Timestamp.fromDate(DateTime.utc(2026, 9, 11));

      expect(
        () => FeedingRecordMapper.fromFirestore(
          recordId: 'alimentacion-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

Map<String, dynamic> _validFirestoreData() {
  return {
    'tipoRegistro': 'alimentacion',
    'fechaEvento': Timestamp.fromDate(DateTime.utc(2026, 9, 10)),
    'fechaCreacion': Timestamp.fromDate(DateTime.utc(2026, 9, 10, 20)),
    'fechaActualizacion': Timestamp.fromDate(DateTime.utc(2026, 9, 10, 20)),
    'uidOperacion': 'usuario-a',
    'datos': {
      'fecha': Timestamp.fromDate(DateTime.utc(2026, 9, 10)),
      'categoria': 'almuerzo',
      'observacion': 'Registro ficticio.',
    },
  };
}
