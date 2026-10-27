import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';
import 'package:sendaris/app/session/linked_account_session_lifecycle_controller.dart';
import 'package:sendaris/app/session/session_timeout_policy.dart';

final class _FakeIdentity implements AccountIdentitySource {
  _FakeIdentity(this._userId);

  String? _userId;

  final _changes = StreamController<String?>.broadcast(sync: true);

  @override
  String? get currentUserId => _userId;

  @override
  Stream<String?> get userIdChanges => _changes.stream;

  void changeTo(String? userId) {
    _userId = userId;
    _changes.add(userId);
  }

  Future<void> dispose() => _changes.close();
}

void main() {
  late _FakeIdentity accountA;
  late _FakeIdentity accountB;

  late AccountSessionSelectionController selection;
  late LinkedAccountSessionLifecycleController lifecycle;

  late DateTime start;
  late DateTime now;

  late int expirations;

  setUp(() {
    start = DateTime.utc(2026, 10, 21, 12);
    now = start;

    expirations = 0;

    accountA = _FakeIdentity('uid-a');
    accountB = _FakeIdentity(null);

    selection = AccountSessionSelectionController(
      primary: accountA,
      secondary: accountB,
    );

    lifecycle = LinkedAccountSessionLifecycleController(
      selection: selection,
      linkedSlot: FirebaseAccountSlot.primary,
      clock: () => now,
      onExpired: () {
        expirations++;
      },
    );
  });

  tearDown(() async {
    lifecycle.dispose();
    selection.dispose();

    await accountA.dispose();
    await accountB.dispose();
  });

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

  group('AUTH-03 B8.9B - Ciclo de vida de A', () {
    test('no autoriza A antes de seleccionar su cuenta', () {
      expect(selection.value, isFalse);
      expect(lifecycle.hasValidLinkedAccess, isFalse);
      expect(lifecycle.record, isNull);
      expect(expirations, 0);
    });

    test('inicia la vigencia despues de autorizar A', () async {
      expect(await selectA(), isTrue);

      expect(lifecycle.hasValidLinkedAccess, isTrue);
      expect(lifecycle.record?.userId, 'uid-a');
      expect(lifecycle.record?.startedAt, start);
      expect(expirations, 0);
    });

    test('minimizar y regresar no exige huella si A sigue vigente', () async {
      expect(await selectA(), isTrue);

      now = start.add(const Duration(minutes: 5));
      lifecycle.enterBackground();

      expect(lifecycle.isBackgrounded, isTrue);
      expect(lifecycle.hasValidLinkedAccess, isTrue);

      now = start.add(const Duration(minutes: 10));
      lifecycle.resume();

      expect(selection.value, isTrue);
      expect(selection.selectedSlot, FirebaseAccountSlot.primary);
      expect(lifecycle.hasValidLinkedAccess, isTrue);
      expect(lifecycle.isBackgrounded, isFalse);
      expect(lifecycle.record?.lastActivityAt, now);
      expect(expirations, 0);
    });

    test('superar el limite en segundo plano bloquea A', () async {
      expect(await selectA(), isTrue);

      now = start.add(const Duration(minutes: 5));
      lifecycle.enterBackground();

      now = now.add(SessionTimeoutPolicy.background);
      lifecycle.resume();

      expect(selection.value, isFalse);
      expect(lifecycle.hasValidLinkedAccess, isFalse);
      expect(lifecycle.record, isNull);
      expect(expirations, 1);

      // No hubo cierre de Firebase.
      expect(accountA.currentUserId, 'uid-a');
    });

    test('superar el limite de inactividad bloquea A', () async {
      expect(await selectA(), isTrue);

      now = start.add(SessionTimeoutPolicy.foregroundIdle);

      lifecycle.checkCurrentValidity();

      expect(selection.value, isFalse);
      expect(lifecycle.record, isNull);
      expect(expirations, 1);
      expect(accountA.currentUserId, 'uid-a');
    });

    test('la actividad de A renueva su inactividad', () async {
      expect(await selectA(), isTrue);

      now = start.add(
        SessionTimeoutPolicy.foregroundIdle - const Duration(minutes: 1),
      );

      lifecycle.registerActivity();

      expect(lifecycle.hasValidLinkedAccess, isTrue);
      expect(lifecycle.record?.lastActivityAt, now);
      expect(lifecycle.record?.startedAt, start);
      expect(expirations, 0);
    });

    test('cerrar sesion termina A inmediatamente', () async {
      expect(await selectA(), isTrue);

      lifecycle.closeLinkedAccess();

      expect(selection.value, isFalse);
      expect(lifecycle.record, isNull);
      expect(lifecycle.hasValidLinkedAccess, isFalse);

      // La vinculacion y Firebase son externas
      // al controlador y no se modifican.
      expect(accountA.currentUserId, 'uid-a');
      expect(expirations, 0);
    });

    test('seleccionar B no conserva la autorizacion privada de A', () async {
      expect(await selectA(), isTrue);

      // Simula el cierre de acceso privado de A.
      selection.lock();

      accountB.changeTo('uid-b');

      expect(await selectB(), isTrue);

      expect(lifecycle.record, isNull);
      expect(lifecycle.hasValidLinkedAccess, isFalse);
      expect(expirations, 0);

      now = start.add(const Duration(minutes: 20));
      lifecycle.registerActivity();

      expect(lifecycle.record, isNull);

      // B conserva su propia seleccion.
      expect(selection.value, isTrue);
      expect(selection.selectedSlot, FirebaseAccountSlot.secondary);
      expect(selection.selectedUserId, 'uid-b');

      // La sesion Firebase A permanece intacta.
      expect(accountA.currentUserId, 'uid-a');
    });

    test('cambiar el UID de A revoca su acceso', () async {
      expect(await selectA(), isTrue);

      accountA.changeTo('uid-c');

      expect(selection.value, isFalse);
      expect(lifecycle.record, isNull);
      expect(lifecycle.hasValidLinkedAccess, isFalse);
    });

    test('una nueva autorizacion de A inicia otro periodo', () async {
      expect(await selectA(), isTrue);

      lifecycle.closeLinkedAccess();

      now = start.add(const Duration(minutes: 30));

      expect(await selectA(), isTrue);

      expect(lifecycle.record?.startedAt, now);
      expect(lifecycle.record?.lastActivityAt, now);
      expect(expirations, 0);
    });

    test('desactivar la vinculacion elimina solo su vigencia', () async {
      expect(await selectA(), isTrue);

      lifecycle.configureLinkedSlot(null);

      expect(lifecycle.record, isNull);
      expect(lifecycle.hasValidLinkedAccess, isFalse);
      expect(expirations, 0);

      // El controlador no termina la sesion Firebase
      // ni modifica por si solo el permiso convencional.
      expect(accountA.currentUserId, 'uid-a');
    });
  });
}
