import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/linked_account_session_lifetime.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';

void main() {
  late LinkedAccountSessionLifetime lifetime;
  late DateTime start;

  setUp(() {
    lifetime = LinkedAccountSessionLifetime();
    start = DateTime.utc(2026, 10, 21, 12);
  });

  bool startA() {
    return lifetime.start(userId: 'uid-a', now: start);
  }

  group('AUTH-03 B8.9 - Vigencia de la cuenta vinculada', () {
    test('una cuenta vigente conserva su acceso', () {
      expect(startA(), isTrue);

      expect(
        lifetime.isValid(
          userId: 'uid-a',
          now: start.add(const Duration(minutes: 30)),
        ),
        isTrue,
      );

      expect(lifetime.userId, 'uid-a');
    });

    test('A respeta el mismo limite de inactividad que B', () {
      expect(startA(), isTrue);

      final beforeExpiry = start.add(
        SessionTimeoutPolicy.foregroundIdle - const Duration(seconds: 1),
      );

      expect(lifetime.isValid(userId: 'uid-a', now: beforeExpiry), isTrue);

      final expiry = start.add(SessionTimeoutPolicy.foregroundIdle);

      expect(lifetime.isValid(userId: 'uid-a', now: expiry), isFalse);

      expect(lifetime.registerActivity(userId: 'uid-a', now: expiry), isFalse);

      expect(lifetime.hasSession, isFalse);
    });

    test('la actividad de A renueva solo su inactividad', () {
      expect(startA(), isTrue);

      final activity = start.add(
        SessionTimeoutPolicy.foregroundIdle - const Duration(minutes: 1),
      );

      expect(lifetime.registerActivity(userId: 'uid-a', now: activity), isTrue);

      expect(lifetime.record!.startedAt, start);
      expect(lifetime.record!.lastActivityAt, activity);

      expect(
        lifetime.nextDeadline,
        activity.add(SessionTimeoutPolicy.foregroundIdle),
      );
    });

    test('salir y regresar antes del limite no exige reautenticar', () {
      expect(startA(), isTrue);

      final backgroundAt = start.add(const Duration(minutes: 10));

      expect(
        lifetime.enterBackground(userId: 'uid-a', now: backgroundAt),
        isTrue,
      );

      final resumedAt = backgroundAt.add(
        SessionTimeoutPolicy.background - const Duration(seconds: 1),
      );

      expect(lifetime.resume(userId: 'uid-a', now: resumedAt), isTrue);

      expect(lifetime.record, isNotNull);
      expect(lifetime.record!.backgroundAt, isNull);
      expect(lifetime.record!.lastActivityAt, resumedAt);
      expect(lifetime.record!.startedAt, start);
    });

    test('el regreso tras vencer en segundo plano revoca A', () {
      expect(startA(), isTrue);

      final backgroundAt = start.add(const Duration(minutes: 5));

      expect(
        lifetime.enterBackground(userId: 'uid-a', now: backgroundAt),
        isTrue,
      );

      final expiredAt = backgroundAt.add(SessionTimeoutPolicy.background);

      expect(lifetime.resume(userId: 'uid-a', now: expiredAt), isFalse);

      expect(lifetime.hasSession, isFalse);
    });

    test('la actividad en segundo plano no renueva A', () {
      expect(startA(), isTrue);

      final backgroundAt = start.add(const Duration(minutes: 5));

      expect(
        lifetime.enterBackground(userId: 'uid-a', now: backgroundAt),
        isTrue,
      );

      expect(
        lifetime.registerActivity(
          userId: 'uid-a',
          now: backgroundAt.add(const Duration(minutes: 10)),
        ),
        isFalse,
      );

      expect(lifetime.record!.backgroundAt, backgroundAt);
      expect(lifetime.record!.lastActivityAt, start);
    });

    test('A conserva el limite absoluto aunque registre actividad', () {
      expect(startA(), isTrue);

      // Mantener actividad real antes de cada
      // vencimiento por inactividad.
      for (var i = 1; i <= 24; i++) {
        final instant = start.add(Duration(minutes: i * 59));

        expect(
          lifetime.registerActivity(userId: 'uid-a', now: instant),
          isTrue,
        );
      }

      expect(
        lifetime.isValid(
          userId: 'uid-a',
          now: start.add(SessionTimeoutPolicy.absolute),
        ),
        isFalse,
      );

      expect(
        lifetime.registerActivity(
          userId: 'uid-a',
          now: start.add(SessionTimeoutPolicy.absolute),
        ),
        isFalse,
      );

      expect(lifetime.hasSession, isFalse);
    });

    test('un UID diferente no reutiliza la sesion A', () {
      expect(startA(), isTrue);

      expect(
        lifetime.isValid(
          userId: 'uid-b',
          now: start.add(const Duration(minutes: 1)),
        ),
        isFalse,
      );

      expect(
        lifetime.registerActivity(
          userId: 'uid-b',
          now: start.add(const Duration(minutes: 1)),
        ),
        isFalse,
      );

      expect(lifetime.hasSession, isFalse);
    });

    test('restaurar exige UID correcto y vigencia temporal', () {
      expect(startA(), isTrue);

      final saved = lifetime.record!;

      final anotherWindow = LinkedAccountSessionLifetime();

      expect(
        anotherWindow.restore(
          record: saved,
          expectedUserId: 'uid-b',
          now: start.add(const Duration(minutes: 5)),
        ),
        isFalse,
      );

      expect(
        anotherWindow.restore(
          record: saved,
          expectedUserId: 'uid-a',
          now: start.add(const Duration(minutes: 5)),
        ),
        isTrue,
      );

      expect(anotherWindow.userId, 'uid-a');

      expect(
        anotherWindow.restore(
          record: saved,
          expectedUserId: 'uid-a',
          now: start.add(SessionTimeoutPolicy.absolute),
        ),
        isFalse,
      );

      expect(anotherWindow.hasSession, isFalse);
    });

    test('cerrar manualmente elimina la vigencia de A', () {
      expect(startA(), isTrue);

      lifetime.revoke();

      expect(lifetime.hasSession, isFalse);
      expect(lifetime.nextDeadline, isNull);

      expect(
        lifetime.resume(
          userId: 'uid-a',
          now: start.add(const Duration(minutes: 1)),
        ),
        isFalse,
      );
    });

    test('no acepta identificadores vacios', () {
      for (final userId in <String>['', ' ', ' uid-a', 'uid-a ']) {
        expect(lifetime.start(userId: userId, now: start), isFalse);

        expect(lifetime.hasSession, isFalse);
      }
    });
  });
}
