import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/exceptions/auth_failure.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository)
    : _isAuthenticated = _repository.isAuthenticated {
    _authSubscription = _repository.authStateChanges.listen(
      _handleAuthenticationChange,
    );
  }

  final AuthRepository _repository;

  late final StreamSubscription<bool> _authSubscription;

  bool _isAuthenticated;

  bool _isLoading = false;

  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  Future<bool> signIn({required String email, required String password}) async {
    final normalizedEmail = email.trim();

    if (normalizedEmail.isEmpty || password.isEmpty) {
      _errorMessage = 'Ingresa tu correo y contraseña.';

      notifyListeners();

      return false;
    }

    _setLoading(true);

    _errorMessage = null;

    try {
      await _repository.signIn(email: normalizedEmail, password: password);

      return true;
    } on AuthFailure catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible iniciar sesión. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signOut() async {
    _setLoading(true);

    _errorMessage = null;

    try {
      await _repository.signOut();

      _handleAuthenticationChange(false);

      return true;
    } on AuthFailure catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible cerrar la sesión. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> reauthenticateWithPassword({required String password}) async {
    if (!_isAuthenticated) {
      _errorMessage =
          'Debes iniciar sesión nuevamente '
          'antes de continuar.';

      notifyListeners();

      return false;
    }

    if (password.isEmpty) {
      _errorMessage = 'Ingresa tu contraseña para continuar.';

      notifyListeners();

      return false;
    }

    if (_repository is! AuthAccountManagementRepository) {
      _errorMessage =
          'No fue posible confirmar tu identidad. '
          'Inténtalo nuevamente.';

      notifyListeners();

      return false;
    }

    final accountRepository = _repository as AuthAccountManagementRepository;

    _setLoading(true);

    _errorMessage = null;

    try {
      await accountRepository.reauthenticateWithPassword(password: password);

      return true;
    } on AuthFailure catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible confirmar tu identidad. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteCurrentAccount() async {
    if (!_isAuthenticated) {
      _errorMessage =
          'Debes iniciar sesión nuevamente '
          'antes de eliminar la cuenta.';

      notifyListeners();

      return false;
    }

    if (_repository is! AuthAccountManagementRepository) {
      _errorMessage =
          'No fue posible eliminar la cuenta. '
          'Inténtalo nuevamente.';

      notifyListeners();

      return false;
    }

    final accountRepository = _repository as AuthAccountManagementRepository;

    _setLoading(true);

    _errorMessage = null;

    try {
      await accountRepository.deleteCurrentAccount();

      _handleAuthenticationChange(false);

      return true;
    } on AuthFailure catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible eliminar la cuenta. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    if (_errorMessage == null) {
      return;
    }

    _errorMessage = null;

    notifyListeners();
  }

  void _handleAuthenticationChange(bool isAuthenticated) {
    if (_isAuthenticated == isAuthenticated) {
      return;
    }

    _isAuthenticated = isAuthenticated;

    notifyListeners();
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;

    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();

    super.dispose();
  }
}
