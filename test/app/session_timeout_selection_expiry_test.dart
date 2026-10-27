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

final class _FakeAuthRepository
    implements AuthRepository, AuthIdentityRepository, AccountIdentitySource {
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

  @override
  Future<void> signIn({required String email, required String password}) async {
    throw UnsupportedError('La prueba no utiliza Firebase real.');
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;

    _userId = null;

    _identityChanges.add(null);
    _authChanges.add(false);
  }

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}

final class _MemoryTimeoutStore implements SessionTimeoutStore {
  SessionTimeoutRecord? record;

  int writes = 0;
  int clears = 0;

  @override
  Future<SessionTimeoutRecord?> read() async => record;

  @override
  Future<void> write(SessionTimeoutRecord value) async {
    writes++;
    record = value;
  }

  @override
  Future<void> clear() async {
    clears++;
    record = null;
  }
}

final class _ExpirySelectionScenario {
  _ExpirySelectionScenario() {
    selection = AccountSessionSelectionController(
      primary: accountA,
      secondary: accountB,
    );
  }

  final accountA = _FakeAuthRepository('uid-a');
  final accountB = _FakeAuthRepository('uid-b');

  final store = _MemoryTimeoutStore();

  late final AccountSessionSelectionController selection;

  final DateTime start = DateTime.utc(2026, 10, 21, 16);

  late DateTime now = start;

  int privateBMounts = 0;

  SessionTimeoutRecord get initialRecord => SessionTimeoutRecord(
    userId: 'uid-b',
    startedAt: start,
    lastActivityAt: start,
  );

  Future<bool> selectA() {
    return selection.select(
      slot: FirebaseAccountSlot.primary,
      expectedUserId: 'uid-a',
      verifyAccess: () async => true,
    );
  }

  Future<bool> selectB() {
    return selection.select(
      slot: FirebaseAccountSlot.secondary,
      expectedUserId: 'uid-b',
      verifyAccess: () async => true,
    );
  }

  Widget buildApplication() {
    return MaterialApp(
      home: Scaffold(
        body: SessionTimeoutGuard(
          authRepository: accountB,
          store: store,
          initialRecord: initialRecord,
          clock: () => now,
          accessSelection: selection,
          conventionalSlot: FirebaseAccountSlot.secondary,
          child: AccountPrivateContentHost(
            selection: selection,
            lockedBuilder: (_) => const Center(
              child: Text('ACCESO BLOQUEADO', key: Key('b6-locked')),
            ),
            privateBuilder: (context, slot, userId) {
              if (slot == FirebaseAccountSlot.secondary) {
                privateBMounts++;
              }

              return Center(
                child: Text(
                  'PRIVADO ${slot.name}:$userId',
                  key: const Key('b6-private'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> dispose() async {
    selection.dispose();

    await accountA.dispose();
    await accountB.dispose();
  }
}

void main() {
  Future<_ExpirySelectionScenario> mount(WidgetTester tester) async {
    final scenario = _ExpirySelectionScenario();

    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());

      await scenario.dispose();
    });

    // Montar el guard con B autenticada y un registro
    // de vigencia inicialmente valido.
    await tester.pumpWidget(scenario.buildApplication());

    await tester.pump();
    await tester.pump();

    expect(scenario.store.record?.userId, 'uid-b');

    // Seleccionar A: las dos sesiones Firebase existen,
    // pero solamente A recibe autorizacion privada.
    expect(await scenario.selectA(), isTrue);

    await tester.pump();

    expect(find.text('PRIVADO primary:uid-a'), findsOneWidget);

    expect(scenario.privateBMounts, 0);

    expect(scenario.accountA.signOutCalls, 0);

    expect(scenario.accountB.signOutCalls, 0);

    return scenario;
  }

  group('AUTH-03 - Seleccion y vencimiento convencional', () {
    testWidgets('B6.1 - una sesion B vigente '
        'puede seleccionarse normalmente', (tester) async {
      final scenario = await mount(tester);

      // Simular un momento anterior al limite
      // de inactividad convencional.
      scenario.now = scenario.start.add(
        SessionTimeoutPolicy.foregroundIdle - const Duration(seconds: 1),
      );

      expect(await scenario.selectB(), isTrue);

      await tester.pump();

      expect(scenario.selection.value, isTrue);

      expect(scenario.selection.selectedSlot, FirebaseAccountSlot.secondary);

      expect(scenario.selection.selectedUserId, 'uid-b');

      expect(find.text('PRIVADO secondary:uid-b'), findsOneWidget);

      expect(scenario.privateBMounts, greaterThan(0));

      expect(scenario.accountA.currentUserId, 'uid-a');

      expect(scenario.accountB.currentUserId, 'uid-b');

      expect(scenario.accountA.signOutCalls, 0);
      expect(scenario.accountB.signOutCalls, 0);
    });

    testWidgets('B6.2 - seleccionar B despues de su vencimiento '
        'debe revocarla inmediatamente', (tester) async {
      final scenario = await mount(tester);

      // Simular un temporizador retrasado:
      // el reloj supera el limite de inactividad,
      // pero no se avanza el tiempo del test
      // para ejecutar automaticamente el Timer.
      scenario.now = scenario.start.add(
        SessionTimeoutPolicy.foregroundIdle + const Duration(seconds: 1),
      );

      final originalRecord = scenario.store.record;

      expect(originalRecord, isNotNull);

      expect(originalRecord!.isExpired(scenario.now), isTrue);

      // Firebase sigue autenticada antes de
      // intentar seleccionar B.
      expect(scenario.accountB.currentUserId, 'uid-b');

      expect(await scenario.selectB(), isTrue);

      await tester.pump();
      await tester.pump();

      // La seleccion debe provocar una comprobacion
      // inmediata de vencimiento, incluso si el
      // temporizador programado aun no se ejecuto.
      //
      // Este es el requisito principal del diagnostico.
      expect(
        scenario.accountB.signOutCalls,
        1,
        reason:
            'Al seleccionar una sesion convencional '
            'vencida, el guard debe revocarla '
            'sin depender de un temporizador retrasado.',
      );

      expect(scenario.accountB.currentUserId, isNull);

      expect(scenario.selection.value, isFalse);

      expect(find.text('PRIVADO secondary:uid-b'), findsNothing);

      expect(scenario.privateBMounts, 0);

      // La sesion biometrica A no debe
      // sufrir modificaciones.
      expect(scenario.accountA.currentUserId, 'uid-a');

      expect(scenario.accountA.signOutCalls, 0);
    });
  });
}
