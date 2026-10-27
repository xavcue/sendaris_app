import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_biometric_access_coordinator.dart';
import 'package:sendaris/app/session/account_conventional_access_coordinator.dart';
import 'package:sendaris/app/session/account_private_content_host.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/session_timeout_guard.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';
import 'package:sendaris/app/session/session_timeout_store.dart';
import 'package:sendaris/features/auth/domain/repositories/auth_repository.dart';

/// Simula una sesion independiente sin utilizar Firebase real.
final class _TestAccountRepository
    implements AuthRepository, AuthIdentityRepository, AccountIdentitySource {
  _TestAccountRepository(this._userId);

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
    throw UnsupportedError('Esta prueba no inicia sesiones Firebase reales.');
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

/// Verifica una identidad mediante una respuesta controlada.
///
/// Permite detener el proceso antes de que el coordinador
/// convencional conceda autorizacion privada.
final class _TestSessionVerifier implements AccountFirebaseSessionVerifier {
  _TestSessionVerifier(this.repository);

  final _TestAccountRepository repository;

  Future<bool> Function()? validation;

  int validationCalls = 0;

  @override
  String? get currentUserId => repository.currentUserId;

  @override
  Future<bool> validate({required String expectedUserId}) async {
    validationCalls++;

    final result = validation == null ? true : await validation!();

    return result && repository.currentUserId == expectedUserId;
  }
}

/// Simula una persistencia de timeout que puede permanecer
/// pendiente mientras Firebase termina la autenticacion.
final class _ControlledTimeoutStore implements SessionTimeoutStore {
  SessionTimeoutRecord? current;

  Completer<void>? writeGate;

  final writeStarted = Completer<void>();

  int writeCalls = 0;

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
    current = null;
  }

  void release() {
    final gate = writeGate;

    if (gate != null && !gate.isCompleted) {
      gate.complete();
    }

    writeGate = null;
  }
}

/// Reproduce la composicion funcional del acceso dual.
///
/// A: contexto biometrico reservado.
/// B: contexto convencional sometido al timeout.
///
/// El contenido privado es un marcador de prueba,
/// por lo que no se realizan consultas a Firestore.
final class _DualAuthorizationScenario {
  _DualAuthorizationScenario({bool blockWrites = false}) {
    selection = AccountSessionSelectionController(
      primary: accountA,
      secondary: accountB,
    );

    primaryVerifier = _TestSessionVerifier(accountA);
    secondaryVerifier = _TestSessionVerifier(accountB);

    conventional = AccountConventionalAccessCoordinator(
      selection: selection,
      primarySession: primaryVerifier,
      secondarySession: secondaryVerifier,
      linkedSlot: FirebaseAccountSlot.primary,
    );

    if (blockWrites) {
      store.writeGate = Completer<void>();
    }
  }

  final accountA = _TestAccountRepository('uid-a');

  final accountB = _TestAccountRepository(null);

  final store = _ControlledTimeoutStore();

  late final AccountSessionSelectionController selection;

  late final _TestSessionVerifier primaryVerifier;
  late final _TestSessionVerifier secondaryVerifier;

  late final AccountConventionalAccessCoordinator conventional;

  final DateTime now = DateTime.utc(2026, 10, 21, 15);

  int privateBuilds = 0;

  Future<bool> signInB() {
    return conventional.signIn(
      slot: FirebaseAccountSlot.secondary,
      authenticate: () async {
        accountB.changeTo('uid-b');
        return true;
      },
    );
  }

