import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/session_timeout_guard.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';
import 'package:sendaris/app/session/session_timeout_store.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';

void main() {
  final start = DateTime.utc(2026, 10, 15, 8);

  SessionTimeoutRecord record({
    String userId = 'uid-a',
    DateTime? lastActivity,
    DateTime? background,
  }) {
    return SessionTimeoutRecord(
      userId: userId,
      startedAt: start,
      lastActivityAt: lastActivity ?? start,
      backgroundAt: background,
    );
  }

  group('Política de caducidad', () {
    test('permite la actividad antes de 60 minutos', () {
      final value = record();

      expect(value.isExpired(start.add(const Duration(minutes: 59))), isFalse);

      expect(value.isExpired(start.add(const Duration(minutes: 60))), isTrue);
    });

    test('la actividad posterior renueva solo el plazo inactivo', () {
      final value = record().activity(start.add(const Duration(minutes: 50)));

      expect(value.isExpired(start.add(const Duration(minutes: 109))), isFalse);

      expect(value.isExpired(start.add(const Duration(minutes: 110))), isTrue);
    });

    test('mantiene la sesión menos de dos horas en segundo plano', () {
      final backgroundTime = start.add(const Duration(minutes: 10));

      final value = record(lastActivity: backgroundTime)
          .backgrounded(backgroundTime);

      expect(
        value.isExpired(backgroundTime.add(const Duration(minutes: 119))),
        isFalse,
      );

      expect(
        value.isExpired(backgroundTime.add(const Duration(hours: 2))),
        isTrue,
      );
    });

    test('al reabrir utiliza dos horas desde la última actividad', () {
      final value = record();

      expect(
        value.isExpired(
          start.add(const Duration(minutes: 119)),
          restoring: true,
        ),
        isFalse,
      );

      expect(
        value.isExpired(start.add(const Duration(hours: 2)), restoring: true),
        isTrue,
      );
    });

    test('el máximo absoluto permanece en 24 horas', () {
      final value = record().activity(
        start.add(const Duration(hours: 23, minutes: 50)),
      );

      expect(
        value.isExpired(start.add(const Duration(hours: 23, minutes: 59))),
        isFalse,
      );

      expect(value.isExpired(start.add(const Duration(hours: 24))), isTrue);
    });

    test('un retroceso del reloj invalida el contexto temporal', () {
      final value = record();

      expect(
        value.isExpired(start.subtract(const Duration(minutes: 1))),
        isTrue,
      );
    });

    test('los metadatos se serializan y recuperan', () {
      final original = record(
        lastActivity: start.add(const Duration(minutes: 10)),
        background: start.add(const Duration(minutes: 12)),
      );

      final restored = SessionTimeoutRecord.fromJson(original.toJson());

      expect(restored.userId, original.userId);
      expect(restored.startedAt, original.startedAt);
      expect(restored.lastActivityAt, original.lastActivityAt);
      expect(restored.backgroundAt, original.backgroundAt);
    });
  });

  group('Protección del arranque', () {
    test('una sesión anterior sin metadatos se cierra', () async {
      final repository = _FakeAuthRepository('uid-a');
      final store = _MemorySessionStore();

      final result = await SessionTimeoutBootstrap.prepare(
        repository: repository,
        store: store,
        now: () => start,
      );

      expect(result, isNull);
      expect(repository.signOutCount, 1);
      expect(repository.isAuthenticated, isFalse);

      await repository.dispose();
    });

    test('una sesión todavía válida puede recuperarse', () async {
      final repository = _FakeAuthRepository('uid-a');

      final store = _MemorySessionStore(initialRecord: record());

      final result = await SessionTimeoutBootstrap.prepare(
        repository: repository,
        store: store,
        now: () => start.add(const Duration(minutes: 90)),
      );

      expect(result, isNotNull);
      expect(repository.signOutCount, 0);
      expect(repository.isAuthenticated, isTrue);

      await repository.dispose();
    });

    test('una sesión vencida en segundo plano se cierra', () async {
      final repository = _FakeAuthRepository('uid-a');

      final store = _MemorySessionStore(
        initialRecord: record().backgrounded(start),
      );

      final result = await SessionTimeoutBootstrap.prepare(
        repository: repository,
        store: store,
        now: () => start.add(const Duration(hours: 2)),
      );

      expect(result, isNull);
      expect(repository.signOutCount, 1);
      expect(store.current, isNull);

      await repository.dispose();
    });

    test('metadatos de otra cuenta no autorizan acceso', () async {
      final repository = _FakeAuthRepository('uid-b');

      final store = _MemorySessionStore(initialRecord: record(userId: 'uid-a'));

      final result = await SessionTimeoutBootstrap.prepare(
        repository: repository,
        store: store,
        now: () => start.add(const Duration(minutes: 1)),
      );

      expect(result, isNull);
      expect(repository.signOutCount, 1);

      await repository.dispose();
    });
  });

  group('Integración del protector', () {
    testWidgets('cierra sesión tras 60 minutos sin actividad', (tester) async {
      var now = start;

      final repository = _FakeAuthRepository('uid-a');
      final store = _MemorySessionStore(initialRecord: record());

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await repository.dispose();
      });

      await tester.pumpWidget(
        _testApp(
          repository: repository,
          store: store,
          initialRecord: record(),
          clock: () => now,
        ),
      );

      await tester.pumpAndSettle();

      expect(repository.isAuthenticated, isTrue);

      now = now.add(const Duration(minutes: 60));

      await tester.pump(const Duration(minutes: 60));
      await tester.pumpAndSettle();

      expect(repository.signOutCount, 1);
      expect(repository.isAuthenticated, isFalse);
    });

    testWidgets('la interacción renueva el tiempo de inactividad', (
      tester,
    ) async {
      var now = start;

      final repository = _FakeAuthRepository('uid-a');
      final store = _MemorySessionStore(initialRecord: record());

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await repository.dispose();
      });

      await tester.pumpWidget(
        _testApp(
          repository: repository,
          store: store,
          initialRecord: record(),
          clock: () => now,
        ),
      );

      await tester.pumpAndSettle();

      now = now.add(const Duration(minutes: 50));
      await tester.pump(const Duration(minutes: 50));

      await tester.tap(find.byKey(const Key('session-test-touch')));
      await tester.pump();

      now = now.add(const Duration(minutes: 59));
      await tester.pump(const Duration(minutes: 59));

      expect(repository.signOutCount, 0);
      expect(repository.isAuthenticated, isTrue);

      now = now.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));
      await tester.pumpAndSettle();

      expect(repository.signOutCount, 1);
    });

    testWidgets('el regreso después de dos horas cierra sesión', (
      tester,
    ) async {
      var now = start;

      final repository = _FakeAuthRepository('uid-a');
      final store = _MemorySessionStore(initialRecord: record());

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await repository.dispose();
      });

      await tester.pumpWidget(
        _testApp(
          repository: repository,
          store: store,
          initialRecord: record(),
          clock: () => now,
        ),
      );

      await tester.pumpAndSettle();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      await tester.pump();

      now = now.add(const Duration(hours: 2));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await tester.pumpAndSettle();

      expect(repository.signOutCount, 1);
      expect(repository.isAuthenticated, isFalse);
    });

    testWidgets('el cambio de cuenta reemplaza el contexto temporal', (
      tester,
    ) async {
      var now = start;

      final repository = _FakeAuthRepository('uid-a');
      final store = _MemorySessionStore(initialRecord: record());

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await repository.dispose();
      });

      await tester.pumpWidget(
        _testApp(
          repository: repository,
          store: store,
          initialRecord: record(),
          clock: () => now,
        ),
      );

      await tester.pumpAndSettle();

      now = now.add(const Duration(minutes: 20));

      repository.setUser('uid-b');

      await tester.pumpAndSettle();

      expect(repository.currentUserId, 'uid-b');
      expect(store.current?.userId, 'uid-b');
      expect(store.current?.startedAt, now);
      expect(repository.signOutCount, 0);

      repository.setUser('uid-a');

      await tester.pumpAndSettle();

      expect(store.current?.userId, 'uid-a');
      expect(store.current?.startedAt, now);
    });
  });
}

