import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/account_session_selection_controller.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';

final class _FakeAccountIdentitySource implements AccountIdentitySource {
  _FakeAccountIdentitySource(this._currentUserId);

  final StreamController<String?> _changes =
      StreamController<String?>.broadcast(sync: true);

  String? _currentUserId;

  @override
  String? get currentUserId => _currentUserId;

  @override
  Stream<String?> get userIdChanges => _changes.stream;

  void changeTo(String? userId) {
    _currentUserId = userId;
    _changes.add(userId);
  }

  void reportError() {
    _changes.addError(StateError('Identity stream failed'));
  }

  Future<void> dispose() => _changes.close();
}

void main() {
  late _FakeAccountIdentitySource primary;
  late _FakeAccountIdentitySource secondary;
  late AccountSessionSelectionController controller;

  setUp(() {
    primary = _FakeAccountIdentitySource('uid-a');
    secondary = _FakeAccountIdentitySource('uid-b');

    controller = AccountSessionSelectionController(
      primary: primary,
      secondary: secondary,
    );
  });

  tearDown(() async {
    controller.dispose();
    await primary.dispose();
    await secondary.dispose();
  });

  Future<bool> allow() async => true;

  group('AccountSessionSelectionController', () {
    test('inicia sin autorización privada', () {
      expect(controller.value, isFalse);
      expect(controller.selectedSlot, isNull);
      expect(controller.selectedUserId, isNull);
      expect(controller.isVerifying, isFalse);
    });

    test('autoriza A solo después de una verificación válida', () async {
      final granted = await controller.select(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
        verifyAccess: allow,
      );

      expect(granted, isTrue);
      expect(controller.value, isTrue);
      expect(controller.selectedSlot, FirebaseAccountSlot.primary);
      expect(controller.selectedUserId, 'uid-a');
    });

    test('autoriza B en su propio contexto', () async {
      final granted = await controller.select(
        slot: FirebaseAccountSlot.secondary,
        expectedUserId: 'uid-b',
        verifyAccess: allow,
      );

      expect(granted, isTrue);
      expect(controller.value, isTrue);
      expect(controller.selectedSlot, FirebaseAccountSlot.secondary);
      expect(controller.selectedUserId, 'uid-b');
    });

    test('rechaza un UID que no pertenece al contexto', () async {
      var verificationCalled = false;

      final granted = await controller.select(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-b',
        verifyAccess: () async {
          verificationCalled = true;
          return true;
        },
      );

      expect(granted, isFalse);
      expect(verificationCalled, isFalse);
      expect(controller.value, isFalse);
    });

    test('rechaza identificadores inválidos', () async {
      for (final userId in ['', ' uid-a', 'uid-a ']) {
        final granted = await controller.select(
          slot: FirebaseAccountSlot.primary,
          expectedUserId: userId,
          verifyAccess: allow,
        );

        expect(granted, isFalse);
      }

      expect(controller.value, isFalse);
    });

    test('rechaza un UID presente en ambas sesiones', () async {
      secondary.changeTo('uid-a');

      final granted = await controller.select(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
        verifyAccess: allow,
      );

      expect(granted, isFalse);
      expect(controller.value, isFalse);
    });

    test('una verificación denegada mantiene el bloqueo', () async {
      final granted = await controller.select(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
        verifyAccess: () async => false,
      );

      expect(granted, isFalse);
      expect(controller.value, isFalse);
      expect(controller.selectedSlot, isNull);
    });

    test('un error de verificación mantiene el bloqueo', () async {
      final granted = await controller.select(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
        verifyAccess: () async {
          throw StateError('Verification unavailable');
        },
      );

      expect(granted, isFalse);
      expect(controller.value, isFalse);
      expect(controller.isVerifying, isFalse);
    });

    test('bloquea A ante una transición A -> B -> A', () async {
      final firstAccess = await controller.select(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
        verifyAccess: allow,
      );

      expect(firstAccess, isTrue);

      primary.changeTo('uid-b');

      expect(controller.value, isFalse);

      primary.changeTo('uid-a');

      expect(controller.value, isFalse);
      expect(controller.selectedSlot, isNull);
    });

    test('rechaza una comprobación pendiente después de A -> B -> A', () async {
      final pending = Completer<bool>();

      final operation = controller.select(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
        verifyAccess: () => pending.future,
      );

      expect(controller.isVerifying, isTrue);
      expect(controller.value, isFalse);

      primary.changeTo('uid-b');
      primary.changeTo('uid-a');

      pending.complete(true);

      expect(await operation, isFalse);
      expect(controller.value, isFalse);
    });

    test('un cambio en B invalida la autorización de A', () async {
      expect(
        await controller.select(
          slot: FirebaseAccountSlot.primary,
          expectedUserId: 'uid-a',
          verifyAccess: allow,
        ),
        isTrue,
      );

      secondary.changeTo('uid-c');

      expect(controller.value, isFalse);
      expect(controller.selectedUserId, isNull);
    });

    test('bloquea mientras comienza el cambio de A a B', () async {
      expect(
        await controller.select(
          slot: FirebaseAccountSlot.primary,
          expectedUserId: 'uid-a',
          verifyAccess: allow,
        ),
        isTrue,
      );

      final pending = Completer<bool>();

      final switching = controller.select(
        slot: FirebaseAccountSlot.secondary,
        expectedUserId: 'uid-b',
        verifyAccess: () => pending.future,
      );

      // A debe perder el acceso antes de esperar
      // la respuesta de la verificación de B.
      expect(controller.value, isFalse);
      expect(controller.selectedSlot, isNull);
      expect(controller.isVerifying, isTrue);

      pending.complete(true);

      expect(await switching, isTrue);
      expect(controller.value, isTrue);
      expect(controller.selectedSlot, FirebaseAccountSlot.secondary);
    });

    test('lock invalida una verificación pendiente', () async {
      final pending = Completer<bool>();

      final operation = controller.select(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
        verifyAccess: () => pending.future,
      );

      controller.lock();

      pending.complete(true);

      expect(await operation, isFalse);
      expect(controller.value, isFalse);
    });

    test('un resultado antiguo no autoriza una operación nueva', () async {
      final oldVerification = Completer<bool>();

      final first = controller.select(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
        verifyAccess: () => oldVerification.future,
      );

      controller.lock();

      final second = await controller.select(
        slot: FirebaseAccountSlot.secondary,
        expectedUserId: 'uid-b',
        verifyAccess: allow,
      );

      expect(second, isTrue);
      expect(controller.selectedSlot, FirebaseAccountSlot.secondary);

      oldVerification.complete(true);

      expect(await first, isFalse);
      expect(controller.selectedSlot, FirebaseAccountSlot.secondary);
    });

    test('los eventos repetidos del mismo UID no revocan', () async {
      expect(
        await controller.select(
          slot: FirebaseAccountSlot.primary,
          expectedUserId: 'uid-a',
          verifyAccess: allow,
        ),
        isTrue,
      );

      primary.changeTo('uid-a');
      secondary.changeTo('uid-b');

      expect(controller.value, isTrue);
    });

    test('un error en el observador revoca el acceso', () async {
      expect(
        await controller.select(
          slot: FirebaseAccountSlot.primary,
          expectedUserId: 'uid-a',
          verifyAccess: allow,
        ),
        isTrue,
      );

      primary.reportError();

      expect(controller.value, isFalse);
      expect(controller.selectedSlot, isNull);
    });

    test('dispose invalida una verificación pendiente', () async {
      final pending = Completer<bool>();

      final operation = controller.select(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
        verifyAccess: () => pending.future,
      );

      controller.dispose();

      pending.complete(true);

      expect(await operation, isFalse);
      expect(controller.value, isFalse);
    });
  });
}
