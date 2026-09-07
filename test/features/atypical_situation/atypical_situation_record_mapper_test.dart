import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/data/mappers/atypical_situation_record_mapper.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';

void main() {
  group('AtypicalSituationRecordMapper', () {
    test('convierte una situación válida a Firestore', () {
      final record = AtypicalSituationRecord(
        recordId: 'registro-test',
        anonymousId: 'anonimo-test',
        date: DateTime(2026, 9, 6),
        category: AtypicalSituationCategory.unexpectedEvent,
        observation: 'Se suspendió una actividad programada.',
        createdAt: DateTime.utc(2026, 9, 6, 18),
        updatedAt: DateTime.utc(2026, 9, 6, 18),
      );

      final data = AtypicalSituationRecordMapper.toFirestore(
        record: record,
        operationUid: 'usuario-test',
      );

      expect(data['tipoRegistro'], 'situacionAtipica');

      expect(data['uidOperacion'], 'usuario-test');

      final situationData = Map<String, dynamic>.from(data['datos'] as Map);

      expect(situationData['categoriaGeneral'], 'evento_inesperado');

      expect(
        situationData['observacion'],
        'Se suspendió una actividad programada.',
      );

      expect(data.containsKey('anonymousId'), isFalse);

      expect(data.containsKey('recordId'), isFalse);
    });

    test('reconstruye una situación válida desde Firestore', () {
      final date = Timestamp.fromDate(DateTime.utc(2026, 9, 6));

      final createdAt = Timestamp.fromDate(DateTime.utc(2026, 9, 6, 18));

      final record = AtypicalSituationRecordMapper.fromFirestore(
        recordId: 'registro-test',
        anonymousId: 'anonimo-test',
        data: {
          'tipoRegistro': 'situacionAtipica',
          'fechaEvento': date,
          'fechaCreacion': createdAt,
          'fechaActualizacion': createdAt,
          'uidOperacion': 'usuario-test',
          'datos': {
            'fecha': date,
            'categoriaGeneral': 'cambio_entorno',
            'observacion': 'La actividad se realizó en otra sala.',
          },
        },
      );

      expect(record.anonymousId, 'anonimo-test');

      expect(record.date, DateTime(2026, 9, 6));

      expect(record.category, AtypicalSituationCategory.environmentChange);

      expect(record.observation, 'La actividad se realizó en otra sala.');
    });

    test('rechaza una categoría fuera del catálogo', () {
      final date = Timestamp.fromDate(DateTime.utc(2026, 9, 6));

      expect(
        () => AtypicalSituationRecordMapper.fromFirestore(
          recordId: 'registro-test',
          anonymousId: 'anonimo-test',
          data: {
            'tipoRegistro': 'situacionAtipica',
            'fechaEvento': date,
            'fechaCreacion': date,
            'fechaActualizacion': date,
            'uidOperacion': 'usuario-test',
            'datos': {
              'fecha': date,
              'categoriaGeneral': 'categoria_invalida',
              'observacion': 'Descripción válida.',
            },
          },
        ),
        throwsFormatException,
      );
    });

    test('rechaza una observación vacía', () {
      final date = Timestamp.fromDate(DateTime.utc(2026, 9, 6));

      expect(
        () => AtypicalSituationRecordMapper.fromFirestore(
          recordId: 'registro-test',
          anonymousId: 'anonimo-test',
          data: {
            'tipoRegistro': 'situacionAtipica',
            'fechaEvento': date,
            'fechaCreacion': date,
            'fechaActualizacion': date,
            'uidOperacion': 'usuario-test',
            'datos': {
              'fecha': date,
              'categoriaGeneral': 'otro',
              'observacion': '   ',
            },
          },
        ),
        throwsFormatException,
      );
    });

    test('rechaza campos adicionales identificadores', () {
      final date = Timestamp.fromDate(DateTime.utc(2026, 9, 6));

      expect(
        () => AtypicalSituationRecordMapper.fromFirestore(
          recordId: 'registro-test',
          anonymousId: 'anonimo-test',
          data: {
            'tipoRegistro': 'situacionAtipica',
            'fechaEvento': date,
            'fechaCreacion': date,
            'fechaActualizacion': date,
            'uidOperacion': 'usuario-test',
            'datos': {
              'fecha': date,
              'categoriaGeneral': 'otro',
              'observacion': 'Descripción válida.',
              'nombreNino': 'Dato no permitido',
            },
          },
        ),
        throwsFormatException,
      );
    });

    test('rechaza fechas internas inconsistentes', () {
      final eventDate = Timestamp.fromDate(DateTime.utc(2026, 9, 6));

      final situationDate = Timestamp.fromDate(DateTime.utc(2026, 9, 7));

      expect(
        () => AtypicalSituationRecordMapper.fromFirestore(
          recordId: 'registro-test',
          anonymousId: 'anonimo-test',
          data: {
            'tipoRegistro': 'situacionAtipica',
            'fechaEvento': eventDate,
            'fechaCreacion': eventDate,
            'fechaActualizacion': eventDate,
            'uidOperacion': 'usuario-test',
            'datos': {
              'fecha': situationDate,
              'categoriaGeneral': 'evento_inesperado',
              'observacion': 'Descripción válida.',
            },
          },
        ),
        throwsFormatException,
      );
    });
  });
}