Widget _testApp({
  required _FakeAuthRepository repository,
  required _MemorySessionStore store,
  required SessionTimeoutRecord initialRecord,
  required DateTime Function() clock,
}) {
  return SessionTimeoutGuard(
    authRepository: repository,
    store: store,
    initialRecord: initialRecord,
    clock: clock,
    child: MaterialApp(
      home: Scaffold(
        body: Center(
          child: TextButton(
            key: const Key('session-test-touch'),
            onPressed: () {},
            child: const Text('Contenido de prueba'),
          ),
        ),
      ),
    ),
  );
}

class _MemorySessionStore implements SessionTimeoutStore {
  _MemorySessionStore({SessionTimeoutRecord? initialRecord})
    : current = initialRecord;

  SessionTimeoutRecord? current;

  @override
  Future<SessionTimeoutRecord?> read() async => current;

  @override
  Future<void> write(SessionTimeoutRecord record) async {
    current = record;
  }

  @override
  Future<void> clear() async {
    current = null;
  }
}

class _FakeAuthRepository implements AuthRepository, AuthIdentityRepository {
  _FakeAuthRepository(this._userId);

  final StreamController<bool> _authController =
      StreamController<bool>.broadcast(sync: true);

  final StreamController<String?> _identityController =
      StreamController<String?>.broadcast(sync: true);

  String? _userId;

  int signOutCount = 0;

  @override
  bool get isAuthenticated => _userId != null;

  @override
  String? get currentUserId => _userId;

  @override
  Stream<bool> get authStateChanges => _authController.stream;

  @override
  Stream<String?> get userIdChanges => _identityController.stream;

  void setUser(String? value) {
    _userId = value;
    _identityController.add(value);
    _authController.add(value != null);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    setUser('uid-login');
  }

  @override
  Future<void> signOut() async {
    signOutCount++;
    setUser(null);
  }

  Future<void> dispose() async {
    await _authController.close();
    await _identityController.close();
  }
}
