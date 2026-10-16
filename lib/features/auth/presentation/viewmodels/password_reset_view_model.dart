import 'package:flutter/foundation.dart';

import '../../domain/exceptions/password_reset_failure.dart';
import '../../domain/repositories/password_reset_repository.dart';

class PasswordResetViewModel extends ChangeNotifier {
  PasswordResetViewModel(this._repository);

  final PasswordResetRepository _repository;

  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static const String confirmationMessage =
      'Si es posible recuperar la contraseña de tu cuenta, '
      'recibirás un enlace en tu correo electrónico.';

  bool _isLoading = false;
  bool _isSent = false;
  bool _isDisposed = false;
  String? _errorMessage;

  bool get isLoading => _isLoading;

  bool get isSent => _isSent;

  String? get errorMessage => _errorMessage;

  Future<bool> requestPasswordReset({required String email}) async {
    if (_isDisposed || _isLoading || _isSent) {
      return false;
    }

    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty) {
      _errorMessage = 'Ingresa tu correo electrónico.';
      notifyListeners();
      return false;
    }

    if (!_emailPattern.hasMatch(normalizedEmail)) {
      _errorMessage = 'Ingresa un correo electrónico válido.';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.requestPasswordReset(email: normalizedEmail);

      if (_isDisposed) {
        return false;
      }

      _isSent = true;
      return true;
    } on PasswordResetFailure catch (error) {
      if (_isDisposed) {
        return false;
      }

      _errorMessage = error.message;
      return false;
    } catch (_) {
      if (_isDisposed) {
        return false;
      }

      _errorMessage =
          'No fue posible procesar la solicitud. '
          'Inténtalo nuevamente.';
      return false;
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void clearError() {
    if (_isDisposed || _errorMessage == null) {
      return;
    }

    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
