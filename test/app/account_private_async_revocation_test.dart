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

final class _TestRepository
    implements AuthRepository, AuthIdentityRepository, AccountIdentitySource {
  _TestRepository(this._userId);

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

    _identityChanges.add(userId);
    _authChanges.add(userId != null);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    throw UnsupportedError('La prueba no realiza autenticacion real.');
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

/// Controla las escrituras de vigencia temporal.
///
/// Las pruebas pueden detener una escritura y
/// completarla despues de revocar la autorizacion.
final class _DelayedTimeoutStore implements SessionTimeoutStore {
  _DelayedTimeoutStore({required bool blockWrites}) {
    if (blockWrites) {
      _writeGate = Completer<void>();
    }
  }

  SessionTimeoutRecord? current;

  Completer<void>? _writeGate;

  final writeStarted = Completer<void>();

  int writeCalls = 0;
  int clearCalls = 0;

  @override
  Future<SessionTimeoutRecord?> read() async => current;

  @override
  Future<void> write(SessionTimeoutRecord record) async {
    writeCalls++;

    if (!writeStarted.isCompleted) {
      writeStarted.complete();
    }

    final gate = _writeGate;

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

  void release() {
    final gate = _writeGate;

    _writeGate = null;

    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }
  }
}

/// Permite observar los montajes reales del contenido
/// privado, no solamente las llamadas a su builder.
final class _PrivatePanel extends StatefulWidget {
  const _PrivatePanel({
    required this.identity,
    required this.onMounted,
    required this.onUnmounted,
  });

  final String identity;

  final ValueChanged<String> onMounted;
  final ValueChanged<String> onUnmounted;

  @override
  State<_PrivatePanel> createState() => _PrivatePanelState();
}

final class _PrivatePanelState extends State<_PrivatePanel> {
  @override
  void initState() {
    super.initState();
    widget.onMounted(widget.identity);
  }

  @override
  void dispose() {
    widget.onUnmounted(widget.identity);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'PRIVADO ${widget.identity}',
        key: const Key('b5-private-panel'),
      ),
    );
  }
}

/// Escenario integrado con dos repositorios independientes.
///
/// A: cuenta reservada para biometria.
/// B y C: cuentas convencionales sucesivas.
///
/// Se utilizan los controladores reales de seleccion,
/// montaje privado y vigencia temporal.
final class _AsyncRevocationScenario {
  _AsyncRevocationScenario({bool blockWrites = false})
    : store = _DelayedTimeoutStore(blockWrites: blockWrites) {
    selection = AccountSessionSelectionController(
      primary: accountA,
      secondary: accountB,
    );
  }

  final accountA = _TestRepository('uid-a');

  final accountB = _TestRepository(null);

  final _DelayedTimeoutStore store;

  late final AccountSessionSelectionController selection;

  final mountedIdentities = <String>[];
  final unmountedIdentities = <String>[];

  final now = DateTime.utc(2026, 10, 21, 16);

  Future<bool> authorize({
    required FirebaseAccountSlot slot,
    required String expectedUserId,
  }) {
    return selection.select(
      slot: slot,
      expectedUserId: expectedUserId,
      verifyAccess: () async => true,
    );
  }

  Future<bool> authorizeA() {
    return authorize(
      slot: FirebaseAccountSlot.primary,
      expectedUserId: 'uid-a',
    );
  }

  Future<bool> authorizeB(String userId) {
    return authorize(
      slot: FirebaseAccountSlot.secondary,
      expectedUserId: userId,
    );
  }

