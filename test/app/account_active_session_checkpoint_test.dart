import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_active_session_checkpoint.dart';
import 'package:sendaris/app/session/account_scoped_session_timeout_store.dart';
import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';

final class _MemoryCheckpointStorage implements AccountSessionKeyValueStorage {
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
  final validTime = start.add(const Duration(minutes: 10));

  AccountActiveSessionCheckpoint checkpoint(
    FirebaseAccountSlot slot,
    String userId,
  ) {
    return AccountActiveSessionCheckpoint(slot: slot, userId: userId);
  }

  SessionTimeoutRecord record(
    String userId, {
    DateTime? lastActivityAt,
    DateTime? backgroundAt,
  }) {
    return SessionTimeoutRecord(
      userId: userId,
      startedAt: start,
      lastActivityAt: lastActivityAt ?? start,
      backgroundAt: backgroundAt,
    );
  }

  AccountSessionResumeDecision decide({
    AccountActiveSessionCheckpoint? active,
    SessionTimeoutRecord? primaryRecord,
    SessionTimeoutRecord? secondaryRecord,
    String? primaryUserId,
    String? secondaryUserId,
    BiometricBindingState binding = const BiometricBindingDisabled(),
    DateTime? now,
  }) {
    return AccountActiveSessionRestorationPolicy.decide(
      checkpoint: active,
      primaryRecord: primaryRecord,
      secondaryRecord: secondaryRecord,
      primaryFirebaseUserId: primaryUserId,
      secondaryFirebaseUserId: secondaryUserId,
      binding: binding,
      now: now ?? validTime,
    );
  }

  group('AUTH-03 B8.10B.2 - Seleccion persistente', () {
    late _MemoryCheckpointStorage storage;
    late AccountActiveSessionCheckpointStore store;

    setUp(() {
      storage = _MemoryCheckpointStorage();

      store = AccountActiveSessionCheckpointStore(storage: storage);
    });

    test('inicialmente no hay cuenta seleccionada', () async {
      expect(await store.read(), isNull);
    });

    test('guarda la cuenta primaria y su UID', () async {
      await store.write(checkpoint(FirebaseAccountSlot.primary, 'uid-a'));

      final saved = await store.read();

      expect(saved, isNotNull);
      expect(saved!.slot, FirebaseAccountSlot.primary);
      expect(saved.userId, 'uid-a');
    });

    test('permite cambiar la ultima cuenta de A a B', () async {
      await store.write(checkpoint(FirebaseAccountSlot.primary, 'uid-a'));

      await store.write(checkpoint(FirebaseAccountSlot.secondary, 'uid-b'));

      final saved = await store.read();

      expect(saved!.slot, FirebaseAccountSlot.secondary);
      expect(saved.userId, 'uid-b');
      expect(storage.values.length, 1);
    });

    test('puede leerse desde una instancia nueva', () async {
      await store.write(checkpoint(FirebaseAccountSlot.secondary, 'uid-b'));

      final restored = AccountActiveSessionCheckpointStore(storage: storage);

      expect((await restored.read())?.userId, 'uid-b');
    });

    test('cerrar acceso elimina la cuenta activa', () async {
      await store.write(checkpoint(FirebaseAccountSlot.primary, 'uid-a'));

      await store.clear();

      expect(await store.read(), isNull);
      expect(storage.values, isEmpty);
    });

    test('rechaza un punto de restauracion corrupto', () async {
      await store.write(checkpoint(FirebaseAccountSlot.primary, 'uid-a'));

      final key = storage.values.keys.single;
      storage.values[key] = '{json-invalido';

      expect(await store.read(), isNull);
    });

    test('rechaza una version desconocida', () async {
      await store.write(checkpoint(FirebaseAccountSlot.primary, 'uid-a'));

      final key = storage.values.keys.single;

      storage.values[key] = jsonEncode({
        'version': 999,
        'slot': 'primary',
        'userId': 'uid-a',
      });

      expect(await store.read(), isNull);
    });

    test('rechaza un contexto desconocido', () async {
      await store.write(checkpoint(FirebaseAccountSlot.primary, 'uid-a'));

      final key = storage.values.keys.single;

      storage.values[key] = jsonEncode({
        'version': 1,
        'slot': 'tertiary',
        'userId': 'uid-a',
      });

      expect(await store.read(), isNull);
    });

    test('rechaza UID vacio o mal formado', () async {
      for (final userId in <String>['', ' ', ' uid-a', 'uid-a ']) {
        expect(
          () => store.write(checkpoint(FirebaseAccountSlot.primary, userId)),
          throwsArgumentError,
        );
      }

      expect(storage.values, isEmpty);
    });

    test('no borra los registros temporales A y B', () async {
      await storage.setString('sendaris.session.dual.primary.v1', 'registro-a');

      await storage.setString(
        'sendaris.session.dual.secondary.v1',
        'registro-b',
      );

      await store.write(checkpoint(FirebaseAccountSlot.primary, 'uid-a'));

      await store.clear();

      expect(storage.values['sendaris.session.dual.primary.v1'], 'registro-a');

      expect(
        storage.values['sendaris.session.dual.secondary.v1'],
        'registro-b',
      );
    });
  });

