import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sendaris/features/auth/data/services/google_identity_token_service.dart';
import 'package:sendaris/features/auth/domain/exceptions/google_identity_failure.dart';

void main() {
  late _FakeGoogleSignInClient client;
  late GoogleIdentityTokenService service;

  setUp(() {
    client = _FakeGoogleSignInClient();
    service = GoogleIdentityTokenService(client: client);
  });

  test('obtiene un token válido después de inicializar', () async {
    client.idToken = 'token-de-prueba';

    final result = await service.requestIdToken();

    expect(result, 'token-de-prueba');
    expect(client.initializeCalls, 1);
    expect(client.authenticateCalls, 1);
  });

  test('la cancelación no produce un error', () async {
    client.authenticationError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.canceled,
    );

    final result = await service.requestIdToken();

    expect(result, isNull);
    expect(client.authenticateCalls, 1);
  });

  test('rechaza un token ausente', () async {
    client.idToken = null;

    await expectLater(
      service.requestIdToken(),
      throwsA(isA<GoogleIdentityFailure>()),
    );
  });

  test('rechaza un token vacío', () async {
    client.idToken = '   ';

    await expectLater(
      service.requestIdToken(),
      throwsA(isA<GoogleIdentityFailure>()),
    );
  });

  test('no autentica cuando la plataforma no lo permite', () async {
    client.authenticationSupported = false;

    await expectLater(
      service.requestIdToken(),
      throwsA(isA<GoogleIdentityFailure>()),
    );

    expect(client.authenticateCalls, 0);
  });

  test('controla errores de configuración del proveedor', () async {
    client.authenticationError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.clientConfigurationError,
      description: 'Error técnico de configuración',
    );

    await expectLater(
      service.requestIdToken(),
      throwsA(
        isA<GoogleIdentityFailure>().having(
          (failure) => failure.message,
          'mensaje',
          isNot(contains('Error técnico')),
        ),
      ),
    );
  });

  test('controla interrupciones de autenticación', () async {
    client.authenticationError = const GoogleSignInException(
      code: GoogleSignInExceptionCode.interrupted,
    );

    await expectLater(
      service.requestIdToken(),
      throwsA(isA<GoogleIdentityFailure>()),
    );
  });

  test('controla errores inesperados sin exponer detalles', () async {
    client.authenticationError = StateError(
      'Información interna que no debe mostrarse',
    );

    await expectLater(
      service.requestIdToken(),
      throwsA(
        isA<GoogleIdentityFailure>().having(
          (failure) => failure.message,
          'mensaje',
          isNot(contains('Información interna')),
        ),
      ),
    );
  });

  test('no abre el selector si falla la inicialización', () async {
    client.initializationError = StateError('Fallo de inicialización');

    await expectLater(
      service.requestIdToken(),
      throwsA(isA<GoogleIdentityFailure>()),
    );

    expect(client.initializeCalls, 1);
    expect(client.authenticateCalls, 0);
  });
}

class _FakeGoogleSignInClient implements GoogleSignInClient {
  String? idToken;

  Object? initializationError;
  Object? authenticationError;

  bool authenticationSupported = true;

  int initializeCalls = 0;
  int authenticateCalls = 0;

  @override
  Future<void> initialize() async {
    initializeCalls++;

    if (initializationError != null) {
      throw initializationError!;
    }
  }

  @override
  bool supportsAuthenticate() {
    return authenticationSupported;
  }

  @override
  Future<String?> authenticateAndGetIdToken() async {
    authenticateCalls++;

    if (authenticationError != null) {
      throw authenticationError!;
    }

    return idToken;
  }
}
