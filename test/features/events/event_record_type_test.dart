import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/events/domain/models/event_record_type.dart';

void main() {
  group('EventRecordType', () {
    test('define únicamente los seis tipos pertenecientes a Eventos', () {
      expect(EventRecordType.values, hasLength(6));
    });

    test('mantiene los códigos técnicos utilizados por Firestore', () {
      expect(EventRecordType.values.map((type) => type.code).toList(), [
        'conducta',
        'sueno',
        'alimentacion',
        'interaccionSocial',
        'desregulacion',
        'situacionAtipica',
      ]);
    });

    test('expone las etiquetas de los seis Eventos', () {
      expect(EventRecordType.values.map((type) => type.label).toList(), [
        'Conducta',
        'Sueño',
        'Alimentación',
        'Interacción social',
        'Desregulación',
        'Otra situación',
      ]);
    });

    test('recupera cada evento desde su código técnico', () {
      expect(EventRecordType.fromCode('conducta'), EventRecordType.behavior);

      expect(EventRecordType.fromCode('sueno'), EventRecordType.sleep);

      expect(EventRecordType.fromCode('alimentacion'), EventRecordType.feeding);

      expect(
        EventRecordType.fromCode('interaccionSocial'),
        EventRecordType.socialInteraction,
      );

      expect(
        EventRecordType.fromCode('desregulacion'),
        EventRecordType.dysregulation,
      );

      expect(
        EventRecordType.fromCode('situacionAtipica'),
        EventRecordType.atypicalSituation,
      );
    });

    test('Estado de rutina no pertenece a EventRecordType', () {
      expect(
        () => EventRecordType.fromCode('estadoRutina'),
        throwsA(isA<FormatException>()),
      );
    });

    test('rechaza cualquier tipo desconocido', () {
      expect(
        () => EventRecordType.fromCode('diagnostico'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
