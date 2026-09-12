import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/social_interaction/data/mappers/social_interaction_record_mapper.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_record.dart';

void main() {
  group('SocialInteractionRecordMapper', () {
    test(
      'persiste únicamente los campos obligatorios cuando no hay opcionales',
      () {
        final record = SocialInteractionRecord(
          recordId: 'interaccion-1',
          anonymousId: 'anonimo-1',
          date: DateTime(2026, 9, 11),
          category: SocialInteractionCategory.socialExchange,
          createdAt: DateTime.utc(2026, 9, 11, 20),
          updatedAt: DateTime.utc(2026, 9, 11, 20),
        );

        final data = SocialInteractionRecordMapper.toFirestore(
          record: record,
          operationUid: 'usuario-a',
        );

        expect(
          data.keys.toSet(),
          SocialInteractionRecordMapper.allowedTopLevelFields,
        );

        expect(data['tipoRegistro'], 'interaccionSocial');

        expect(data['uidOperacion'], 'usuario-a');

        final interactionData = data['datos'] as Map<String, dynamic>;

        expect(interactionData.keys.toSet(), {'fecha', 'categoria'});

        expect(interactionData['categoria'], 'intercambio_social');

        expect(interactionData.containsKey('contexto'), false);

        expect(interactionData.containsKey('observacion'), false);
      },
    );

    test('persiste contexto y observación descriptivos cuando existen', () {
      final record = SocialInteractionRecord(
        recordId: 'interaccion-1',
        anonymousId: 'anonimo-1',
        date: DateTime(2026, 9, 11),
        category: SocialInteractionCategory.sharedActivity,
        context: 'Actividad recreativa',
        observation: 'Registro ficticio descriptivo.',
        createdAt: DateTime.utc(2026, 9, 11, 20),
        updatedAt: DateTime.utc(2026, 9, 11, 20),
      );

      final data = SocialInteractionRecordMapper.toFirestore(
        record: record,
        operationUid: 'usuario-a',
      );

      final interactionData = data['datos'] as Map<String, dynamic>;

      expect(interactionData['contexto'], 'Actividad recreativa');

      expect(interactionData['observacion'], 'Registro ficticio descriptivo.');
    });

    test('recupera íntegramente un registro válido', () {
      final data = _validFirestoreData();

      final record = SocialInteractionRecordMapper.fromFirestore(
        recordId: 'interaccion-1',
        anonymousId: 'anonimo-1',
        data: data,
      );

      expect(record.recordId, 'interaccion-1');

      expect(record.anonymousId, 'anonimo-1');

      expect(record.date, DateTime(2026, 9, 11));

      expect(record.category, SocialInteractionCategory.socialExchange);

      expect(record.context, 'Actividad recreativa');

      expect(record.observation, 'Registro ficticio.');

      expect(record.createdAt, DateTime.utc(2026, 9, 11, 20));
    });

    test('rechaza una categoría fuera del catálogo', () {
      final data = _validFirestoreData();

      final interactionData = Map<String, dynamic>.from(data['datos'] as Map);

      interactionData['categoria'] = 'buena_interaccion';

      data['datos'] = interactionData;

      expect(
        () => SocialInteractionRecordMapper.fromFirestore(
          recordId: 'interaccion-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza campos clínicos o valorativos adicionales', () {
      final data = _validFirestoreData();

      final interactionData = Map<String, dynamic>.from(data['datos'] as Map);

      interactionData['puntuacionSocial'] = 8;

      data['datos'] = interactionData;

      expect(
        () => SocialInteractionRecordMapper.fromFirestore(
          recordId: 'interaccion-1',
          anonymousId: 'anonimo-1',
          data: data,
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza cuando fechaEvento no coincide con datos.fecha', () {
      final data = _validFirestoreData();

      data['fechaEvento'] = Timestamp.fromDate(DateTime.utc(2026, 9, 12));

      expect(
        () => SocialInteractionRecordMapper.fromFirestore(
          recordId: 'interaccion-1',
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
    'tipoRegistro': 'interaccionSocial',
    'fechaEvento': Timestamp.fromDate(DateTime.utc(2026, 9, 11)),
    'fechaCreacion': Timestamp.fromDate(DateTime.utc(2026, 9, 11, 20)),
    'fechaActualizacion': Timestamp.fromDate(DateTime.utc(2026, 9, 11, 20)),
    'uidOperacion': 'usuario-a',
    'datos': {
      'fecha': Timestamp.fromDate(DateTime.utc(2026, 9, 11)),
      'categoria': 'intercambio_social',
      'contexto': 'Actividad recreativa',
      'observacion': 'Registro ficticio.',
    },
  };
}
