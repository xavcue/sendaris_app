import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/events/domain/models/event_record.dart';
import 'package:sendaris/features/events/domain/models/event_record_type.dart';

void main() {
  group('EventRecord', () {
    test('conserva el identificador del registro y del seguimiento', () {
      final record = EventRecord(
        recordId: 'registro-001',
        anonymousId: 'anonimo-001',
        type: EventRecordType.behavior,
        eventDate: DateTime.utc(2026, 9, 15, 14, 30),
      );

      expect(record.recordId, 'registro-001');

      expect(record.anonymousId, 'anonimo-001');
    });

    test('conserva el tipo y la fecha efectiva del evento', () {
      final eventDate = DateTime.utc(2026, 9, 15, 14, 30);

      final record = EventRecord(
        recordId: 'registro-001',
        anonymousId: 'anonimo-001',
        type: EventRecordType.dysregulation,
        eventDate: eventDate,
      );

      expect(record.type, EventRecordType.dysregulation);

      expect(record.eventDate, eventDate);
    });

    test('conserva la fecha real de creación cuando está disponible', () {
      final eventDate = DateTime.utc(2026, 9, 15);

      final createdAt = DateTime.utc(2026, 9, 15, 21, 45);

      final record = EventRecord(
        recordId: 'registro-001',
        anonymousId: 'anonimo-001',
        type: EventRecordType.atypicalSituation,
        eventDate: eventDate,
        createdAt: createdAt,
      );

      expect(record.eventDate, eventDate);

      expect(record.createdAt, createdAt);
    });

    test('usa la fecha del evento como respaldo cuando no se proporciona fecha de creación', () {
      final eventDate = DateTime.utc(2026, 9, 15, 14, 30);

      final record = EventRecord(
        recordId: 'registro-001',
        anonymousId: 'anonimo-001',
        type: EventRecordType.behavior,
        eventDate: eventDate,
      );

      expect(record.createdAt, eventDate);
    });

    test(
      'dos seguimientos distintos conservan su asociación independiente',
      () {
        final first = EventRecord(
          recordId: 'registro-a',
          anonymousId: 'seguimiento-a',
          type: EventRecordType.sleep,
          eventDate: DateTime.utc(2026, 9, 15),
        );

        final second = EventRecord(
          recordId: 'registro-b',
          anonymousId: 'seguimiento-b',
          type: EventRecordType.sleep,
          eventDate: DateTime.utc(2026, 9, 15),
        );

        expect(first.anonymousId, isNot(second.anonymousId));

        expect(first.recordId, isNot(second.recordId));
      },
    );
  });
}
