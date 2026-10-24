import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_private_content_host.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/session_timeout_guard.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';
import 'package:sendaris/app/session/session_timeout_store.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';

final class _FakeAccountRepository
    implements AuthRepository, AuthIdentityRepository, AccountIdentitySource {
  _FakeAccountRepository(this._userId);

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
    throw UnsupportedError('La prueba no utiliza Firebase real.');
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

final class _ControlledTimeoutStore implements SessionTimeoutStore {
  SessionTimeoutRecord? current;

  int writeCalls = 0;
  int clearCalls = 0;

  Completer<void>? writeGate;

  final Completer<void> writeStarted = Completer<void>();

  @override
  Future<SessionTimeoutRecord?> read() async => current;

  @override
  Future<void> write(SessionTimeoutRecord record) async {
    writeCalls++;

    if (!writeStarted.isCompleted) {
      writeStarted.complete();
    }

    final gate = writeGate;

    if (gate != null) {
      await gate.future;
    }

    current = record;
  }

  @override
  Future<void> clear() async {
    clearCalls++;
    current = null;
  }

  void releasePendingWrites() {
    final gate = writeGate;

    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }

    writeGate = null;
  }
}

final class _DualAccountScenario {
  _DualAccountScenario({bool delayPersistence = false}) {
    selection = AccountSessionSelectionController(
      primary: biometricAccount,
      secondary: conventionalAccount,
    );

    if (delayPersistence) {
      store.writeGate = Completer<void>();
    }
  }

  final _FakeAccountRepository biometricAccount = _FakeAccountRepository(
    'uid-a',
  );

  final _FakeAccountRepository conventionalAccount = _FakeAccountRepository(
    'uid-b',
  );

  final _ControlledTimeoutStore store = _ControlledTimeoutStore();

  late final AccountSessionSelectionController selection;

  DateTime now = DateTime.utc(2026, 10, 21, 12);

  SessionTimeoutRecord get conventionalRecord => SessionTimeoutRecord(
    userId: 'uid-b',
    startedAt: DateTime.utc(2026, 10, 21, 12),
    lastActivityAt: DateTime.utc(2026, 10, 21, 12),
  );

  Future<bool> selectAccount(FirebaseAccountSlot slot) {
    final expectedUserId = switch (slot) {
      FirebaseAccountSlot.primary => 'uid-a',
      FirebaseAccountSlot.secondary => 'uid-b',
    };

    return selection.select(
      slot: slot,
      expectedUserId: expectedUserId,
      verifyAccess: () async => true,
    );
  }

  Widget buildApplication() {
    return MaterialApp(
      home: Scaffold(
        body: SessionTimeoutGuard(
          authRepository: conventionalAccount,
          store: store,
          initialRecord: conventionalRecord,
          clock: () => now,

          // Solo la cuenta B utiliza el timeout convencional.
          accessSelection: selection,
          conventionalSlot: FirebaseAccountSlot.secondary,

          child: AccountPrivateContentHost(
            selection: selection,
            lockedBuilder: (_) => const Center(
              child: Text('ACCESO BLOQUEADO', key: Key('dual-account-locked')),
            ),
            privateBuilder: (context, slot, userId) {
              return Center(
                child: ElevatedButton(
                  key: const Key('dual-account-private-interaction'),
                  onPressed: () {},
                  child: Text(
                    'CONTENIDO PRIVADO $userId',
                    key: const Key('dual-account-private-content'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> dispose() async {
    store.releasePendingWrites();
    selection.dispose();
    await biometricAccount.dispose();
    await conventionalAccount.dispose();
  }
}

void main() {
  group('AUTH-03 - Aislamiento de timeout entre A y B', () {
    testWidgets('B1.1 - una persistencia pendiente de B no debe '
        'superponer su bloqueo sobre A', (tester) async {
      final scenario = _DualAccountScenario(delayPersistence: true);

      addTearDown(() async {
        scenario.store.releasePendingWrites();
        await tester.pumpWidget(const SizedBox.shrink());
        await scenario.dispose();
      });

      final authorized = await scenario.selectAccount(
        FirebaseAccountSlot.primary,
      );

      expect(authorized, isTrue);
      expect(scenario.selection.value, isTrue);

      await tester.pumpWidget(scenario.buildApplication());

      await scenario.store.writeStarted.future;
      await tester.pump();

      expect(scenario.selection.selectedSlot, FirebaseAccountSlot.primary);
      expect(scenario.selection.selectedUserId, 'uid-a');
      expect(scenario.biometricAccount.currentUserId, 'uid-a');
      expect(scenario.biometricAccount.signOutCalls, 0);

      expect(find.text('CONTENIDO PRIVADO uid-a'), findsOneWidget);

      expect(
        find.byKey(const Key('session-timeout-protection')),
        findsNothing,
        reason: 'La proteccion convencional de B no debe cubrir A.',
      );

      scenario.store.releasePendingWrites();
      await tester.pump();
    });

    testWidgets('B1.2 - interactuar con A no debe renovar '
        'la actividad convencional de B', (tester) async {
      final scenario = _DualAccountScenario();

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await scenario.dispose();
      });

      final authorized = await scenario.selectAccount(
        FirebaseAccountSlot.primary,
      );

      expect(authorized, isTrue);

      await tester.pumpWidget(scenario.buildApplication());
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('session-timeout-protection')), findsNothing);

      expect(scenario.store.current?.userId, 'uid-b');

      final originalActivity = scenario.store.current!.lastActivityAt;

      scenario.now = scenario.now.add(const Duration(seconds: 31));

      await tester.tap(
        find.byKey(const Key('dual-account-private-interaction')),
      );

      await tester.pump();
      await tester.pump();

      expect(scenario.selection.selectedSlot, FirebaseAccountSlot.primary);
      expect(scenario.biometricAccount.currentUserId, 'uid-a');
      expect(scenario.conventionalAccount.currentUserId, 'uid-b');

      expect(
        scenario.store.current?.lastActivityAt,
        originalActivity,
        reason: 'La actividad de A no puede renovar B.',
      );

      expect(scenario.conventionalAccount.signOutCalls, 0);
      expect(scenario.biometricAccount.signOutCalls, 0);
    });

    testWidgets('B1.3 - interactuar con B mantiene '
        'su propia renovacion de actividad', (tester) async {
      final scenario = _DualAccountScenario();

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await scenario.dispose();
      });

      final authorized = await scenario.selectAccount(
        FirebaseAccountSlot.secondary,
      );

      expect(authorized, isTrue);

      await tester.pumpWidget(scenario.buildApplication());
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('session-timeout-protection')), findsNothing);
      expect(scenario.store.current?.userId, 'uid-b');

      final originalActivity = scenario.store.current!.lastActivityAt;

      scenario.now = scenario.now.add(const Duration(seconds: 31));

      await tester.tap(
        find.byKey(const Key('dual-account-private-interaction')),
      );

      await tester.pump();
      await tester.pump();

      expect(scenario.store.current?.lastActivityAt, scenario.now);

      expect(
        scenario.store.current!.lastActivityAt.isAfter(originalActivity),
        isTrue,
      );

      expect(scenario.selection.selectedSlot, FirebaseAccountSlot.secondary);
      expect(scenario.conventionalAccount.currentUserId, 'uid-b');
      expect(scenario.biometricAccount.currentUserId, 'uid-a');

      expect(scenario.conventionalAccount.signOutCalls, 0);
      expect(scenario.biometricAccount.signOutCalls, 0);
    });
  });
}
