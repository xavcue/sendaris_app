import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/exceptions/password_reset_failure.dart';
import '../../domain/repositories/password_reset_repository.dart';

class FirebasePasswordResetRepository implements PasswordResetRepository {
  FirebasePasswordResetRepository(this._firebaseAuth);

  final FirebaseAuth _firebaseAuth;

  @override
  Future<void> requestPasswordReset({required String email}) async {
    final normalizedEmail = email.trim();

    try {
      await _firebaseAuth.setLanguageCode('es-419');

      await _firebaseAuth.sendPasswordResetEmail(email: normalizedEmail);
    } on FirebaseAuthException catch (error) {
      switch (error.code) {
        case 'user-not-found':
          // No revelar si existe una cuenta asociada al correo.
          return;

        case 'too-many-requests':
          throw const PasswordResetFailure(
            'No es posible procesar la solicitud en este momento. '
            'Inténtalo nuevamente más tarde.',
          );

        case 'network-request-failed':
          throw const PasswordResetFailure(
            'No fue posible conectar con el servicio. '
            'Comprueba tu conexión.',
          );

        default:
          throw const PasswordResetFailure(
            'No fue posible procesar la solicitud. '
            'Inténtalo nuevamente.',
          );
      }
    } catch (_) {
      throw const PasswordResetFailure(
        'No fue posible procesar la solicitud. '
        'Inténtalo nuevamente.',
      );
    }
  }
}
