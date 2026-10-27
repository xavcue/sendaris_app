import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_scoped_session_timeout_store.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';

final class _MemoryStorage implements AccountSessionKeyValueStorage {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> getString(String key) async {
    return values[key];
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }
}

void main() {
  final start = DateTime.utc(2026, 10, 21, 12);

  SessionTimeoutRecord record(
    String userId, {
    DateTime? startedAt,
    DateTime? lastActivityAt,
    DateTime? backgroundAt,
  }) {
    return SessionTimeoutRecord(
      userId: userId,
      startedAt: startedAt ?? start,
      lastActivityAt: lastActivityAt ?? start,
      backgroundAt: backgroundAt,
    );
  }

  late _MemoryStorage storage;
  late AccountScopedSessionTimeoutStore primary;
  late AccountScopedSessionTimeoutStore secondary;

  setUp(() {
    storage = _MemoryStorage();

    primary = AccountScopedSessionTimeoutStore(
      slot: FirebaseAccountSlot.primary,
      storage: storage,
    );

    secondary = AccountScopedSessionTimeoutStore(
      slot: FirebaseAccountSlot.secondary,
      storage: storage,
    );
  });

  group('AUTH-03 B8.10B.1 - Persistencia por contexto', () {
    test('los contextos utilizan registros independientes', () async {
      await primary.write(record('uid-a'));
      await secondary.write(record('uid-b'));

      expect(storage.values.length, 2);

      expect((await primary.read())?.userId, 'uid-a');

      expect((await secondary.read())?.userId, 'uid-b');
    });

    test('eliminar primary no elimina secondary', () async {
      await primary.write(record('uid-a'));
      await secondary.write(record('uid-b'));

      await primary.clear();

      expect(await primary.read(), isNull);

      expect((await secondary.read())?.userId, 'uid-b');

      expect(storage.values.length, 1);
    });

    test('eliminar secondary no elimina primary', () async {
      await primary.write(record('uid-a'));
      await secondary.write(record('uid-b'));

      await secondary.clear();

      expect(await secondary.read(), isNull);

      expect((await primary.read())?.userId, 'uid-a');

      expect(storage.values.length, 1);
    });

    test('los registros sobreviven a nuevas instancias', () async {
      await primary.write(record('uid-a'));
      await secondary.write(record('uid-b'));

      final restoredPrimary = AccountScopedSessionTimeoutStore(
        slot: FirebaseAccountSlot.primary,
        storage: storage,
      );

      final restoredSecondary = AccountScopedSessionTimeoutStore(
        slot: FirebaseAccountSlot.secondary,
        storage: storage,
      );

      expect((await restoredPrimary.read())?.userId, 'uid-a');

      expect((await restoredSecondary.read())?.userId, 'uid-b');
    });

    test('una escritura posterior reemplaza solo su contexto', () async {
      await primary.write(record('uid-a'));
      await secondary.write(record('uid-b'));

      await secondary.write(record('uid-c'));

      expect((await primary.read())?.userId, 'uid-a');

      expect((await secondary.read())?.userId, 'uid-c');
    });

    test('conserva los tiempos originales del registro', () async {
      final backgroundAt = start.add(const Duration(minutes: 10));

      await primary.write(record('uid-a', backgroundAt: backgroundAt));

      final restored = await primary.read();

      expect(restored, isNotNull);
      expect(restored!.startedAt, start);
      expect(restored.lastActivityAt, start);
      expect(restored.backgroundAt, backgroundAt);
    });

    test('un JSON corrupto no recupera registros', () async {
      await primary.write(record('uid-a'));

      final key = storage.values.keys.single;

      storage.values[key] = '{json-invalido';

      expect(await primary.read(), isNull);
    });

    test('una versión de registro desconocida se rechaza', () async {
      await primary.write(record('uid-a'));

      final key = storage.values.keys.single;

      final invalid = record('uid-a').toJson();
      invalid['version'] = 999;

      storage.values[key] = jsonEncode(invalid);

      expect(await primary.read(), isNull);
    });

    test('rechaza identificadores vacíos o mal formados', () {
      for (final userId in <String>['', ' ', ' uid-a', 'uid-a ']) {
        expect(
          () => primary.write(record(userId)),
          throwsArgumentError,
          reason: 'Debe rechazar el UID inválido: "$userId"',
        );
      }

      expect(storage.values, isEmpty);
    });

    test('no modifica el almacenamiento temporal anterior', () async {
      storage.values['sendaris.session.timeout.v1'] = 'registro-anterior';

      await primary.write(record('uid-a'));
      await secondary.write(record('uid-b'));

      await primary.clear();
      await secondary.clear();

      expect(
        storage.values['sendaris.session.timeout.v1'],
        'registro-anterior',
      );
    });
  });

  group('AUTH-03 B8.10B.1 - Candidatos de restauración', () {
    test('permite un registro vigente del mismo UID', () {
      expect(
        AccountSessionRestorationCandidatePolicy.isEligible(
          record: record('uid-a'),
          authenticatedUserId: 'uid-a',
          now: start.add(const Duration(minutes: 30)),
        ),
        isTrue,
      );
    });

    test('rechaza una identidad Firebase diferente', () {
      expect(
        AccountSessionRestorationCandidatePolicy.isEligible(
          record: record('uid-a'),
          authenticatedUserId: 'uid-b',
          now: start.add(const Duration(minutes: 1)),
        ),
        isFalse,
      );
    });

    test('rechaza ausencia de sesión Firebase', () {
      expect(
        AccountSessionRestorationCandidatePolicy.isEligible(
          record: record('uid-a'),
          authenticatedUserId: null,
          now: start.add(const Duration(minutes: 1)),
        ),
        isFalse,
      );
    });

    test('rechaza ausencia de metadatos temporales', () {
      expect(
        AccountSessionRestorationCandidatePolicy.isEligible(
          record: null,
          authenticatedUserId: 'uid-a',
          now: start.add(const Duration(minutes: 1)),
        ),
        isFalse,
      );
    });

    test('respeta 60 minutos sin marca de segundo plano', () {
      expect(
        AccountSessionRestorationCandidatePolicy.isEligible(
          record: record('uid-a'),
          authenticatedUserId: 'uid-a',
          now: start.add(
            SessionTimeoutPolicy.foregroundIdle - const Duration(seconds: 1),
          ),
        ),
        isTrue,
      );

      expect(
        AccountSessionRestorationCandidatePolicy.isEligible(
          record: record('uid-a'),
          authenticatedUserId: 'uid-a',
          now: start.add(SessionTimeoutPolicy.foregroundIdle),
        ),
        isFalse,
      );
    });

    test('respeta el límite de segundo plano', () {
      final backgroundAt = start.add(const Duration(minutes: 5));

      final saved = record('uid-a', backgroundAt: backgroundAt);

      expect(
        AccountSessionRestorationCandidatePolicy.isEligible(
          record: saved,
          authenticatedUserId: 'uid-a',
          now: backgroundAt.add(
            SessionTimeoutPolicy.background - const Duration(seconds: 1),
          ),
        ),
        isTrue,
      );

      expect(
        AccountSessionRestorationCandidatePolicy.isEligible(
          record: saved,
          authenticatedUserId: 'uid-a',
          now: backgroundAt.add(SessionTimeoutPolicy.background),
        ),
        isFalse,
      );
    });

    test('respeta el límite absoluto de la sesión', () {
      final saved = record(
        'uid-a',
        lastActivityAt: start.add(
          SessionTimeoutPolicy.absolute - const Duration(minutes: 1),
        ),
      );

      expect(
        AccountSessionRestorationCandidatePolicy.isEligible(
          record: saved,
          authenticatedUserId: 'uid-a',
          now: start.add(SessionTimeoutPolicy.absolute),
        ),
        isFalse,
      );
    });

    test('rechaza fechas anteriores al inicio registrado', () {
      expect(
        AccountSessionRestorationCandidatePolicy.isEligible(
          record: record('uid-a'),
          authenticatedUserId: 'uid-a',
          now: start.subtract(const Duration(minutes: 1)),
        ),
        isFalse,
      );
    });
  });
}
