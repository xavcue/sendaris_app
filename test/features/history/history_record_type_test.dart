import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/history/domain/models/history_record_type.dart';

void main() {
  group('HistoryRecordType', () {
    test('define únicamente los siete tipos de registro disponibles en el historial', () {
      expect(HistoryRecordType.values, hasLength(7));
    });

    test('mantiene los códigos técnicos utilizados por Firestore', () {
      expect(HistoryRecordType.values.map((type) => type.code).toList(), [
        'conducta',
        'sueno',
        'alimentacion',
        'interaccionSocial',
        'desregulacion',
        'situacionAtipica',
        'estadoRutina',
      ]);
    });

    test('expone etiquetas comprensibles para el usuario', () {
      expect(HistoryRecordType.values.map((type) => type.label).toList(), [
        'Conducta',
        'Sueño',
        'Alimentación',
        'Interacción social',
        'Desregulación',
        'Otra situación',
        'Estado de rutina',
      ]);
    });

    test('recupera cada tipo desde su código técnico', () {
      expect(
        HistoryRecordType.fromCode('conducta'),
        HistoryRecordType.behavior,
      );

      expect(HistoryRecordType.fromCode('sueno'), HistoryRecordType.sleep);

      expect(
        HistoryRecordType.fromCode('alimentacion'),
        HistoryRecordType.feeding,
      );

      expect(
        HistoryRecordType.fromCode('interaccionSocial'),
        HistoryRecordType.socialInteraction,
      );

      expect(
        HistoryRecordType.fromCode('desregulacion'),
        HistoryRecordType.dysregulation,
      );

      expect(
        HistoryRecordType.fromCode('situacionAtipica'),
        HistoryRecordType.atypicalSituation,
      );

      expect(
        HistoryRecordType.fromCode('estadoRutina'),
        HistoryRecordType.routineStatus,
      );
    });

    test('rechaza un tipo de registro desconocido', () {
      expect(
        () => HistoryRecordType.fromCode('diagnostico'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
