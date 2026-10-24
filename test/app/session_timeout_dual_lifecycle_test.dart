import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/session_timeout_guard.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';
import 'package:sendaris/app/session/session_timeout_store.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';

/// Repositorio de autenticacion simulado.
///
/// No utiliza Firebase real y permite comprobar que
/// una expiracion convencional no desconecta A.
final class _TestAuthRepository
    implements AuthRepository, AuthIdentityRepository, AccountIdentitySource {
  _TestAuthRepository(this._userId);

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

  void _updateUser(String? userId) {
    _userId = userId;
    _identityChanges.add(userId);
    _authChanges.add(userId != null);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    throw UnsupportedError('Esta prueba no realiza autenticacion real.');
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    _updateUser(null);
  }

  Future<void> dispose() async {
    await _authChanges.close();
    await _identityChanges.close();
  }
}

/// Persistencia en memoria para comprobar las marcas
/// de actividad sin almacenamiento externo.
final class _TestTimeoutStore implements SessionTimeoutStore {
  SessionTimeoutRecord? current;

  int writeCalls = 0;
  int clearCalls = 0;

  @override
  Future<SessionTimeoutRecord?> read() async => current;

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

/// Escenario de dos contextos Firebase independientes.
///
/// A permanece vinculada conceptualmente a biometria.
/// B es la cuenta convencional sometida al timeout.
///
/// El selector es real; solamente las fuentes de
/// identidad y persistencia son simuladas.
final class _DualLifecycleScenario {
  _DualLifecycleScenario() {
    selection = AccountSessionSelectionController(
      primary: accountA,
      secondary: accountB,
    );
  }

  final DateTime start = DateTime.utc(2026, 10, 21, 14);

  late DateTime now = start;

  final _TestAuthRepository accountA = _TestAuthRepository('uid-a');

  final _TestAuthRepository accountB = _TestAuthRepository('uid-b');

  final _TestTimeoutStore store = _TestTimeoutStore();

  late final AccountSessionSelectionController selection;

  SessionTimeoutRecord get initialRecord => SessionTimeoutRecord(
    userId: 'uid-b',
    startedAt: start,
    lastActivityAt: start,
  );

  Future<bool> select(FirebaseAccountSlot slot) {
    final userId = switch (slot) {
      FirebaseAccountSlot.primary => 'uid-a',
      FirebaseAccountSlot.secondary => 'uid-b',
    };

    return selection.select(
      slot: slot,
      expectedUserId: userId,
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
          child: const Center(
            child: Text(
              'Contenido de prueba',
              key: Key('dual-lifecycle-content'),
            ),
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
  Future<_DualLifecycleScenario> mount(
    WidgetTester tester,
    FirebaseAccountSlot selectedSlot,
  ) async {
    final scenario = _DualLifecycleScenario();

    addTearDown(() async {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await tester.pumpWidget(const SizedBox.shrink());
      await scenario.dispose();
    });

    final authorized = await scenario.select(selectedSlot);

    expect(authorized, isTrue);
    expect(scenario.selection.value, isTrue);

    await tester.pumpWidget(scenario.buildApplication());

    await tester.pump();
    await tester.pump();

    expect(scenario.store.current, isNotNull);
    expect(scenario.store.current!.userId, 'uid-b');

    return scenario;
  }

  group('AUTH-03 - Ciclo de vida dual A/B', () {
    testWidgets('B3.1 - regresar con A no debe renovar '
        'la ultima actividad de B', (tester) async {
      final scenario = await mount(tester, FirebaseAccountSlot.primary);

      final originalActivity = scenario.store.current!.lastActivityAt;

      expect(scenario.selection.selectedUserId, 'uid-a');

      // La aplicacion sale del primer plano
      // cuando A es la cuenta seleccionada.
      scenario.now = scenario.start.add(const Duration(minutes: 5));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      await tester.pump();

      // Reproduce la revocacion privada que realiza
      // SendarisDualAccountRoot para la cuenta A.
      //
      // No modifica la sesion Firebase.
      scenario.selection.lock();

      expect(scenario.selection.value, isFalse);

      expect(scenario.accountA.currentUserId, 'uid-a');

      // El usuario vuelve despues de diez minutos.
      //
      // Todavia no ha seleccionado B ni ha
      // realizado ninguna actividad convencional.
      scenario.now = scenario.start.add(const Duration(minutes: 10));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await tester.pump();
      await tester.pump();

      expect(scenario.selection.value, isFalse);

      expect(scenario.accountA.currentUserId, 'uid-a');

      expect(scenario.accountB.currentUserId, 'uid-b');

      expect(scenario.accountA.signOutCalls, 0);
      expect(scenario.accountB.signOutCalls, 0);

      // Regla de aislamiento:
      //
      // El regreso a la aplicacion con A no
      // constituye actividad autorizada de B.
      expect(
        scenario.store.current?.lastActivityAt,
        originalActivity,
        reason:
            'El regreso de A desde segundo plano '
            'no debe renovar automaticamente B.',
      );

      expect(find.byKey(const Key('session-timeout-protection')), findsNothing);
    });

    testWidgets('B3.2 - regresar con B conserva '
        'la renovacion convencional', (tester) async {
      final scenario = await mount(tester, FirebaseAccountSlot.secondary);

      expect(scenario.selection.selectedSlot, FirebaseAccountSlot.secondary);

      final originalActivity = scenario.store.current!.lastActivityAt;

      scenario.now = scenario.start.add(const Duration(minutes: 5));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      await tester.pump();

      expect(scenario.store.current?.backgroundAt, scenario.now);

      // B sigue siendo la cuenta seleccionada.
      // Su sesion no ha superado los umbrales.
      scenario.now = scenario.start.add(const Duration(minutes: 10));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await tester.pump();
      await tester.pump();

      expect(scenario.selection.value, isTrue);

      expect(scenario.selection.selectedSlot, FirebaseAccountSlot.secondary);

      expect(scenario.store.current?.lastActivityAt, scenario.now);

      expect(
        scenario.store.current!.lastActivityAt.isAfter(originalActivity),
        isTrue,
      );

      expect(scenario.store.current?.backgroundAt, isNull);

      expect(scenario.accountA.signOutCalls, 0);
      expect(scenario.accountB.signOutCalls, 0);
    });

    testWidgets('B3.3 - la expiracion de B en segundo plano '
        'no desconecta Firebase de A', (tester) async {
      final scenario = await mount(tester, FirebaseAccountSlot.primary);

      scenario.now = scenario.start.add(const Duration(minutes: 5));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);

      await tester.pump();

      scenario.selection.lock();

      expect(scenario.accountA.currentUserId, 'uid-a');

      // Han transcurrido mas de dos horas
      // desde que B quedo en segundo plano.
      scenario.now = scenario.start.add(const Duration(hours: 2, minutes: 6));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

      await tester.pump();
      await tester.pump();
      await tester.pump();

      // El timeout puede cerrar exclusivamente B.
      expect(scenario.accountB.signOutCalls, 1);

      expect(scenario.accountB.currentUserId, isNull);

      // A permanece autenticada en su
      // contexto Firebase independiente.
      expect(scenario.accountA.signOutCalls, 0);

      expect(scenario.accountA.currentUserId, 'uid-a');

      // Regresar desde segundo plano no concede
      // automaticamente acceso privado a A.
      expect(scenario.selection.value, isFalse);
    });
  });
}
