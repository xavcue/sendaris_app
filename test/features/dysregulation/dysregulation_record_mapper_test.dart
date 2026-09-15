import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/dysregulation/data/mappers/dysregulation_record_mapper.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_intensity.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';

void main() {
  group('DysregulationRecordMapper', () {
    test('persiste únicamente la fecha cuando '
        'no existen campos opcionales', () {
      final record = DysregulationRecord(
        recordId: 'desregulacion-1',
        anonymousId: 'anonimo-1',
        date: DateTime(2026, 9, 15),
        createdAt: DateTime.utc(2026, 9, 15, 20),
        updatedAt: DateTime.utc(2026, 9, 15, 20),
      );

      final data = DysregulationRecordMapper.toFirestore(
        record: record,
        operationUid: 'usuario-a',
      );

      expect(
        data.keys.toSet(),
        DysregulationRecordMapper.allowedTopLevelFields,
      );

      expect(data['tipoRegistro'], 'desregulacion');

      expect(data['uidOperacion'], 'usuario-a');

      final episodeData = data['datos'] as Map<String, dynamic>;

      expect(episodeData.keys.toSet(), {'fecha'});

      expect(episodeData.containsKey('hora'), isFalse);

      expect(episodeData.containsKey('duracionMin'), isFalse);

      expect(episodeData.containsKey('intensidad'), isFalse);

      expect(episodeData.containsKey('contexto'), isFalse);

      expect(episodeData.containsKey('observacion'), isFalse);
    });

    test('persiste todos los campos descriptivos '
        'opcionales cuando existen', () {
      final record = DysregulationRecord(
        recordId: 'desregulacion-1',
        anonymousId: 'anonimo-1',
        date: DateTime(2026, 9, 15),
        time: '14:30',
        durationMinutes: 12,
        intensity: DysregulationIntensity.medium,
        context: 'Durante una actividad cotidiana',
        observation: 'Registro ficticio descriptivo.',
        createdAt: DateTime.utc(2026, 9, 15, 20),
        updatedAt: DateTime.utc(2026, 9, 15, 20),
      );

      final data = DysregulationRecordMapper.toFirestore(
        record: record,
        operationUid: 'usuario-a',
      );

      final episodeData = data['datos'] as Map<String, dynamic>;

      expect(episodeData['hora'], '14:30');

      expect(episodeData['duracionMin'], 12);

      expect(episodeData['intensidad'], 'media');

      expect(episodeData['contexto'], 'Durante una actividad cotidiana');

      expect(episodeData['observacion'], 'Registro ficticio descriptivo.');
    });

    test('recupera íntegramente un registro válido', () {
      final record = DysregulationRecordMapper.fromFirestore(
        recordId: 'desregulacion-1',
        anonymousId: 'anonimo-1',
        data: _validFirestoreData(),
      );

      expect(record.recordId, 'desregulacion-1');

      expect(record.anonymousId, 'anonimo-1');

      expect(record.date, DateTime(2026, 9, 15));

      expect(record.time, '14:30');

      expect(record.durationMinutes, 12);

      expect(record.intensity, DysregulationIntensity.medium);

      expect(record.context, 'Actividad cotidiana');

      expect(record.observation, 'Registro ficticio.');

      expect(record.createdAt, DateTime.utc(2026, 9, 15, 20));
    });

    test('permite recuperar duración igual a cero', () {
      final data = _validFirestoreData();

      final episodeData = Map<String, dynamic>.from(data['datos'] as Map);

      episodeData['duracionMin'] = 0;

      data['datos'] = episodeData;

      final record = DysregulationRecordMapper.fromFirestore(
        recordId: 'desregulacion-1',
        anonymousId: 'anonimo-1',
        data: data,
      );

      expect(record.durationMinutes, 0);
    });

    test('rechaza una duración negativa recuperada', () {
      final data = _validFirestoreData();

      final episodeData = Map<String, dynamic>.from(data['datos'] as Map);

      episodeData['duracionMin'] = -1;

      data['datos'] = episodeData;

      expect(
        () => DysregulationRecordMapper.fromFirestore(
          recordId: 'desregulacion-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza una intensidad fuera del catálogo', () {
      final data = _validFirestoreData();

      final episodeData = Map<String, dynamic>.from(data['datos'] as Map);

      episodeData['intensidad'] = 'severa';

      data['datos'] = episodeData;

      expect(
        () => DysregulationRecordMapper.fromFirestore(
          recordId: 'desregulacion-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza campos clínicos o causales '
        'fuera del alcance', () {
      final data = _validFirestoreData();

      final episodeData = Map<String, dynamic>.from(data['datos'] as Map);

      episodeData['causaInferida'] = 'Sobrecarga sensorial';

      data['datos'] = episodeData;

      expect(
        () => DysregulationRecordMapper.fromFirestore(
          recordId: 'desregulacion-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza una hora con formato inválido', () {
      final data = _validFirestoreData();

      final episodeData = Map<String, dynamic>.from(data['datos'] as Map);

      episodeData['hora'] = '25:90';

      data['datos'] = episodeData;

      expect(
        () => DysregulationRecordMapper.fromFirestore(
          recordId: 'desregulacion-1',
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
    'tipoRegistro': 'desregulacion',
    'fechaEvento': Timestamp.fromDate(DateTime.utc(2026, 9, 15, 14, 30)),
    'fechaCreacion': Timestamp.fromDate(DateTime.utc(2026, 9, 15, 20)),
    'fechaActualizacion': Timestamp.fromDate(DateTime.utc(2026, 9, 15, 20)),
    'uidOperacion': 'usuario-a',
    'datos': {
      'fecha': Timestamp.fromDate(DateTime.utc(2026, 9, 15)),
      'hora': '14:30',
      'duracionMin': 12,
      'intensidad': 'media',
      'contexto': 'Actividad cotidiana',
      'observacion': 'Registro ficticio.',
    },
  };
}
