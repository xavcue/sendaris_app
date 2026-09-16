import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/history/domain/models/history_record.dart';
import 'package:sendaris/features/history/domain/models/history_record_type.dart';

void main() {
  group('HistoryRecord', () {
    test('conserva el identificador del registro y del perfil anónimo', () {
      final record = HistoryRecord(
        recordId: 'registro-001',
        anonymousId: 'anonimo-001',
        type: HistoryRecordType.behavior,
        eventDate: DateTime.utc(2026, 9, 15, 14, 30),
      );

      expect(record.recordId, 'registro-001');

      expect(record.anonymousId, 'anonimo-001');
    });

    test('conserva el tipo y la fecha efectiva del evento', () {
      final eventDate = DateTime.utc(2026, 9, 15, 14, 30);

      final record = HistoryRecord(
        recordId: 'registro-001',
        anonymousId: 'anonimo-001',
        type: HistoryRecordType.dysregulation,
        eventDate: eventDate,
      );

      expect(record.type, HistoryRecordType.dysregulation);

      expect(record.eventDate, eventDate);
    });

    test('dos perfiles distintos conservan su asociación independiente', () {
      final first = HistoryRecord(
        recordId: 'registro-a',
        anonymousId: 'perfil-a',
        type: HistoryRecordType.sleep,
        eventDate: DateTime.utc(2026, 9, 15),
      );

      final second = HistoryRecord(
        recordId: 'registro-b',
        anonymousId: 'perfil-b',
        type: HistoryRecordType.sleep,
        eventDate: DateTime.utc(2026, 9, 15),
      );

      expect(first.anonymousId, isNot(second.anonymousId));

      expect(first.recordId, isNot(second.recordId));
    });
  });
}
