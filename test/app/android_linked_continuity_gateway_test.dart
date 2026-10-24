import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/android_linked_continuity_gateway.dart';
import 'package:sendaris/app/session/firebase_account_contexts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.xavcue.sendaris/linked_continuity');

  final startedAt = DateTime.utc(2026, 10, 22, 12);
  final startedAtMs = startedAt.millisecondsSinceEpoch;

  late AndroidLinkedContinuityGateway gateway;
  late List<MethodCall> calls;

  Map<String, Object> response(
    String status, {
    String uid = 'uid-a',
    String slot = 'primary',
    int? startedAtMilliseconds,
  }) {
    return <String, Object>{
      'status': status,
      'uid': uid,
      'slot': slot,
      'startedAtMs': startedAtMilliseconds ?? startedAtMs,
    };
  }

  void mock(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return handler(call);
        });
  }

  Future<bool> verifyA() {
    return gateway.verify(
      slot: FirebaseAccountSlot.primary,
      expectedUserId: 'uid-a',
      sessionStartedAt: startedAt,
    );
  }

  Future<bool> activateAfterUnlockA() {
    return gateway.activateAfterUnlock(
      slot: FirebaseAccountSlot.primary,
      expectedUserId: 'uid-a',
      sessionStartedAt: startedAt,
    );
  }

  setUp(() {
    calls = <MethodCall>[];

    gateway = AndroidLinkedContinuityGateway(channel: channel);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('AUTH-03 B8.10B.10C.2A - Contrato nativo', () {
    test('sin servicio nativo nunca verifica A', () async {
      expect(await verifyA(), isFalse);
    });

    test('acepta solo una respuesta verificada exacta', () async {
      mock((call) async => response('verified'));

      expect(await verifyA(), isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'verify');

      final arguments = calls.single.arguments as Map;

      expect(arguments['uid'], 'uid-a');
      expect(arguments['slot'], 'primary');
      expect(arguments['startedAtMs'], startedAtMs);
    });

    test('una respuesta booleana no autoriza A', () async {
      mock((call) async => true);

      expect(await verifyA(), isFalse);
    });

    test('un estado denied no autoriza A', () async {
      mock((call) async => response('denied'));

      expect(await verifyA(), isFalse);
    });

    test('un UID distinto no autoriza A', () async {
      mock((call) async => response('verified', uid: 'uid-b'));

      expect(await verifyA(), isFalse);
    });

    test('otro contexto Firebase no autoriza A', () async {
      mock((call) async => response('verified', slot: 'secondary'));

      expect(await verifyA(), isFalse);
    });

    test('otra fecha de inicio no autoriza A', () async {
      mock(
        (call) async =>
            response('verified', startedAtMilliseconds: startedAtMs + 1000),
      );

      expect(await verifyA(), isFalse);
    });

    test('un mapa incompleto no autoriza A', () async {
      mock((call) async => <String, Object>{'status': 'verified'});

      expect(await verifyA(), isFalse);
    });

    test('rechaza un UID vacio', () async {
      mock((call) async => response('verified'));

      final accepted = await gateway.verify(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: '',
        sessionStartedAt: startedAt,
      );

      expect(accepted, isFalse);
      expect(calls, isEmpty);
    });

    test('rechaza un UID con espacios exteriores', () async {
      mock((call) async => response('verified'));

      final accepted = await gateway.verify(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: ' uid-a ',
        sessionStartedAt: startedAt,
      );

      expect(accepted, isFalse);
      expect(calls, isEmpty);
    });

    test('rechaza una fecha de inicio invalida', () async {
      mock((call) async => response('verified'));

      final accepted = await gateway.verify(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
        sessionStartedAt: DateTime.utc(1969, 12, 31),
      );

      expect(accepted, isFalse);
      expect(calls, isEmpty);
    });

    test('transmite la fecha normalizada a UTC', () async {
      mock((call) async => response('verified'));

      final localOffset = DateTime.parse('2026-10-22T07:00:00-05:00');

      final accepted = await gateway.verify(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
        sessionStartedAt: localOffset,
      );

      expect(accepted, isTrue);

      final arguments = calls.single.arguments as Map;

      expect(arguments['startedAtMs'], startedAtMs);
    });

    test('un fallo nativo no autoriza A', () async {
      mock((call) async {
        throw PlatformException(
          code: 'UNAVAILABLE',
          message: 'Keystore no disponible',
        );
      });

      expect(await verifyA(), isFalse);
    });

    test('activacion requiere confirmacion exacta', () async {
      mock((call) async => response('activated'));

      final activated = await gateway.activate(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
        sessionStartedAt: startedAt,
      );

      expect(activated, isTrue);
      expect(calls.single.method, 'activate');
    });

    test('activar no equivale a verificar', () async {
      mock((call) async => response('activated'));

      expect(await verifyA(), isFalse);
    });

    test('la revocacion debe confirmarse por Android', () async {
      mock(
        (call) async => <String, Object>{
          'status': 'revoked',
          'slot': 'primary',
          'uid': 'uid-a',
        },
      );

      final revoked = await gateway.revoke(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
      );

      expect(revoked, isTrue);
      expect(calls.single.method, 'revoke');
    });

    test('no acepta revocacion de otro UID', () async {
      mock(
        (call) async => <String, Object>{
          'status': 'revoked',
          'slot': 'primary',
          'uid': 'uid-b',
        },
      );

      final revoked = await gateway.revoke(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
      );

      expect(revoked, isFalse);
    });

    test('un fallo al revocar no se declara exitoso', () async {
      mock((call) async {
        throw PlatformException(code: 'STORAGE_ERROR');
      });

      final revoked = await gateway.revoke(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: 'uid-a',
      );

      expect(revoked, isFalse);
    });
  });

  group('AUTH-03 B8.10B.10C.3D - Activacion tras huella', () {
    test('emite con la confirmacion nativa exacta', () async {
      mock((call) async => response('activated'));

      final accepted = await activateAfterUnlockA();

      expect(accepted, isTrue);
      expect(calls, hasLength(1));
      expect(calls.single.method, 'activateAfterUnlock');

      final arguments = calls.single.arguments as Map;

      expect(arguments['slot'], 'primary');
      expect(arguments['uid'], 'uid-a');
      expect(arguments['startedAtMs'], startedAtMs);
    });

    test('verified no equivale a activated', () async {
      mock((call) async => response('verified'));

      expect(await activateAfterUnlockA(), isFalse);
    });

    test('no acepta otro UID', () async {
      mock((call) async => response('activated', uid: 'uid-b'));

      expect(await activateAfterUnlockA(), isFalse);
    });

    test('no acepta otro contexto', () async {
      mock((call) async => response('activated', slot: 'secondary'));

      expect(await activateAfterUnlockA(), isFalse);
    });

    test('no acepta otro inicio de sesion', () async {
      mock(
        (call) async =>
            response('activated', startedAtMilliseconds: startedAtMs + 1000),
      );

      expect(await activateAfterUnlockA(), isFalse);
    });

    test('rechaza datos locales invalidos', () async {
      mock((call) async => response('activated'));

      final accepted = await gateway.activateAfterUnlock(
        slot: FirebaseAccountSlot.primary,
        expectedUserId: ' uid-a ',
        sessionStartedAt: startedAt,
      );

      expect(accepted, isFalse);
      expect(calls, isEmpty);
    });

    test('sin servicio nativo no emite', () async {
      expect(await activateAfterUnlockA(), isFalse);
    });

    test('un error de Android no confirma emision', () async {
      mock((call) async {
        throw PlatformException(code: 'AUTHORIZATION_EXPIRED');
      });

      expect(await activateAfterUnlockA(), isFalse);
    });
  });
}
