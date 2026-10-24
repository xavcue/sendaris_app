import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/app/bootstrap/sendaris_account_private_host.dart';

void main() {
  bool permits({
    String authorizedUserId = 'uid-a',
    String? contextUserId = 'uid-a',
    String selectedAppName = '[DEFAULT]',
    String authAppName = '[DEFAULT]',
    String firestoreAppName = '[DEFAULT]',
    String otherAppName = 'sendaris_secondary_account',
    String projectId = 'sendaris-project',
    String otherProjectId = 'sendaris-project',
    String firebaseAppId = 'firebase-app-id',
    String otherFirebaseAppId = 'firebase-app-id',
    String apiKey = 'firebase-api-key',
    String otherApiKey = 'firebase-api-key',
  }) {
    return AccountPrivateContextPolicy.permits(
      authorizedUserId: authorizedUserId,
      contextUserId: contextUserId,
      selectedAppName: selectedAppName,
      authAppName: authAppName,
      firestoreAppName: firestoreAppName,
      otherAppName: otherAppName,
      projectId: projectId,
      otherProjectId: otherProjectId,
      firebaseAppId: firebaseAppId,
      otherFirebaseAppId: otherFirebaseAppId,
      apiKey: apiKey,
      otherApiKey: otherApiKey,
    );
  }

  group('AccountPrivateContextPolicy', () {
    test('acepta servicios coherentes de la cuenta A', () {
      expect(permits(), isTrue);
    });

    test('rechaza un UID distinto del autorizado', () {
      expect(
        permits(authorizedUserId: 'uid-a', contextUserId: 'uid-b'),
        isFalse,
      );
    });

    test('rechaza una sesión Firebase ausente', () {
      expect(permits(contextUserId: null), isFalse);
    });

    test('rechaza identificadores de usuario inválidos', () {
      expect(permits(authorizedUserId: ''), isFalse);

      expect(permits(authorizedUserId: ' uid-a '), isFalse);

      expect(permits(contextUserId: 'uid-a '), isFalse);
    });

    test('rechaza Authentication de otra aplicación', () {
      expect(permits(authAppName: 'sendaris_secondary_account'), isFalse);
    });

    test('rechaza Firestore de otra aplicación', () {
      expect(permits(firestoreAppName: 'sendaris_secondary_account'), isFalse);
    });

    test('rechaza dos contextos con el mismo nombre', () {
      expect(permits(otherAppName: '[DEFAULT]'), isFalse);
    });

    test('rechaza configuraciones de proyectos diferentes', () {
      expect(permits(otherProjectId: 'otro-proyecto'), isFalse);
    });

    test('rechaza identificadores Firebase incompatibles', () {
      expect(permits(otherFirebaseAppId: 'otra-app'), isFalse);
    });

    test('rechaza claves de configuración incompatibles', () {
      expect(permits(otherApiKey: 'otra-clave'), isFalse);
    });
  });
}