  Widget buildApplication() {
    return MaterialApp(
      home: Scaffold(
        body: SessionTimeoutGuard(
          authRepository: accountB,
          store: store,
          clock: () => now,
          accessSelection: selection,
          conventionalSlot: FirebaseAccountSlot.secondary,
          child: AccountPrivateContentHost(
            selection: selection,
            lockedBuilder: (_) => const Center(
              child: Text('ACCESO PRIVADO BLOQUEADO', key: Key('b5-locked')),
            ),
            privateBuilder: (context, slot, userId) {
              return _PrivatePanel(
                identity: '${slot.name}:$userId',
                onMounted: mountedIdentities.add,
                onUnmounted: unmountedIdentities.add,
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> dispose() async {
    store.release();

    selection.dispose();

    await accountA.dispose();
    await accountB.dispose();
  }
}

void main() {
  Future<_AsyncRevocationScenario> mount(
    WidgetTester tester, {
    bool blockWrites = false,
  }) async {
    final scenario = _AsyncRevocationScenario(blockWrites: blockWrites);

    addTearDown(() async {
      scenario.store.release();

      await tester.pumpWidget(const SizedBox.shrink());

      await scenario.dispose();
    });

    await tester.pumpWidget(scenario.buildApplication());

    await tester.pump();

    expect(find.byKey(const Key('b5-locked')), findsOneWidget);

    expect(scenario.mountedIdentities, isEmpty);

    return scenario;
  }

  group('AUTH-03 - Revocacion y operaciones asincronas', () {
    testWidgets('B5.1 - una escritura pendiente de B '
        'no vuelve a montar B despues de seleccionar A', (tester) async {
      final scenario = await mount(tester, blockWrites: true);

      scenario.accountB.changeTo('uid-b');

      await scenario.store.writeStarted.future;

      expect(await scenario.authorizeB('uid-b'), isTrue);

      await tester.pump();

      // B todavia no tiene su vigencia persistida.
      expect(scenario.store.current, isNull);

      expect(scenario.mountedIdentities, isEmpty);

      // Seleccionar A revoca el permiso anterior.
      expect(await scenario.authorizeA(), isTrue);

      await tester.pump();

      expect(find.text('PRIVADO primary:uid-a'), findsOneWidget);

      expect(scenario.mountedIdentities, contains('primary:uid-a'));

      // Ahora termina la escritura antigua de B.
      scenario.store.release();

      await tester.pump();
      await tester.pump();

      // La finalizacion tardia no selecciona B.
      expect(scenario.selection.selectedSlot, FirebaseAccountSlot.primary);

      expect(scenario.selection.selectedUserId, 'uid-a');

      expect(find.text('PRIVADO primary:uid-a'), findsOneWidget);

      expect(find.text('PRIVADO secondary:uid-b'), findsNothing);

      expect(scenario.mountedIdentities, isNot(contains('secondary:uid-b')));

      expect(scenario.accountA.signOutCalls, 0);
      expect(scenario.accountB.signOutCalls, 0);
    });

    testWidgets('B5.2 - bloquear B durante una escritura '
        'impide recuperar su acceso al completarla', (tester) async {
      final scenario = await mount(tester, blockWrites: true);

      scenario.accountB.changeTo('uid-b');

      await scenario.store.writeStarted.future;

      expect(await scenario.authorizeB('uid-b'), isTrue);

      await tester.pump();

      expect(find.byKey(const Key('b5-private-panel')), findsNothing);

      scenario.selection.lock();

      await tester.pump();

      expect(scenario.selection.value, isFalse);

      scenario.store.release();

      await tester.pump();
      await tester.pump();

      // La persistencia no es una autorizacion privada.
      expect(scenario.selection.value, isFalse);

      expect(scenario.selection.selectedSlot, isNull);

      expect(find.byKey(const Key('b5-private-panel')), findsNothing);

      expect(find.byKey(const Key('b5-locked')), findsOneWidget);

      expect(scenario.mountedIdentities, isEmpty);

      // Las sesiones Firebase permanecen independientes.
      expect(scenario.accountA.currentUserId, 'uid-a');
      expect(scenario.accountB.currentUserId, 'uid-b');

      expect(scenario.accountA.signOutCalls, 0);
      expect(scenario.accountB.signOutCalls, 0);
    });

    testWidgets('B5.3 - una escritura antigua de B '
        'no concede acceso privado a C', (tester) async {
      final scenario = await mount(tester, blockWrites: true);

      scenario.accountB.changeTo('uid-b');

      await scenario.store.writeStarted.future;

      expect(await scenario.authorizeB('uid-b'), isTrue);

      await tester.pump();

      expect(scenario.mountedIdentities, isEmpty);

      // La misma instancia convencional cambia
      // de UID antes de terminar la escritura.
      scenario.accountB.changeTo('uid-c');

      expect(scenario.selection.value, isFalse);

      expect(scenario.selection.selectedSlot, isNull);

      expect(await scenario.authorizeB('uid-c'), isTrue);

      await tester.pump();

      // C tiene Firebase validado conceptualmente,
      // pero todavia no ha persistido su nueva vigencia.
      expect(find.byKey(const Key('b5-private-panel')), findsNothing);

      scenario.store.release();

      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(scenario.store.current?.userId, 'uid-c');

      expect(scenario.selection.selectedSlot, FirebaseAccountSlot.secondary);

      expect(scenario.selection.selectedUserId, 'uid-c');

      expect(find.text('PRIVADO secondary:uid-c'), findsOneWidget);

      expect(find.text('PRIVADO secondary:uid-b'), findsNothing);

      expect(scenario.mountedIdentities, contains('secondary:uid-c'));

      expect(scenario.mountedIdentities, isNot(contains('secondary:uid-b')));

      expect(scenario.accountA.currentUserId, 'uid-a');
      expect(scenario.accountA.signOutCalls, 0);
    });

    testWidgets('B5.4 - una verificacion tardia de B '
        'no reemplaza la autorizacion posterior de A', (tester) async {
      final scenario = await mount(tester);

      scenario.accountB.changeTo('uid-b');

      await tester.pump();
      await tester.pump();

      final pendingVerification = Completer<bool>();

      // La autorizacion para B permanece pendiente.
      final oldAuthorization = scenario.selection.select(
        slot: FirebaseAccountSlot.secondary,
        expectedUserId: 'uid-b',
        verifyAccess: () => pendingVerification.future,
      );

      await tester.pump();

      expect(scenario.selection.value, isFalse);

      expect(find.byKey(const Key('b5-private-panel')), findsNothing);

      // Se revoca la solicitud anterior y A
      // obtiene una autorizacion posterior.
      scenario.selection.lock();

      expect(await scenario.authorizeA(), isTrue);

      await tester.pump();

      expect(find.text('PRIVADO primary:uid-a'), findsOneWidget);

      // Firebase responde tarde a la solicitud de B.
      pendingVerification.complete(true);

      expect(await oldAuthorization, isFalse);

      await tester.pump();

      expect(scenario.selection.selectedSlot, FirebaseAccountSlot.primary);

      expect(scenario.selection.selectedUserId, 'uid-a');

      expect(find.text('PRIVADO primary:uid-a'), findsOneWidget);

      expect(find.text('PRIVADO secondary:uid-b'), findsNothing);

      expect(scenario.mountedIdentities, isNot(contains('secondary:uid-b')));

      expect(scenario.accountA.signOutCalls, 0);
      expect(scenario.accountB.signOutCalls, 0);
    });
  });
}
