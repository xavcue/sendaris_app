import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/serialized_session_timeout_store.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';
import 'package:sendaris/app/session/session_timeout_store.dart';

void main() {
  final now = DateTime.utc(2026, 10, 18, 8);

  SessionTimeoutRecord record(String userId) {
    return SessionTimeoutRecord(
      userId: userId,
      startedAt: now,
      lastActivityAt: now,
    );
  }

  group('AUTH-03 - Almacenamiento serializado', () {
    late _FakeStore delegate;
    late SerializedSessionTimeoutStore store;

    setUp(() {
      delegate = _FakeStore();

      store = SerializedSessionTimeoutStore(delegate: delegate);
    });

    test('delega una lectura sin modificar el registro', () async {
      final original = record('uid-a');
      delegate.current = original;

      final result = await store.read();

      expect(result, same(original));
      expect(delegate.operations, <String>['read']);
    });

    test('delega una escritura y conserva los datos', () async {
      final original = record('uid-a');

      await store.write(original);

      expect(delegate.current, same(original));
      expect(delegate.operations, <String>['write:uid-a']);
    });

    test('una lectura espera a la escritura anterior', () async {
      final pending = Completer<void>();
      final original = record('uid-a');

      delegate.onWrite = () => pending.future;

      final writing = store.write(original);
      final reading = store.read();

      await Future<void>.delayed(Duration.zero);

      expect(delegate.operations, <String>['write:uid-a']);

      pending.complete();

      await writing;

      expect(await reading, same(original));

      expect(delegate.operations, <String>['write:uid-a', 'read']);
    });

    test('clear espera a una escritura pendiente', () async {
      final pending = Completer<void>();

      delegate.onWrite = () => pending.future;

      final writing = store.write(record('uid-a'));
      final clearing = store.clear();

      await Future<void>.delayed(Duration.zero);

      expect(delegate.operations, <String>['write:uid-a']);

      pending.complete();

      await writing;
      await clearing;

      expect(delegate.current, isNull);

      expect(delegate.operations, <String>['write:uid-a', 'clear']);
    });

    test('una escritura nueva espera a clear', () async {
      final pending = Completer<void>();

      delegate.current = record('uid-a');
      delegate.onClear = () => pending.future;

      final clearing = store.clear();
      final writing = store.write(record('uid-b'));

      await Future<void>.delayed(Duration.zero);

      expect(delegate.operations, <String>['clear']);

      pending.complete();

      await clearing;
      await writing;

      expect(delegate.current?.userId, 'uid-b');

      expect(delegate.operations, <String>['clear', 'write:uid-b']);
    });

    test('un fallo de escritura no bloquea operaciones posteriores', () async {
      delegate.failWrite = true;

      await expectLater(store.write(record('uid-a')), throwsStateError);

      delegate.failWrite = false;

      await store.write(record('uid-b'));

      final result = await store.read();

      expect(result?.userId, 'uid-b');

      expect(delegate.operations, <String>[
        'write:uid-a',
        'write:uid-b',
        'read',
      ]);
    });

    test('un fallo de lectura no bloquea la cola', () async {
      delegate.failRead = true;

      await expectLater(store.read(), throwsStateError);

      delegate.failRead = false;

      await store.write(record('uid-b'));

      expect(delegate.current?.userId, 'uid-b');

      expect(delegate.operations, <String>['read', 'write:uid-b']);
    });

    test('un fallo de clear se propaga y permite reintento', () async {
      delegate.current = record('uid-a');
      delegate.failClear = true;

      await expectLater(store.clear(), throwsStateError);

      expect(delegate.current?.userId, 'uid-a');

      delegate.failClear = false;

      await store.clear();

      expect(delegate.current, isNull);

      expect(delegate.operations, <String>['clear', 'clear']);
    });

    test('preserva el orden de varias operaciones concurrentes', () async {
      final firstWrite = store.write(record('uid-a'));
      final firstRead = store.read();
      final clearing = store.clear();
      final secondWrite = store.write(record('uid-b'));
      final secondRead = store.read();

      await Future.wait<void>([firstWrite, clearing, secondWrite]);

      expect((await firstRead)?.userId, 'uid-a');
      expect((await secondRead)?.userId, 'uid-b');

      expect(delegate.current?.userId, 'uid-b');

      expect(delegate.operations, <String>[
        'write:uid-a',
        'read',
        'clear',
        'write:uid-b',
        'read',
      ]);
    });
  });
}

final class _FakeStore implements SessionTimeoutStore {
  final List<String> operations = <String>[];

  SessionTimeoutRecord? current;

  bool failRead = false;
  bool failWrite = false;
  bool failClear = false;

  Future<void> Function()? onRead;
  Future<void> Function()? onWrite;
  Future<void> Function()? onClear;

  @override
  Future<SessionTimeoutRecord?> read() async {
    operations.add('read');

    final callback = onRead;

    if (callback != null) {
      await callback();
    }

    if (failRead) {
      throw StateError('Fallo simulado de lectura');
    }

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
      throw StateError('Fallo simulado de escritura');
    }

    current = record;
  }

  @override
  Future<void> clear() async {
    operations.add('clear');

    final callback = onClear;

    if (callback != null) {
      await callback();
    }

    if (failClear) {
      throw StateError('Fallo simulado de eliminación');
    }

    current = null;
  }
}
