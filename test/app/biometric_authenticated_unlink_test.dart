import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/session/biometric_vault_gateway.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.xavcue.sendaris/biometric_vault');

  late AndroidBiometricVaultGateway gateway;

  String bindingUid = 'uid-a';
  String bindingStatus = 'enabled';
  String deactivateStatus = 'verified';
  String? responseUid = 'uid-a';

  int deactivateCalls = 0;
  int clearCalls = 0;

  bool updateBindingOnSuccess = true;
  bool failOnRead = false;
  bool throwOnDeactivate = false;

  setUp(() {
    bindingUid = 'uid-a';
    bindingStatus = 'enabled';
    deactivateStatus = 'verified';
    responseUid = 'uid-a';

    deactivateCalls = 0;
    clearCalls = 0;

    updateBindingOnSuccess = true;
    failOnRead = false;
    throwOnDeactivate = false;

    gateway = AndroidBiometricVaultGateway(channel: channel);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          switch (call.method) {
            case 'readBinding':
              if (failOnRead) {
                throw PlatformException(code: 'vault_unavailable');
              }

              if (bindingStatus == 'enabled') {
                return <String, Object?>{
                  'status': 'enabled',
                  'uid': bindingUid,
                };
              }

              return <String, Object?>{'status': bindingStatus};

            case 'deactivate':
              deactivateCalls++;

              if (throwOnDeactivate) {
                throw PlatformException(code: 'biometric_unavailable');
              }

              final arguments = call.arguments;

              if (arguments is! Map || arguments['uid'] != bindingUid) {
                return <String, Object?>{'status': 'denied'};
              }

              if (deactivateStatus == 'verified' && updateBindingOnSuccess) {
                bindingStatus = 'disabled';
              }

              return <String, Object?>{
                'status': deactivateStatus,
                if (deactivateStatus == 'verified') 'uid': responseUid,
              };

            case 'clearBinding':
              clearCalls++;
              return <String, Object?>{'status': 'disabled'};

            default:
              throw MissingPluginException();
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('Desvinculacion biometrica autenticada', () {
    test('solo acepta desactivacion con UID correcto '
        'y estado posterior desactivado', () async {
      final outcome = await gateway.deactivate(expectedUserId: 'uid-a');

      expect(outcome, BiometricVaultOutcome.verified);

      expect(deactivateCalls, 1);
      expect(bindingStatus, 'disabled');
      expect(clearCalls, 0);
    });

    test('rechaza UID perteneciente a otra cuenta', () async {
      final outcome = await gateway.deactivate(expectedUserId: 'uid-b');

      expect(outcome, BiometricVaultOutcome.denied);

      expect(deactivateCalls, 0);
      expect(bindingStatus, 'enabled');
    });

    test('rechaza UID vacio o con espacios', () async {
      for (final uid in <String>['', ' uid-a', 'uid-a ']) {
        final outcome = await gateway.deactivate(expectedUserId: uid);

        expect(outcome, BiometricVaultOutcome.denied);
      }

      expect(deactivateCalls, 0);
    });

    test('no desactiva si no existe vinculacion', () async {
      bindingStatus = 'disabled';

      final outcome = await gateway.deactivate(expectedUserId: 'uid-a');

      expect(outcome, BiometricVaultOutcome.denied);

      expect(deactivateCalls, 0);
    });

    test('un almacenamiento ilegible bloquea '
        'la operacion', () async {
      bindingStatus = 'unavailable';

      final outcome = await gateway.deactivate(expectedUserId: 'uid-a');

      expect(outcome, BiometricVaultOutcome.denied);

      expect(deactivateCalls, 0);
    });

    test('cancelar la huella conserva la vinculacion', () async {
      deactivateStatus = 'cancelled';

      final outcome = await gateway.deactivate(expectedUserId: 'uid-a');

      expect(outcome, BiometricVaultOutcome.cancelled);

      expect(bindingStatus, 'enabled');
      expect(clearCalls, 0);
    });

    test('una huella denegada conserva la vinculacion', () async {
      deactivateStatus = 'denied';

      final outcome = await gateway.deactivate(expectedUserId: 'uid-a');

      expect(outcome, BiometricVaultOutcome.denied);

      expect(bindingStatus, 'enabled');
    });

    test('rechaza una respuesta de otro UID', () async {
      responseUid = 'uid-b';

      final outcome = await gateway.deactivate(expectedUserId: 'uid-a');

      expect(outcome, BiometricVaultOutcome.denied);
    });

    test('un exito del canal no basta si la clave '
        'continua vinculada', () async {
      updateBindingOnSuccess = false;

      final outcome = await gateway.deactivate(expectedUserId: 'uid-a');

      expect(outcome, BiometricVaultOutcome.denied);

      expect(bindingStatus, 'enabled');
    });

    test('rechaza una lectura nativa fallida', () async {
      failOnRead = true;

      final outcome = await gateway.deactivate(expectedUserId: 'uid-a');

      expect(outcome, BiometricVaultOutcome.denied);

      expect(deactivateCalls, 0);
    });

    test('un error nativo no concede desactivacion', () async {
      throwOnDeactivate = true;

      final outcome = await gateway.deactivate(expectedUserId: 'uid-a');

      expect(outcome, BiometricVaultOutcome.unavailable);

      expect(bindingStatus, 'enabled');
    });

    test('la API antigua no intenta borrar la clave', () async {
      final cleared = await gateway.clearBinding();

      expect(cleared, isFalse);
      expect(clearCalls, 0);
      expect(bindingStatus, 'enabled');
    });
  });
}