  group('AUTH-03 B8.10B.2 - Evaluacion del reinicio', () {
    test('sin punto de restauracion requiere login', () {
      expect(
        decide(primaryUserId: 'uid-a', primaryRecord: record('uid-a')),
        AccountSessionResumeDecision.requireSignIn,
      );
    });

    test('restaura candidato convencional vigente', () {
      expect(
        decide(
          active: checkpoint(FirebaseAccountSlot.primary, 'uid-b'),
          primaryUserId: 'uid-b',
          primaryRecord: record('uid-b'),
        ),
        AccountSessionResumeDecision.restoreConventional,
      );
    });

    test('rechaza UID Firebase diferente al guardado', () {
      expect(
        decide(
          active: checkpoint(FirebaseAccountSlot.primary, 'uid-b'),
          primaryUserId: 'uid-c',
          primaryRecord: record('uid-b'),
        ),
        AccountSessionResumeDecision.requireSignIn,
      );
    });

    test('rechaza metadatos temporales ausentes', () {
      expect(
        decide(
          active: checkpoint(FirebaseAccountSlot.primary, 'uid-b'),
          primaryUserId: 'uid-b',
        ),
        AccountSessionResumeDecision.requireSignIn,
      );
    });

    test('rechaza una sesion convencional vencida', () {
      expect(
        decide(
          active: checkpoint(FirebaseAccountSlot.primary, 'uid-b'),
          primaryUserId: 'uid-b',
          primaryRecord: record('uid-b'),
          now: start.add(SessionTimeoutPolicy.foregroundIdle),
        ),
        AccountSessionResumeDecision.requireSignIn,
      );
    });

    test('no mezcla dos sesiones del mismo UID', () {
      expect(
        decide(
          active: checkpoint(FirebaseAccountSlot.primary, 'uid-a'),
          primaryUserId: 'uid-a',
          secondaryUserId: 'uid-a',
          primaryRecord: record('uid-a'),
        ),
        AccountSessionResumeDecision.denyAccess,
      );
    });

    test('rechaza vinculacion ilegible', () {
      expect(
        decide(
          active: checkpoint(FirebaseAccountSlot.primary, 'uid-a'),
          primaryUserId: 'uid-a',
          primaryRecord: record('uid-a'),
          binding: const BiometricBindingUnavailable(),
        ),
        AccountSessionResumeDecision.denyAccess,
      );
    });

    test('A vinculada no recibe acceso automatico', () {
      expect(
        decide(
          active: checkpoint(FirebaseAccountSlot.primary, 'uid-a'),
          primaryUserId: 'uid-a',
          primaryRecord: record('uid-a'),
          binding: const BiometricBindingEnabled(userId: 'uid-a'),
        ),
        AccountSessionResumeDecision.requireLinkedAuthorization,
      );
    });

    test('B puede ser candidata si A ocupa otro contexto', () {
      expect(
        decide(
          active: checkpoint(FirebaseAccountSlot.secondary, 'uid-b'),
          primaryUserId: 'uid-a',
          secondaryUserId: 'uid-b',
          primaryRecord: record('uid-a'),
          secondaryRecord: record('uid-b'),
          binding: const BiometricBindingEnabled(userId: 'uid-a'),
        ),
        AccountSessionResumeDecision.restoreConventional,
      );
    });

    test('B no se restaura si falta la identidad de A', () {
      expect(
        decide(
          active: checkpoint(FirebaseAccountSlot.secondary, 'uid-b'),
          secondaryUserId: 'uid-b',
          secondaryRecord: record('uid-b'),
          binding: const BiometricBindingEnabled(userId: 'uid-a'),
        ),
        AccountSessionResumeDecision.denyAccess,
      );
    });

    test('una cuenta convencional no puede ocupar A', () {
      expect(
        decide(
          active: checkpoint(FirebaseAccountSlot.primary, 'uid-b'),
          primaryUserId: 'uid-b',
          secondaryUserId: 'uid-a',
          primaryRecord: record('uid-b'),
          binding: const BiometricBindingEnabled(userId: 'uid-a'),
        ),
        AccountSessionResumeDecision.restoreConventional,
      );
    });

    test('sin vinculacion no restaura SECONDARY', () {
      expect(
        decide(
          active: checkpoint(FirebaseAccountSlot.secondary, 'uid-b'),
          secondaryUserId: 'uid-b',
          secondaryRecord: record('uid-b'),
        ),
        AccountSessionResumeDecision.denyAccess,
      );
    });

    test('un registro de A vencido no permite recuperarla', () {
      expect(
        decide(
          active: checkpoint(FirebaseAccountSlot.primary, 'uid-a'),
          primaryUserId: 'uid-a',
          primaryRecord: record('uid-a'),
          binding: const BiometricBindingEnabled(userId: 'uid-a'),
          now: start.add(SessionTimeoutPolicy.absolute),
        ),
        AccountSessionResumeDecision.requireSignIn,
      );
    });
  });
}
