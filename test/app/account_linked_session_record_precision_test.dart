import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_linked_session_persistence_sync.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';

void main() {
  final base = DateTime.utc(2026, 10, 22, 12);

  DateTime withMicroseconds(int extra) {
    return DateTime.fromMicrosecondsSinceEpoch(
      base.microsecondsSinceEpoch + extra,
      isUtc: true,
    );
  }

  SessionTimeoutRecord record({
    String userId = 'uid-a',
    DateTime? startedAt,
    DateTime? lastActivityAt,
    DateTime? backgroundAt,
  }) {
    return SessionTimeoutRecord(
      userId: userId,
      startedAt: startedAt ?? base,
      lastActivityAt: lastActivityAt ?? base,
      backgroundAt: backgroundAt,
    );
  }

  group('AUTH-03 B8.10B.10C.3G - Precision persistente', () {
    test('acepta una sesion recuperada sin microsegundos', () {
      final original = record(
        startedAt: withMicroseconds(789),
        lastActivityAt: withMicroseconds(945),
      );

      final restored = SessionTimeoutRecord.fromJson(original.toJson());

      expect(original.startedAt, isNot(restored.startedAt));

      expect(samePersistedLinkedSessionRecord(original, restored), isTrue);
    });

    test('acepta la misma sesion sin serializar', () {
      final original = record(
        startedAt: withMicroseconds(123),
        lastActivityAt: withMicroseconds(456),
      );

      expect(samePersistedLinkedSessionRecord(original, original), isTrue);
    });

    test('rechaza un inicio distinto por un milisegundo', () {
      final first = record(startedAt: base);

      final second = record(
        startedAt: base.add(const Duration(milliseconds: 1)),
      );

      expect(samePersistedLinkedSessionRecord(first, second), isFalse);
    });

    test('rechaza cambios de ultima actividad', () {
      final first = record();

      final second = record(
        lastActivityAt: base.add(const Duration(milliseconds: 1)),
      );

      expect(samePersistedLinkedSessionRecord(first, second), isFalse);
    });

    test('rechaza cambios de segundo plano', () {
      final first = record(backgroundAt: base);

      final second = record(
        backgroundAt: base.add(const Duration(milliseconds: 1)),
      );

      expect(samePersistedLinkedSessionRecord(first, second), isFalse);
    });

    test('no confunde segundo plano con primer plano', () {
      final first = record();

      final second = record(backgroundAt: base);

      expect(samePersistedLinkedSessionRecord(first, second), isFalse);
    });

    test('rechaza otra identidad', () {
      final first = record(userId: 'uid-a');

      final second = record(userId: 'uid-b');

      expect(samePersistedLinkedSessionRecord(first, second), isFalse);
    });

    test('mantiene la equivalencia tras serializar '
        'una entrada en segundo plano', () {
      final original = record(
        startedAt: withMicroseconds(123),
        lastActivityAt: withMicroseconds(456),
        backgroundAt: withMicroseconds(789),
      );

      final restored = SessionTimeoutRecord.fromJson(original.toJson());

      expect(samePersistedLinkedSessionRecord(original, restored), isTrue);
    });

    test('reconoce el mismo instante independientemente '
        'de la zona horaria', () {
      final utc = record();

      final offset = DateTime.parse('2026-10-22T07:00:00-05:00');

      final sameInstant = record(startedAt: offset, lastActivityAt: offset);

      expect(samePersistedLinkedSessionRecord(utc, sameInstant), isTrue);
    });
  });
}
