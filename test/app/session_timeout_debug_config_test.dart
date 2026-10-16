import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/session_timeout_policy.dart';

void main() {
  group('Configuración normal de caducidad', () {
    test('utiliza los límites aprobados sin activar Debug acelerado', () {
      expect(SessionTimeoutPolicy.acceleratedDebug, isFalse);

      expect(SessionTimeoutPolicy.foregroundIdle, const Duration(minutes: 60));

      expect(SessionTimeoutPolicy.background, const Duration(hours: 2));

      expect(SessionTimeoutPolicy.absolute, const Duration(hours: 24));
    });

    test('volver del segundo plano elimina su marca temporal', () {
      final startedAt = DateTime.utc(2026, 10, 15, 8);

      final initial = SessionTimeoutRecord(
        userId: 'uid-prueba',
        startedAt: startedAt,
        lastActivityAt: startedAt,
      );

      final backgrounded = initial.backgrounded(
        startedAt.add(const Duration(minutes: 10)),
      );

      expect(backgrounded.backgroundAt, isNotNull);

      final resumedAt = startedAt.add(const Duration(minutes: 15));

      final resumed = backgrounded.activity(resumedAt);

      expect(resumed.backgroundAt, isNull);
      expect(resumed.startedAt, startedAt);
      expect(resumed.lastActivityAt, resumedAt);
      expect(resumed.isExpired(resumedAt), isFalse);
    });

    test('volver al primer plano no reinicia las 24 horas', () {
      final startedAt = DateTime.utc(2026, 10, 15, 8);

      final original = SessionTimeoutRecord(
        userId: 'uid-prueba',
        startedAt: startedAt,
        lastActivityAt: startedAt,
      );

      final resumed = original
          .backgrounded(startedAt.add(const Duration(hours: 23, minutes: 58)))
          .activity(startedAt.add(const Duration(hours: 23, minutes: 59)));

      expect(resumed.startedAt, startedAt);

      expect(
        resumed.isExpired(startedAt.add(const Duration(hours: 24))),
        isTrue,
      );
    });
  });
}
