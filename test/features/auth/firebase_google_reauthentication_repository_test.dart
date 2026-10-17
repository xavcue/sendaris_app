import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:sendaris/features/auth/data/services/firebase_auth_service.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/exceptions/google_identity_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/google_identity_token_provider.dart';

void main() {
  late _FakeGoogleAccountService service;
  late FirebaseAuthRepository repository;

  setUp(() {
    service = _FakeGoogleAccountService();
    repository = FirebaseAuthRepository(service);
  });

  test('detecta el proveedor Google en la cuenta actual', () {
    expect(repository.canReauthenticateWithGoogle, isTrue);
  });

  test('rechaza Google si la cuenta solo utiliza contraseña', () {
    service.googleEnabled = false;

    expect(repository.canReauthenticateWithGoogle, isFalse);
  });

  test('no ofrece reautenticación Google sin sesión', () {
    service.hasUser = false;

    expect(repository.canReauthenticateWithGoogle, isFalse);
  });

  test('confirma correctamente la identidad mediante Google', () async {
    service.result = true;

    final result = await repository.reauthenticateWithGoogle();

    expect(result, isTrue);
    expect(service.reauthenticationCalls, 1);
  });

  test('la cancelación devuelve false sin lanzar error', () async {
    service.result = false;

    final result = await repository.reauthenticateWithGoogle();

    expect(result, isFalse);
    expect(service.reauthenticationCalls, 1);
  });

  test('convierte el error de identidad en AuthFailure', () async {
    service.failure = const GoogleIdentityFailure(
      'No fue posible comprobar tu cuenta de Google.',
    );

    await expectLater(
      repository.reauthenticateWithGoogle(),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'mensaje',
          'No fue posible comprobar tu cuenta de Google.',
        ),
      ),
    );
  });

  test('rechaza credenciales de otra cuenta Google', () async {
    service.failure = FirebaseAuthException(
      code: 'user-mismatch',
      message: 'Error técnico interno',
    );

    await expectLater(
      repository.reauthenticateWithGoogle(),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'mensaje',
          allOf(
            contains('no coincide'),
            isNot(contains('Error técnico interno')),
          ),
        ),
      ),
    );
  });

  test('controla fallos de red sin revelar detalles', () async {
    service.failure = FirebaseAuthException(
      code: 'network-request-failed',
      message: 'Información técnica privada',
    );

    await expectLater(
      repository.reauthenticateWithGoogle(),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'mensaje',
          allOf(
            contains('conexión'),
            isNot(contains('Información técnica privada')),
          ),
        ),
      ),
    );
  });

  test('controla límites de solicitudes', () async {
    service.failure = FirebaseAuthException(code: 'too-many-requests');

    await expectLater(
      repository.reauthenticateWithGoogle(),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'mensaje',
          contains('Demasiados intentos'),
        ),
      ),
    );
  });

  test('solicita nueva sesión ante una cuenta inválida', () async {
    service.failure = FirebaseAuthException(code: 'user-disabled');

    await expectLater(
      repository.reauthenticateWithGoogle(),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'mensaje',
          contains('iniciar sesión nuevamente'),
        ),
      ),
    );
  });

  test('controla cambios inesperados de sesión', () async {
    service.failure = StateError('La identidad cambió durante la operación');

    await expectLater(
      repository.reauthenticateWithGoogle(),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'mensaje',
          allOf(
            contains('iniciar sesión nuevamente'),
            isNot(contains('La identidad cambió')),
          ),
        ),
      ),
    );
  });

  test('no expone fallos inesperados', () async {
    service.failure = Exception('Detalle interno confidencial');

    await expectLater(
      repository.reauthenticateWithGoogle(),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'mensaje',
          allOf(
            contains('Inténtalo nuevamente'),
            isNot(contains('confidencial')),
          ),
        ),
      ),
    );
  });
}

/// Simula únicamente las operaciones requeridas por el
/// repositorio sin ejecutar Firebase ni el SDK de Google.
class _FakeGoogleAccountService extends FirebaseAuthService {
  _FakeGoogleAccountService()
    : super(
        _UnusedFirebaseAuth(),
        googleIdentityTokenProvider: _UnusedGoogleTokenProvider(),
      );

  bool hasUser = true;
  bool googleEnabled = true;

  bool result = true;
  Object? failure;

  int reauthenticationCalls = 0;

  @override
  User? get currentUser {
    if (!hasUser) {
      return null;
    }

    return _FakeUser(googleEnabled: googleEnabled);
  }

  @override
  Future<bool> reauthenticateCurrentUserWithGoogle() async {
    reauthenticationCalls++;

    final error = failure;

    if (error != null) {
      throw error;
    }

    return result;
  }
}

class _FakeUser implements User {
  _FakeUser({required this.googleEnabled});

  final bool googleEnabled;

  @override
  String get uid => 'uid-prueba';

  @override
  List<UserInfo> get providerData {
    return [_FakeUserInfo(googleEnabled ? 'google.com' : 'password')];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _FakeUserInfo implements UserInfo {
  _FakeUserInfo(this.providerId);

  @override
  final String providerId;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _UnusedFirebaseAuth implements FirebaseAuth {
  @override
  dynamic noSuchMethod(Invocation invocation) {
    return super.noSuchMethod(invocation);
  }
}

class _UnusedGoogleTokenProvider implements GoogleIdentityTokenProvider {
  @override
  Future<String?> requestIdToken() {
    throw UnimplementedError(
      'El SDK de Google no debe ejecutarse en esta prueba.',
    );
  }
}