  Future<bool> authorizeAForTest() {
    // Simula una autorizacion ya verificada.
    // La comprobacion criptografica real pertenece
    // a AccountBiometricAccessCoordinator.
    return selection.select(
      slot: FirebaseAccountSlot.primary,
      expectedUserId: 'uid-a',
      verifyAccess: () async => true,
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
            lockedBuilder: (_) {
              return const Center(
                child: Text(
                  'ACCESO PRIVADO BLOQUEADO',
                  key: Key('authorization-locked'),
                ),
              );
            },
            privateBuilder: (context, slot, userId) {
              privateBuilds++;

              return Center(
                child: Text(
                  'PRIVADO ${slot.name} $userId',
                  key: const Key('authorization-private-content'),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> dispose() async {
    store.release();

    conventional.dispose();
    selection.dispose();

    await accountA.dispose();
    await accountB.dispose();
  }
}

void main() {
  Future<_DualAuthorizationScenario> mount(
    WidgetTester tester, {
    bool blockWrites = false,
  }) async {
    final scenario = _DualAuthorizationScenario(blockWrites: blockWrites);

    addTearDown(() async {
      scenario.store.release();

      await tester.pumpWidget(const SizedBox.shrink());
      await scenario.dispose();
    });

    await tester.pumpWidget(scenario.buildApplication());

    await tester.pump();

    expect(find.byKey(const Key('authorization-locked')), findsOneWidget);

    expect(scenario.privateBuilds, 0);

    return scenario;
  }

  group('AUTH-03 - Autorizacion privada y timeout', () {
    testWidgets('B4.1 - una validacion Firebase pendiente '
        'no monta contenido privado de B', (tester) async {
      final scenario = await mount(tester, blockWrites: true);

      final validation = Completer<bool>();

      scenario.secondaryVerifier.validation = () => validation.future;

      final pendingLogin = scenario.signInB();

      // Firebase ha informado el UID, pero el
      // coordinador todavia espera su validacion.
      await scenario.store.writeStarted.future;

      await tester.pump();

      expect(scenario.accountB.currentUserId, 'uid-b');

      expect(scenario.selection.value, isFalse);

      expect(scenario.privateBuilds, 0);

      expect(
        find.byKey(const Key('authorization-private-content')),
        findsNothing,
      );

      // Cancelar la operacion no puede conceder
      // posteriormente el acceso privado.
      scenario.conventional.cancelAndLock();

      validation.complete(true);

      expect(await pendingLogin, isFalse);

      await tester.pump();

      expect(scenario.selection.value, isFalse);
      expect(scenario.privateBuilds, 0);
    });

    testWidgets('B4.2 - B no debe montar contenido privado '
        'antes de persistir su vigencia temporal', (tester) async {
      final scenario = await mount(tester, blockWrites: true);

      final pendingLogin = scenario.signInB();

      // El guard ya esta intentando registrar
      // la nueva sesion, pero la escritura
      // permanece bloqueada.
      await scenario.store.writeStarted.future;

      expect(scenario.store.current, isNull);

      // La validacion Firebase convencional
      // puede finalizar antes de la persistencia.
      expect(await pendingLogin, isTrue);

      await tester.pump();

      expect(scenario.selection.value, isTrue);

      expect(scenario.selection.selectedSlot, FirebaseAccountSlot.secondary);

      expect(scenario.selection.selectedUserId, 'uid-b');

      expect(
        find.byKey(const Key('session-timeout-protection')),
        findsOneWidget,
      );

      // Requisito de seguridad:
      //
      // Una pantalla protectora visible no equivale
      // a impedir que el arbol privado se construya.
      //
      // El contenido privado no debe montarse
      // hasta confirmar la vigencia de B.
      expect(
        scenario.privateBuilds,
        0,
        reason:
            'La persistencia del timeout de B sigue '
            'pendiente. No debe construirse '
            'contenido privado bajo la proteccion.',
      );

      expect(
        find.byKey(const Key('authorization-private-content')),
        findsNothing,
      );

      scenario.store.release();

      await tester.pump();
      await tester.pump();

      expect(scenario.store.current?.userId, 'uid-b');
    });

    testWidgets('B4.3 - B puede acceder despues de '
        'confirmar su autenticacion y vigencia', (tester) async {
      final scenario = await mount(tester);

      expect(await scenario.signInB(), isTrue);

      await tester.pump();
      await tester.pump();

      expect(scenario.store.current, isNotNull);

      expect(scenario.store.current?.userId, 'uid-b');

      expect(scenario.selection.value, isTrue);

      expect(scenario.selection.selectedSlot, FirebaseAccountSlot.secondary);

      expect(find.byKey(const Key('session-timeout-protection')), findsNothing);

      expect(find.text('PRIVADO secondary uid-b'), findsOneWidget);

      expect(scenario.privateBuilds, greaterThan(0));

      expect(scenario.accountA.currentUserId, 'uid-a');

      expect(scenario.accountA.signOutCalls, 0);
      expect(scenario.accountB.signOutCalls, 0);
    });

    testWidgets('B4.4 - bloquear A exige una nueva '
        'autorizacion aun con Firebase activo', (tester) async {
      final scenario = await mount(tester);

      expect(await scenario.authorizeAForTest(), isTrue);

      await tester.pump();

      expect(find.text('PRIVADO primary uid-a'), findsOneWidget);

      scenario.selection.lock();

      await tester.pump();

      expect(scenario.selection.value, isFalse);

      expect(
        find.byKey(const Key('authorization-private-content')),
        findsNothing,
      );

      expect(find.byKey(const Key('authorization-locked')), findsOneWidget);

      // Recibir nuevamente el mismo UID de Firebase
      // no es una autorizacion biometrica.
      scenario.accountA.changeTo('uid-a');

      await tester.pump();

      expect(scenario.selection.value, isFalse);

      expect(
        find.byKey(const Key('authorization-private-content')),
        findsNothing,
      );

      expect(scenario.accountA.currentUserId, 'uid-a');

      expect(scenario.accountA.signOutCalls, 0);

      // Una nueva autorizacion explicita permite
      // montar nuevamente el contenido privado.
      // En produccion este paso exige Android Keystore.
      expect(await scenario.authorizeAForTest(), isTrue);

      await tester.pump();

      expect(find.text('PRIVADO primary uid-a'), findsOneWidget);
    });
  });
}
