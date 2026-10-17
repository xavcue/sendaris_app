import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/exceptions/google_identity_failure.dart';
import '../../domain/repositories/google_identity_token_provider.dart';

/// Contrato interno para aislar el SDK de Google durante las pruebas.
abstract interface class GoogleSignInClient {
  Future<void> initialize();

  bool supportsAuthenticate();

  Future<String?> authenticateAndGetIdToken();
}

/// Obtiene una identidad Google sin modificar Firebase Authentication.
class GoogleIdentityTokenService implements GoogleIdentityTokenProvider {
  GoogleIdentityTokenService({GoogleSignInClient? client})
    : _client = client ?? _SdkGoogleSignInClient();

  final GoogleSignInClient _client;

  @override
  Future<String?> requestIdToken() async {
    try {
      await _client.initialize();

      if (!_client.supportsAuthenticate()) {
        throw const GoogleIdentityFailure(
          'El inicio de sesión con Google no está disponible '
          'en este dispositivo.',
        );
      }

      final idToken = await _client.authenticateAndGetIdToken();

      if (idToken == null || idToken.trim().isEmpty) {
        throw const GoogleIdentityFailure(
          'No fue posible comprobar tu cuenta de Google. '
          'Inténtalo nuevamente.',
        );
      }

      return idToken;
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        return null;
      }

      switch (error.code) {
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          throw const GoogleIdentityFailure(
            'El acceso con Google no está disponible '
            'en este momento. Inténtalo más tarde.',
          );

        case GoogleSignInExceptionCode.interrupted:
        case GoogleSignInExceptionCode.uiUnavailable:
          throw const GoogleIdentityFailure(
            'No se pudo completar el acceso con Google. '
            'Inténtalo nuevamente.',
          );

        default:
          throw const GoogleIdentityFailure(
            'No fue posible iniciar sesión con Google. '
            'Inténtalo nuevamente.',
          );
      }
    } on GoogleIdentityFailure {
      rethrow;
    } catch (_) {
      throw const GoogleIdentityFailure(
        'No fue posible iniciar sesión con Google. '
        'Inténtalo nuevamente.',
      );
    }
  }
}

/// Adaptador concreto del SDK google_sign_in 7.x.
class _SdkGoogleSignInClient implements GoogleSignInClient {
  static final GoogleSignIn _signIn = GoogleSignIn.instance;

  // GoogleSignIn 7.x requiere una única inicialización por proceso.
  static Future<void>? _initialization;

  @override
  Future<void> initialize() {
    return _initialization ??= _signIn.initialize();
  }

  @override
  bool supportsAuthenticate() {
    return _signIn.supportsAuthenticate();
  }

  @override
  Future<String?> authenticateAndGetIdToken() async {
    final account = await _signIn.authenticate();

    return account.authentication.idToken;
  }
}
