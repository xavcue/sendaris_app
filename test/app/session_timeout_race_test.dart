import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/session_timeout_guard.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';
import 'package:sendaris/app/session/session_timeout_store.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';

void main() {
  testWidgets('un cierre vencido de A no cierra la nueva sesión B', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 10, 15, 8);

    final repository = _DelayedSignOutRepository();

    final initialRecord = SessionTimeoutRecord(
      userId: 'uid-a',
      startedAt: now,
      lastActivityAt: now,
    );

    final store = _MemoryStore(initialRecord);

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await repository.dispose();
    });

    await tester.pumpWidget(
      SessionTimeoutGuard(
        authRepository: repository,
        store: store,
        initialRecord: initialRecord,
        clock: () => now,
        child: const MaterialApp(
          home: Scaffold(body: Center(child: Text('Seguimiento de prueba'))),
        ),
      ),
    );

    await tester.pumpAndSettle();

    now = now.add(const Duration(minutes: 60));

    await tester.pump(const Duration(minutes: 60));
    await tester.pump();

    expect(repository.signOutStarted, isTrue);

    expect(find.byKey(const Key('session-timeout-protection')), findsOneWidget);

    // Mientras A espera su cierre, se autentica B.
    repository.setUser('uid-b');

    await tester.pumpAndSettle();

    expect(store.current?.userId, 'uid-b');

    // Se termina la operación antigua de A.
    repository.completeSignOut();

    await tester.pumpAndSettle();

    expect(repository.currentUserId, 'uid-b');
    expect(repository.isAuthenticated, isTrue);
    expect(store.current?.userId, 'uid-b');

    expect(find.byKey(const Key('session-timeout-protection')), findsNothing);
  });
}

class _MemoryStore implements SessionTimeoutStore {
  _MemoryStore(this.current);

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

class _DelayedSignOutRepository
    implements AuthRepository, AuthIdentityRepository {
  final StreamController<bool> _authController =
      StreamController<bool>.broadcast(sync: true);

  final StreamController<String?> _identityController =
      StreamController<String?>.broadcast(sync: true);

  final Completer<void> _signOutGate = Completer<void>();

  String? _userId = 'uid-a';

  bool signOutStarted = false;

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
    setUser('uid-b');
  }

  @override
  Future<void> signOut() async {
    final requestedUserId = _userId;

    signOutStarted = true;

    await _signOutGate.future;

    // Simula la protección de contexto del repositorio real:
    // una operación antigua no puede cerrar una cuenta nueva.
    if (_userId == requestedUserId) {
      setUser(null);
    }
  }

  void completeSignOut() {
    if (!_signOutGate.isCompleted) {
      _signOutGate.complete();
    }
  }

  Future<void> dispose() async {
    completeSignOut();

    await _authController.close();
    await _identityController.close();
  }
}
