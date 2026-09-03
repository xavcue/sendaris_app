import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/exceptions/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';
import '../services/firebase_auth_service.dart';

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository(this._service);

  final FirebaseAuthService _service;

  @override
  bool get isAuthenticated => _service.currentUser != null;

  @override
  Stream<bool> get authStateChanges {
    return _service.authStateChanges.map((user) => user != null);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _service.signIn(email: email, password: password);
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_safeMessageFor(error.code));
    } catch (_) {
      throw const AuthFailure(
        'No fue posible iniciar sesión. Inténtalo nuevamente.',
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _service.signOut();
    } on FirebaseAuthException {
      throw const AuthFailure(
        'No fue posible cerrar la sesión. Inténtalo nuevamente.',
      );
    } catch (_) {
      throw const AuthFailure(
        'No fue posible cerrar la sesión. Inténtalo nuevamente.',
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
        return 'Demasiados intentos. Inténtalo nuevamente más tarde.';

      case 'network-request-failed':
        return 'No fue posible conectar con el servicio. Verifica tu conexión.';

      case 'user-disabled':
        return 'No fue posible iniciar sesión con esta cuenta.';

      default:
        return 'No fue posible iniciar sesión. Inténtalo nuevamente.';
    }
  }
}
