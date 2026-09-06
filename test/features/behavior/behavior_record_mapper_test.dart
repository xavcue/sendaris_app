import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/behavior/data/mappers/behavior_record_mapper.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_intensity.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';

void main() {
  group('BehaviorRecordMapper', () {
    test(
      'persiste únicamente campos obligatorios cuando los opcionales faltan',
      () {
        final record = BehaviorRecord(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          date: DateTime(2026, 9, 5),
          category: BehaviorCategory.repetitiveBehavior,
          createdAt: DateTime.utc(2026, 9, 5, 18),
          updatedAt: DateTime.utc(2026, 9, 5, 18),
        );

        final data = BehaviorRecordMapper.toFirestore(
          record: record,
          operationUid: 'usuario-a',
        );

        expect(data.keys.toSet(), BehaviorRecordMapper.allowedTopLevelFields);

        final behaviorData = data['datos'] as Map<String, dynamic>;

        expect(behaviorData.keys.toSet(), {'fecha', 'categoria'});

        expect(behaviorData['categoria'], 'conducta_repetitiva');

        expect(behaviorData.containsKey('hora'), false);

        expect(behaviorData.containsKey('observacion'), false);
      },
    );

    test('persiste campos opcionales cuando existen', () {
      final record = BehaviorRecord(
        recordId: 'registro-1',
        anonymousId: 'anonimo-1',
        date: DateTime(2026, 9, 5),
        time: '14:30',
        category: BehaviorCategory.avoidanceFear,
        durationMinutes: 15,
        intensity: BehaviorIntensity.medium,
        context: 'Actividad cotidiana',
        observation: 'Observación ficticia.',
        createdAt: DateTime.utc(2026, 9, 5, 18),
        updatedAt: DateTime.utc(2026, 9, 5, 18),
      );

      final data = BehaviorRecordMapper.toFirestore(
        record: record,
        operationUid: 'usuario-a',
      );

      final behaviorData = data['datos'] as Map<String, dynamic>;

      expect(behaviorData['hora'], '14:30');

      expect(behaviorData['duracionMin'], 15);

      expect(behaviorData['intensidad'], 'media');

      expect(behaviorData['contexto'], 'Actividad cotidiana');

      expect(behaviorData['observacion'], 'Observación ficticia.');
    });

    test('recupera un registro válido sin alterar sus datos', () {
      final data = <String, dynamic>{
        'tipoRegistro': 'conducta',
        'fechaEvento': Timestamp.fromDate(DateTime.utc(2026, 9, 5, 14, 30)),
        'fechaCreacion': Timestamp.fromDate(DateTime.utc(2026, 9, 5, 18)),
        'fechaActualizacion': Timestamp.fromDate(DateTime.utc(2026, 9, 5, 18)),
        'uidOperacion': 'usuario-a',
        'datos': {
          'fecha': Timestamp.fromDate(DateTime.utc(2026, 9, 5)),
          'hora': '14:30',
          'categoria': 'conducta_repetitiva',
          'duracionMin': 10,
          'intensidad': 'media',
          'contexto': 'Actividad cotidiana',
        },
      };

      final record = BehaviorRecordMapper.fromFirestore(
        recordId: 'registro-1',
        anonymousId: 'anonimo-1',
        data: data,
      );

      expect(record.recordId, 'registro-1');

      expect(record.anonymousId, 'anonimo-1');

      expect(record.category, BehaviorCategory.repetitiveBehavior);

      expect(record.durationMinutes, 10);

      expect(record.intensity, BehaviorIntensity.medium);

      expect(record.context, 'Actividad cotidiana');
    });

    test('rechaza documentos que no sean de tipo conducta', () {
      expect(
        () => BehaviorRecordMapper.fromFirestore(
          recordId: 'registro-1',
          anonymousId: 'anonimo-1',
          data: {'tipoRegistro': 'sueno'},
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
