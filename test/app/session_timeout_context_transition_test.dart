import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/session_timeout_guard.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';
import 'package:sendaris/app/session/session_timeout_store.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';

final class _FakeAuthRepository
    implements AuthRepository, AuthIdentityRepository {
  _FakeAuthRepository(this._userId);

  String? _userId;
  int signOutCalls = 0;

  final _authChanges = StreamController<bool>.broadcast(sync: true);

  final _identityChanges = StreamController<String?>.broadcast(sync: true);

  @override
  bool get isAuthenticated => _userId != null;

  @override
  String? get currentUserId => _userId;

  @override
  Stream<bool> get authStateChanges => _authChanges.stream;

  @override
  Stream<String?> get userIdChanges => _identityChanges.stream;

  void changeTo(String? userId) {
    _userId = userId;

    _authChanges.add(userId != null);
    _identityChanges.add(userId);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    throw UnsupportedError('El test no utiliza autenticacion real.');
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    changeTo(null);
  }

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}

final class _MemorySessionStore implements SessionTimeoutStore {
  SessionTimeoutRecord? current;

  int writeCalls = 0;
  int clearCalls = 0;

  @override
  Future<SessionTimeoutRecord?> read() async {
    return current;
  }

  @override
  Future<void> write(SessionTimeoutRecord record) async {
    writeCalls++;
    current = record;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    current = null;
  }
}

final class _MountMarker extends StatefulWidget {
  const _MountMarker({required this.onMounted});

  final VoidCallback onMounted;

  @override
  State<_MountMarker> createState() => _MountMarkerState();
}

final class _MountMarkerState extends State<_MountMarker> {
  @override
  void initState() {
    super.initState();
    widget.onMounted();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Contenido conservado',
            key: Key('timeout-context-content'),
          ),
        ),
      ),
    );
  }
}

void main() {
  final now = DateTime.utc(2026, 10, 21, 12);

  SessionTimeoutRecord validRecord(String userId) {
    return SessionTimeoutRecord(
      userId: userId,
      startedAt: now,
      lastActivityAt: now,
    );
  }

  testWidgets('cambiar de A a un contexto vacio '
      'no desconecta A ni desmonta el hijo', (tester) async {
    final accountA = _FakeAuthRepository('uid-a');
    final conventional = _FakeAuthRepository(null);

    final store = _MemorySessionStore();

    var mounts = 0;

    Widget buildGuard(
      AuthRepository repository, {
      SessionTimeoutRecord? initialRecord,
    }) {
      return SessionTimeoutGuard(
        authRepository: repository,
        store: store,
        initialRecord: initialRecord,
        clock: () => now,
        child: _MountMarker(
          onMounted: () {
            mounts++;
          },
        ),
      );
    }

    await tester.pumpWidget(
      buildGuard(accountA, initialRecord: validRecord('uid-a')),
    );

    await tester.pump();

    expect(store.current?.userId, 'uid-a');
    expect(accountA.signOutCalls, 0);
    expect(mounts, 1);

    // El nuevo contexto convencional esta vacio.
    // A debe conservar su sesion Firebase.
    await tester.pumpWidget(buildGuard(conventional));

    await tester.pump();

    expect(accountA.currentUserId, 'uid-a');
    expect(accountA.signOutCalls, 0);

    expect(conventional.currentUserId, isNull);
    expect(conventional.signOutCalls, 0);

    expect(store.current, isNull);

    // El arbol hijo no fue desmontado.
    expect(mounts, 1);
    expect(find.byKey(const Key('timeout-context-content')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());

    await accountA.dispose();
    await conventional.dispose();
  });

  testWidgets('al vigilar una cuenta convencional existente '
      'inicia una vigencia nueva', (tester) async {
    final emptyContext = _FakeAuthRepository(null);

    final accountB = _FakeAuthRepository('uid-b');

    final store = _MemorySessionStore();

    var mounts = 0;

    Widget buildGuard(AuthRepository repository) {
      return SessionTimeoutGuard(
        authRepository: repository,
        store: store,
        clock: () => now,
        child: _MountMarker(
          onMounted: () {
            mounts++;
          },
        ),
      );
    }

    await tester.pumpWidget(buildGuard(emptyContext));

    expect(mounts, 1);
    expect(store.current, isNull);

    // El componente raiz ha confirmado
    // previamente la seleccion del contexto B.
    await tester.pumpWidget(buildGuard(accountB));

    await tester.pump();

    expect(accountB.signOutCalls, 0);
    expect(accountB.currentUserId, 'uid-b');

    expect(store.current, isNotNull);
    expect(store.current!.userId, 'uid-b');
    expect(store.current!.startedAt, now);

    expect(mounts, 1);

    await tester.pumpWidget(const SizedBox.shrink());

    await emptyContext.dispose();
    await accountB.dispose();
  });

  testWidgets('eventos del repositorio anterior '
      'no alteran la cuenta nueva', (tester) async {
    final oldContext = _FakeAuthRepository(null);

    final accountB = _FakeAuthRepository('uid-b');

    final store = _MemorySessionStore();

    Widget buildGuard(AuthRepository repository) {
      return SessionTimeoutGuard(
        authRepository: repository,
        store: store,
        clock: () => now,
        child: const MaterialApp(home: Scaffold(body: Text('Sendaris'))),
      );
    }

    await tester.pumpWidget(buildGuard(oldContext));

    await tester.pumpWidget(buildGuard(accountB));

    await tester.pump();

    expect(store.current?.userId, 'uid-b');

    // Un evento tardio del contexto anterior
    // no debe iniciar una vigencia para A.
    oldContext.changeTo('uid-a');

    await tester.pump();

    expect(store.current?.userId, 'uid-b');
    expect(accountB.currentUserId, 'uid-b');

    expect(accountB.signOutCalls, 0);
    expect(oldContext.signOutCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());

    await oldContext.dispose();
    await accountB.dispose();
  });

  testWidgets('la restauracion inicial sin registro valido '
      'sigue rechazandose', (tester) async {
    final accountA = _FakeAuthRepository('uid-a');

    final store = _MemorySessionStore();

    await tester.pumpWidget(
      SessionTimeoutGuard(
        authRepository: accountA,
        store: store,
        clock: () => now,
        initialRecord: null,
        child: const MaterialApp(home: Scaffold(body: Text('Sendaris'))),
      ),
    );

    await tester.pump();

    // Conservamos la politica anterior:
    // una sesion restaurada sin metadatos
    // de vigencia no obtiene acceso automatico.
    expect(accountA.signOutCalls, 1);
    expect(accountA.currentUserId, isNull);

    await tester.pumpWidget(const SizedBox.shrink());

    await accountA.dispose();
  });
}
