import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/acknowledged_session_timeout_store.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';
import 'package:sendaris/app/session/session_timeout_store.dart';

void main() {
  final now = DateTime.utc(2026, 10, 19, 8);

  SessionTimeoutRecord record(String userId) {
    return SessionTimeoutRecord(
      userId: userId,
      startedAt: now,
      lastActivityAt: now,
    );
  }

  group('AUTH-03 - Confirmaciones persistentes de sesión', () {
    late _FakeStore delegate;
    late AcknowledgedSessionTimeoutStore store;

    setUp(() {
      delegate = _FakeStore();

      store = AcknowledgedSessionTimeoutStore(delegate: delegate);
    });

    tearDown(() {
      store.dispose();
    });

    test('no existe confirmación antes de una escritura', () {
      expect(store.lastPersistedRecord, isNull);
      expect(store.revision, 0);
      expect(store.isDisposed, isFalse);
    });

    test('una lectura no concede ni publica confirmaciones', () async {
      final original = record('uid-a');

      delegate.current = original;

      var notifications = 0;
      store.addListener(() => notifications++);

      final result = await store.read();

      expect(result, same(original));
      expect(store.lastPersistedRecord, isNull);
      expect(store.revision, 0);
      expect(notifications, 0);
      expect(delegate.operations, <String>['read']);
    });

    test('una escritura exitosa publica una confirmación', () async {
      final original = record('uid-a');

      var notifications = 0;
      store.addListener(() => notifications++);

      await store.write(original);

      expect(delegate.current, same(original));
      expect(store.lastPersistedRecord, same(original));
      expect(store.revision, 1);
      expect(notifications, 1);

      expect(delegate.operations, <String>['write:uid-a']);
    });

    test('una eliminación confirmada invalida el registro', () async {
      await store.write(record('uid-a'));

      var notifications = 0;
      store.addListener(() => notifications++);

      await store.clear();

      expect(delegate.current, isNull);
      expect(store.lastPersistedRecord, isNull);
      expect(store.revision, 2);
      expect(notifications, 1);

      expect(delegate.operations, <String>['write:uid-a', 'clear']);
    });

    test('una escritura fallida no publica confirmaciones', () async {
      delegate.failWrite = true;

      var notifications = 0;
      store.addListener(() => notifications++);

      await expectLater(store.write(record('uid-a')), throwsStateError);

      expect(delegate.current, isNull);
      expect(store.lastPersistedRecord, isNull);
      expect(store.revision, 0);
      expect(notifications, 0);
    });

    test('una eliminación fallida conserva la confirmación', () async {
      final original = record('uid-a');

      await store.write(original);

      delegate.failClear = true;

      var notifications = 0;
      store.addListener(() => notifications++);

      await expectLater(store.clear(), throwsStateError);

      expect(delegate.current, same(original));
      expect(store.lastPersistedRecord, same(original));
      expect(store.revision, 1);
      expect(notifications, 0);
    });

    test('no notifica mientras una escritura está pendiente', () async {
      final pending = Completer<void>();
      final original = record('uid-a');

      delegate.onWrite = () => pending.future;

      var notifications = 0;
      store.addListener(() => notifications++);

      final writing = store.write(original);

      await Future<void>.delayed(Duration.zero);

      expect(delegate.operations, <String>['write:uid-a']);

      expect(delegate.current, isNull);
      expect(store.lastPersistedRecord, isNull);
      expect(store.revision, 0);
      expect(notifications, 0);

      pending.complete();

      await writing;

      expect(delegate.current, same(original));
      expect(store.lastPersistedRecord, same(original));
      expect(store.revision, 1);
      expect(notifications, 1);
    });

    test('una eliminación espera a la escritura pendiente', () async {
      final pending = Completer<void>();

      delegate.onWrite = () => pending.future;

      var notifications = 0;
      store.addListener(() => notifications++);

      final writing = store.write(record('uid-a'));
      final clearing = store.clear();

      await Future<void>.delayed(Duration.zero);

      expect(delegate.operations, <String>['write:uid-a']);

      expect(notifications, 0);

      pending.complete();

      await writing;
      await clearing;

      expect(delegate.current, isNull);
      expect(store.lastPersistedRecord, isNull);
      expect(store.revision, 2);
      expect(notifications, 2);

      expect(delegate.operations, <String>['write:uid-a', 'clear']);
    });

    test('un fallo no impide confirmar la siguiente escritura', () async {
      delegate.failWrite = true;

      await expectLater(store.write(record('uid-a')), throwsStateError);

      expect(store.revision, 0);

      delegate.failWrite = false;

      final second = record('uid-b');

      await store.write(second);

      expect(delegate.current, same(second));
      expect(store.lastPersistedRecord, same(second));
      expect(store.revision, 1);

      expect(delegate.operations, <String>['write:uid-a', 'write:uid-b']);
    });

    test('dos escrituras del mismo registro generan dos revisiones', () async {
      final original = record('uid-a');

      var notifications = 0;
      store.addListener(() => notifications++);

      await store.write(original);
      await store.write(original);

      expect(delegate.current, same(original));
      expect(store.lastPersistedRecord, same(original));
      expect(store.revision, 2);
      expect(notifications, 2);

      expect(delegate.operations, <String>['write:uid-a', 'write:uid-a']);
    });
  });
}

final class _FakeStore implements SessionTimeoutStore {
  final List<String> operations = <String>[];

  SessionTimeoutRecord? current;

  bool failWrite = false;
  bool failClear = false;

  Future<void> Function()? onWrite;

  @override
  Future<SessionTimeoutRecord?> read() async {
    operations.add('read');
    return current;
  }

  @override
  Future<void> write(SessionTimeoutRecord record) async {
    operations.add('write:${record.userId}');

    final callback = onWrite;

    if (callback != null) {
      await callback();
    }

    if (failWrite) {
      throw StateError('Escritura fallida simulada');
    }

    current = record;
  }

  @override
  Future<void> clear() async {
    operations.add('clear');

    if (failClear) {
      throw StateError('Eliminación fallida simulada');
    }

    current = null;
  }
}
