import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/auth/data/repositories/firebase_auth_repository.dart';
import 'package:sendaris/features/auth/data/services/firebase_auth_service.dart';
import 'package:sendaris/features/auth/domain/exceptions/auth_failure.dart';
import 'package:sendaris/features/auth/domain/exceptions/google_identity_failure.dart';
import 'package:sendaris/features/auth/domain/repositories/google_identity_token_provider.dart';

void main() {
  late _FakeGoogleFirebaseAuthService service;
  late FirebaseAuthRepository repository;

  setUp(() {
    service = _FakeGoogleFirebaseAuthService();
    repository = FirebaseAuthRepository(service);
  });

  test('devuelve el UID obtenido mediante Google', () async {
    service.resultUserId = 'uid-google-123';

    var started = false;

    final result = await repository.signInWithGoogleObserved(
      onExecutionStarted: () {
        started = true;
      },
    );

    expect(started, isTrue);
    expect(result, 'uid-google-123');
    expect(service.calls, 1);
  });

  test('devuelve null cuando se cancela Google', () async {
    service.resultUserId = null;

    final result = await repository.signInWithGoogleObserved(
      onExecutionStarted: () {},
    );

    expect(result, isNull);
    expect(service.calls, 1);
  });

  test('convierte errores de identidad en errores controlados', () async {
    service.failure = const GoogleIdentityFailure(
      'No se pudo completar el acceso con Google.',
    );

    await expectLater(
      repository.signInWithGoogleObserved(onExecutionStarted: () {}),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'mensaje',
          'No se pudo completar el acceso con Google.',
        ),
      ),
    );
  });

  test('controla errores de red de Firebase', () async {
    service.failure = FirebaseAuthException(
      code: 'network-request-failed',
      message: 'Información técnica interna',
    );

    await expectLater(
      repository.signInWithGoogleObserved(onExecutionStarted: () {}),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'mensaje',
          allOf(
            contains('conexión'),
            isNot(contains('Información técnica interna')),
          ),
        ),
      ),
    );
  });

  test('controla límites de solicitudes', () async {
    service.failure = FirebaseAuthException(code: 'too-many-requests');

    await expectLater(
      repository.signInWithGoogleObserved(onExecutionStarted: () {}),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'mensaje',
          contains('Demasiados intentos'),
        ),
      ),
    );
  });

  test('no expone correos ante conflictos de proveedores', () async {
    service.failure = FirebaseAuthException(
      code: 'account-exists-with-different-credential',
      message: 'usuario-privado@example.com',
    );

    await expectLater(
      repository.signInWithGoogleObserved(onExecutionStarted: () {}),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'mensaje',
          allOf(
            contains('acceso con Google'),
            isNot(contains('usuario-privado@example.com')),
          ),
        ),
      ),
    );
  });

  test('no divulga errores inesperados', () async {
    service.failure = StateError('Detalle interno que no debe mostrarse');

    await expectLater(
      repository.signInWithGoogleObserved(onExecutionStarted: () {}),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.message,
          'mensaje',
          allOf(
            contains('Inténtalo nuevamente'),
            isNot(contains('Detalle interno')),
          ),
        ),
      ),
    );
  });
}

/// Permite probar el contrato de repositorio sin llamar a
/// Firebase Authentication ni al SDK nativo de Google.
class _FakeGoogleFirebaseAuthService extends FirebaseAuthService {
  _FakeGoogleFirebaseAuthService()
    : super(
        _UnusedFirebaseAuth(),
        googleIdentityTokenProvider: _UnusedGoogleTokenProvider(),
      );

  String? resultUserId;
  Object? failure;
  int calls = 0;

  @override
  Future<String?> signInWithGoogleObserved({
    required void Function() onExecutionStarted,
  }) async {
    calls++;

    onExecutionStarted();

    final error = failure;

    if (error != null) {
      throw error;
    }

    return resultUserId;
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
      'El proveedor nativo no debe ejecutarse en esta prueba.',
    );
  }
}
