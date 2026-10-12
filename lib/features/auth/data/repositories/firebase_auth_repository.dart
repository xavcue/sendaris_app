import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/exceptions/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/firebase_auth_service.dart';

class FirebaseAuthRepository
    implements
        AuthRepository,
        AuthRegistrationRepository,
        AuthEmailVerificationRepository,
        AuthSessionValidationRepository,
        AuthAccountManagementRepository {
  FirebaseAuthRepository(this._service);

  final FirebaseAuthService _service;

  @override
  bool get isAuthenticated {
    return _service.currentUser != null;
  }

  @override
  String? get currentUserEmail => _service.currentUserEmail;

  @override
  bool get isCurrentUserEmailVerified {
    return _service.isCurrentUserEmailVerified;
  }

  @override
  Stream<bool> get authStateChanges {
    return _service.authStateChanges.map((user) => user != null).distinct();
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _service.signIn(email: email, password: password);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_safeSignInMessage(error.code));
    } catch (_) {
      throw const AuthFailure(
        'No fue posible iniciar sesión. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> createUnverifiedAccount({
    required String email,
    required String password,
  }) async {
    try {
      await _service.createUnverifiedAccount(email: email, password: password);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_safeRegistrationMessage(error.code));
    } catch (_) {
      throw const AuthFailure(
        'No fue posible crear la cuenta. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> sendEmailVerification() async {
    try {
      await _service.sendCurrentUserEmailVerification();
    } on StateError {
      throw const AuthFailure('Debes iniciar sesión para verificar tu correo.');
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_safeEmailVerificationMessage(error.code));
    } catch (_) {
      throw const AuthFailure(
        'No fue posible enviar el correo de verificación. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<bool> refreshEmailVerificationStatus() async {
    try {
      return await _service.refreshCurrentUserEmailVerificationStatus();
    } on StateError {
      throw const AuthFailure('Debes iniciar sesión para verificar tu correo.');
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_safeEmailVerificationRefreshMessage(error.code));
    } catch (_) {
      throw const AuthFailure(
        'No fue posible comprobar la verificación del correo. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _service.signOut();
    } on FirebaseAuthException {
      throw const AuthFailure(
        'No fue posible cerrar la sesión. '
        'Inténtalo nuevamente.',
      );
    } catch (_) {
      throw const AuthFailure(
        'No fue posible cerrar la sesión. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<bool> validateCurrentSession() async {
    if (_service.currentUser == null) {
      return false;
    }

    try {
      await _service.reloadCurrentUser();

      return _service.currentUser != null;
    } on FirebaseAuthException catch (error) {
      if (_invalidSessionCodes.contains(error.code)) {
        try {
          await _service.signOut();
        } catch (_) {
          // La sesión se considera inválida aunque no sea posible
          // completar el cierre local.
        }

        return false;
      }

      switch (error.code) {
        case 'network-request-failed':
          throw const AuthFailure(
            'No fue posible verificar la sesión. '
            'Comprueba tu conexión.',
          );

        case 'too-many-requests':
          throw const AuthFailure(
            'No fue posible verificar la sesión en este momento. '
            'Inténtalo nuevamente más tarde.',
          );

        default:
          throw const AuthFailure(
            'No fue posible verificar la sesión. '
            'Inténtalo nuevamente.',
          );
      }
    } catch (_) {
      throw const AuthFailure(
        'No fue posible verificar la sesión. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> reauthenticateWithPassword({required String password}) async {
    try {
      await _service.reauthenticateCurrentUserWithPassword(password: password);
    } on StateError {
      throw const AuthFailure(
        'Debes iniciar sesión nuevamente '
        'antes de continuar.',
      );
    } on FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
          throw const AuthFailure('La contraseña ingresada es incorrecta.');

        case 'too-many-requests':
          throw const AuthFailure(
            'Demasiados intentos. '
            'Inténtalo nuevamente más tarde.',
          );

        case 'network-request-failed':
          throw const AuthFailure(
            'No fue posible confirmar tu identidad. '
            'Verifica tu conexión.',
          );

        case 'user-disabled':
        case 'user-not-found':
        case 'user-token-expired':
        case 'invalid-user-token':
          throw const AuthFailure(
            'Debes iniciar sesión nuevamente '
            'antes de continuar.',
          );

        default:
          throw const AuthFailure(
            'No fue posible confirmar tu identidad. '
            'Inténtalo nuevamente.',
          );
      }
    } catch (_) {
      throw const AuthFailure(
        'No fue posible confirmar tu identidad. '
        'Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> deleteCurrentAccount() async {
    try {
      await _service.deleteCurrentUser();
    } on StateError {
      throw const AuthFailure(
        'Debes iniciar sesión nuevamente '
        'antes de eliminar la cuenta.',
      );
    } on FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'requires-recent-login':
        case 'user-token-expired':
          throw const AuthFailure(
            'Debes confirmar nuevamente tu identidad '
            'antes de eliminar la cuenta.',
          );

        case 'too-many-requests':
          throw const AuthFailure(
            'Demasiados intentos. '
            'Inténtalo nuevamente más tarde.',
          );

        case 'network-request-failed':
          throw const AuthFailure(
            'No fue posible eliminar la cuenta. '
            'Verifica tu conexión.',
          );

        default:
          throw const AuthFailure(
            'No fue posible eliminar la cuenta. '
            'Inténtalo nuevamente.',
          );
      }
    } catch (_) {
      throw const AuthFailure(
        'No fue posible eliminar la cuenta. '
        'Inténtalo nuevamente.',
      );
    }
  }

  static const Set<String> _invalidSessionCodes = {
    'user-not-found',
    'user-disabled',
    'user-token-expired',
    'invalid-user-token',
  };

  String _safeSignInMessage(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'Correo o contraseña incorrectos.';

      case 'too-many-requests':
        return 'Demasiados intentos. '
            'Inténtalo nuevamente más tarde.';

      case 'network-request-failed':
        return 'No fue posible conectar con el servicio. '
            'Verifica tu conexión.';

      case 'user-disabled':
        return 'No fue posible iniciar sesión con esta cuenta.';

      default:
        return 'No fue posible iniciar sesión. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeRegistrationMessage(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'Ya existe un registro con este correo. '
            'Inicia sesión con las credenciales utilizadas '
            'para continuar con tu cuenta.';

      case 'invalid-email':
        return 'Ingresa un correo electrónico válido.';

      case 'weak-password':
      case 'invalid-password':
        return 'La contraseña no cumple los requisitos de seguridad.';

      case 'operation-not-allowed':
        return 'El registro mediante correo no está disponible '
            'en este momento.';

      case 'too-many-requests':
        return 'Se alcanzó temporalmente el límite de solicitudes. '
            'Inténtalo nuevamente más tarde.';

      case 'network-request-failed':
        return 'No fue posible crear la cuenta. '
            'Verifica tu conexión.';

      default:
        return 'No fue posible crear la cuenta. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeEmailVerificationMessage(String code) {
    switch (code) {
      case 'too-many-requests':
        return 'Se alcanzó temporalmente el límite de envío de '
            'correos de verificación. '
            'Inténtalo nuevamente más tarde.';

      case 'network-request-failed':
        return 'No fue posible enviar el correo de verificación. '
            'Verifica tu conexión.';

      case 'user-disabled':
      case 'user-not-found':
      case 'user-token-expired':
      case 'invalid-user-token':
        return 'La sesión ya no es válida. '
            'Inicia sesión nuevamente.';

      default:
        return 'No fue posible enviar el correo de verificación. '
            'Inténtalo nuevamente.';
    }
  }

  String _safeEmailVerificationRefreshMessage(String code) {
    switch (code) {
      case 'network-request-failed':
        return 'No fue posible comprobar la verificación del correo. '
            'Verifica tu conexión.';

      case 'too-many-requests':
        return 'No fue posible comprobar la verificación '
            'en este momento. '
            'Inténtalo nuevamente más tarde.';

      case 'user-disabled':
      case 'user-not-found':
      case 'user-token-expired':
      case 'invalid-user-token':
        return 'La sesión ya no es válida. '
            'Inicia sesión nuevamente.';

      default:
        return 'No fue posible comprobar la verificación del correo. '
            'Inténtalo nuevamente.';
    }
  }
}
