import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/exceptions/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/firebase_auth_service.dart';

class FirebaseAuthRepository
    implements AuthRepository, AuthAccountManagementRepository {
  FirebaseAuthRepository(this._service);

  final FirebaseAuthService _service;

  @override
  bool get isAuthenticated {
    return _service.currentUser != null;
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
      throw AuthFailure(_safeMessageFor(error.code));
    } catch (_) {
      throw const AuthFailure(
        'No fue posible iniciar sesión. '
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

  String _safeMessageFor(String code) {
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
}
