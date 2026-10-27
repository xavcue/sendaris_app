import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sendaris/app/session/biometric_binding_policy.dart';
import 'package:sendaris/app/session/biometric_vault_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.xavcue.sendaris/test_biometric_vault');

  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late AndroidBiometricVaultGateway gateway;

  setUp(() {
    gateway = AndroidBiometricVaultGateway(channel: channel);
  });

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  void respondWith(Object? response) {
    messenger.setMockMethodCallHandler(channel, (_) async => response);
  }

  group('Contrato del almacén biométrico', () {
    test('estado disabled se interpreta explícitamente', () async {
      respondWith(<String, Object?>{'status': 'disabled'});

      final result = await gateway.readBinding();

      expect(result, isA<BiometricBindingDisabled>());
    });

    test('estado enabled conserva el UID informado', () async {
      respondWith(<String, Object?>{'status': 'enabled', 'uid': 'uid-a'});

      final result = await gateway.readBinding();

      expect(result, isA<BiometricBindingEnabled>());
      expect((result as BiometricBindingEnabled).userId, 'uid-a');
    });

    test('UID inválido produce estado no disponible', () async {
      respondWith(<String, Object?>{'status': 'enabled', 'uid': ' uid-a'});

      final result = await gateway.readBinding();

      expect(result, isA<BiometricBindingUnavailable>());
    });

    test('respuesta desconocida no desactiva la seguridad', () async {
      respondWith(<String, Object?>{'status': 'unexpected'});

      final result = await gateway.readBinding();

      expect(result, isA<BiometricBindingUnavailable>());
    });

    test('módulo nativo ausente produce estado no disponible', () async {
      // Sin handler, MethodChannel devuelve MissingPluginException.
      final result = await gateway.readBinding();

      expect(result, isA<BiometricBindingUnavailable>());
    });

    test('error nativo al leer produce estado no disponible', () async {
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'storage_error');
      });

      final result = await gateway.readBinding();

      expect(result, isA<BiometricBindingUnavailable>());
    });

    test('enroll transmite el UID correcto', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'enroll');
        expect(call.arguments, <String, String>{'uid': 'uid-a'});

        return <String, Object?>{'status': 'verified', 'uid': 'uid-a'};
      });

      final result = await gateway.enroll(userId: 'uid-a');

      expect(result, BiometricVaultOutcome.verified);
    });

    test('enroll rechaza un UID vacío antes de llamar a Android', () async {
      final result = await gateway.enroll(userId: '');

      expect(result, BiometricVaultOutcome.denied);
    });

    test('cancelación de enroll no autoriza', () async {
      respondWith(<String, Object?>{'status': 'cancelled'});

      final result = await gateway.enroll(userId: 'uid-a');

      expect(result, BiometricVaultOutcome.cancelled);
    });

    test('enroll rechaza una identidad distinta', () async {
      respondWith(<String, Object?>{'status': 'verified', 'uid': 'uid-b'});

      final result = await gateway.enroll(userId: 'uid-a');

      expect(result, BiometricVaultOutcome.denied);
    });

    test('unlock acepta únicamente el UID esperado', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'unlock');
        expect(call.arguments, <String, String>{'uid': 'uid-a'});

        return <String, Object?>{'status': 'verified', 'uid': 'uid-a'};
      });

      final result = await gateway.unlock(expectedUserId: 'uid-a');

      expect(result, BiometricVaultOutcome.verified);
    });

    test('unlock de B no autoriza la vinculación de A', () async {
      respondWith(<String, Object?>{'status': 'verified', 'uid': 'uid-a'});

      final result = await gateway.unlock(expectedUserId: 'uid-b');

      expect(result, BiometricVaultOutcome.denied);
    });

    test('un simple booleano no constituye prueba biométrica', () async {
      respondWith(true);

      final result = await gateway.unlock(expectedUserId: 'uid-a');

      expect(result, BiometricVaultOutcome.denied);
    });

    test('biometría no disponible no concede acceso', () async {
      respondWith(<String, Object?>{'status': 'unavailable'});

      final result = await gateway.unlock(expectedUserId: 'uid-a');

      expect(result, BiometricVaultOutcome.unavailable);
    });

    test('clearBinding rechaza la eliminación aunque '
        'Android pudiera responder disabled', () async {
      var nativeCalls = 0;

      messenger.setMockMethodCallHandler(channel, (call) async {
        nativeCalls++;

        return <String, Object?>{'status': 'disabled'};
      });

      final result = await gateway.clearBinding();

      // La interfaz antigua nunca autoriza
      // una eliminación de la vinculación.
      expect(result, isFalse);

      // Ni siquiera debe enviar una solicitud
      // al canal nativo.
      expect(nativeCalls, 0);
    });

    test('clearBinding permanece bloqueado '
        'aunque el canal nativo falle', () async {
      var nativeCalls = 0;

      messenger.setMockMethodCallHandler(channel, (_) async {
        nativeCalls++;

        throw PlatformException(code: 'storage_error');
      });

      final result = await gateway.clearBinding();

      expect(result, isFalse);

      // No debe intentar comunicarse con Android.
      expect(nativeCalls, 0);
    });
  });
}
