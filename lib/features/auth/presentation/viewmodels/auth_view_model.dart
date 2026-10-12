import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/exceptions/auth_failure.dart';
import '../../domain/models/password_requirements.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/email_identity_normalizer.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository)
    : _isAuthenticated = _repository.isAuthenticated {
    _synchronizeEmailVerificationFields();

    _authSubscription = _repository.authStateChanges.listen(
      _handleAuthenticationChange,
    );
  }

  final AuthRepository _repository;

  late final StreamSubscription<bool> _authSubscription;

  bool _isAuthenticated;

  bool _isLoading = false;

  bool _isValidatingSession = false;

  String? _currentUserEmail;

  bool? _isEmailVerified;

  String? _errorMessage;

  bool get isAuthenticated => _isAuthenticated;

  bool get isLoading => _isLoading;

  bool get isValidatingSession => _isValidatingSession;

  bool get isAuthenticatedAppReady {
    if (!_isAuthenticated) {
      return false;
    }

    if (_repository is AuthEmailVerificationRepository) {
      return _isEmailVerified == true;
    }

    return true;
  }

  String? get currentUserEmail => _currentUserEmail;

  bool? get isEmailVerified => _isEmailVerified;

  String? get errorMessage => _errorMessage;

  Future<bool> signIn({required String email, required String password}) async {
    final normalizedEmail = EmailIdentityNormalizer.normalize(email);

    if (normalizedEmail.isEmpty || password.isEmpty) {
      _errorMessage = 'Ingresa tu correo y contraseña.';

      notifyListeners();

      return false;
    }

    _setLoading(true);

    _errorMessage = null;

    try {
      await _repository.signIn(email: normalizedEmail, password: password);

      _synchronizeAuthenticationState();

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

  Future<bool> createUnverifiedAccount({
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    final normalizedEmail = EmailIdentityNormalizer.normalize(email);

    if (normalizedEmail.isEmpty) {
      _errorMessage = 'Ingresa tu correo electrónico.';

      notifyListeners();

      return false;
    }

    final requirements = PasswordRequirements.evaluate(password);

    if (!requirements.isValid) {
      _errorMessage = 'La contraseña no cumple los requisitos de seguridad.';

      notifyListeners();

      return false;
    }

    if (password != passwordConfirmation) {
      _errorMessage = 'Las contraseñas no coinciden.';

      notifyListeners();

      return false;
    }

    if (_repository is! AuthRegistrationRepository) {
      _errorMessage =
          'No fue posible crear la cuenta. '
          'Inténtalo nuevamente.';

      notifyListeners();

      return false;
    }

    final registrationRepository = _repository as AuthRegistrationRepository;

    _setLoading(true);

    _errorMessage = null;

    try {
      await registrationRepository.createUnverifiedAccount(
        email: normalizedEmail,
        password: password,
      );

      _synchronizeAuthenticationState();

      return true;
    } on AuthFailure catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible crear la cuenta. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> sendEmailVerification() async {
    if (!_isAuthenticated) {
      _errorMessage = 'Debes iniciar sesión para verificar tu correo.';

      notifyListeners();

      return false;
    }

    if (_repository is! AuthEmailVerificationRepository) {
      _errorMessage =
          'No fue posible enviar el correo de verificación. '
          'Inténtalo nuevamente.';

      notifyListeners();

      return false;
    }

    if (_isEmailVerified == true) {
      _errorMessage = null;

      notifyListeners();

      return true;
    }

    final verificationRepository =
        _repository as AuthEmailVerificationRepository;

    _setLoading(true);

    _errorMessage = null;

    try {
      await verificationRepository.sendEmailVerification();

      return true;
    } on AuthFailure catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible enviar el correo de verificación. '
          'Inténtalo nuevamente.';

      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> refreshEmailVerificationStatus() async {
    if (!_isAuthenticated) {
      _errorMessage = 'Debes iniciar sesión para verificar tu correo.';

      notifyListeners();

      return false;
    }

    if (_repository is! AuthEmailVerificationRepository) {
      _errorMessage =
          'No fue posible comprobar la verificación del correo. '
          'Inténtalo nuevamente.';

      notifyListeners();

      return false;
    }

    final verificationRepository =
        _repository as AuthEmailVerificationRepository;

    _setLoading(true);

    _errorMessage = null;

    try {
      final verified = await verificationRepository
          .refreshEmailVerificationStatus();

      final previousEmail = _currentUserEmail;

      final previousEmailVerified = _isEmailVerified;

      _synchronizeEmailVerificationFields();

      if (_isEmailVerified != verified) {
        _isEmailVerified = verified;
      }

      if (previousEmail != _currentUserEmail ||
          previousEmailVerified != _isEmailVerified) {
        notifyListeners();
      }

      return verified;
    } on AuthFailure catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible comprobar la verificación del correo. '
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

      _synchronizeAuthenticationState();

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

  Future<bool> validateCurrentSession() async {
    if (!_isAuthenticated) {
      return false;
    }

    if (_isValidatingSession) {
      return _isAuthenticated;
    }

    if (_repository is! AuthSessionValidationRepository) {
      return _isAuthenticated;
    }

    final validationRepository = _repository as AuthSessionValidationRepository;

    _setValidatingSession(true);

    try {
      final valid = await validationRepository.validateCurrentSession();

      if (!valid) {
        _handleAuthenticationChange(false);

        return false;
      }

      _synchronizeAuthenticationState();

      return _isAuthenticated;
    } on AuthFailure catch (error) {
      _errorMessage = error.message;

      notifyListeners();

      return _isAuthenticated;
    } catch (_) {
      _errorMessage =
          'No fue posible verificar la sesión. '
          'Inténtalo nuevamente.';

      notifyListeners();

      return _isAuthenticated;
    } finally {
      _setValidatingSession(false);
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

  Future<bool> cancelUnverifiedAccount() async {
    if (!_isAuthenticated) {
      _errorMessage =
          'Debes iniciar sesión nuevamente '
          'antes de cambiar el correo.';

      notifyListeners();

      return false;
    }

    if (_repository is! AuthEmailVerificationRepository ||
        _repository is! AuthAccountManagementRepository) {
      _errorMessage =
          'No fue posible cancelar el registro pendiente. '
          'Inténtalo nuevamente.';

      notifyListeners();

      return false;
    }

    final verificationRepository =
        _repository as AuthEmailVerificationRepository;

    final accountRepository = _repository as AuthAccountManagementRepository;

    _setLoading(true);

    _errorMessage = null;

    try {
      final refreshedVerified = await verificationRepository
          .refreshEmailVerificationStatus();

      final previousEmail = _currentUserEmail;

      final previousEmailVerified = _isEmailVerified;

      _synchronizeEmailVerificationFields();

      final verified = refreshedVerified || _isEmailVerified == true;

      if (verified && _isEmailVerified != true) {
        _isEmailVerified = true;
      }

      if (previousEmail != _currentUserEmail ||
          previousEmailVerified != _isEmailVerified) {
        notifyListeners();
      }

      if (verified) {
        _errorMessage =
            'Tu correo ya está verificado. '
            'La cuenta no se eliminó.';

        notifyListeners();

        return false;
      }

      await accountRepository.deleteCurrentAccount();

      _synchronizeAuthenticationState();

      return true;
    } on AuthFailure catch (error) {
      _errorMessage = error.message;

      return false;
    } catch (_) {
      _errorMessage =
          'No fue posible cancelar el registro pendiente. '
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

      _synchronizeAuthenticationState();

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

  void _synchronizeAuthenticationState() {
    _handleAuthenticationChange(_repository.isAuthenticated);
  }

  void _handleAuthenticationChange(bool isAuthenticated) {
    final previousAuthenticated = _isAuthenticated;

    final previousEmail = _currentUserEmail;

    final previousEmailVerified = _isEmailVerified;

    _isAuthenticated = isAuthenticated;

    _synchronizeEmailVerificationFields();

    final changed =
        previousAuthenticated != _isAuthenticated ||
        previousEmail != _currentUserEmail ||
        previousEmailVerified != _isEmailVerified;

    if (changed) {
      notifyListeners();
    }
  }

  void _synchronizeEmailVerificationFields() {
    if (!_isAuthenticated) {
      _currentUserEmail = null;

      _isEmailVerified = null;

      return;
    }

    if (_repository is! AuthEmailVerificationRepository) {
      _currentUserEmail = null;

      _isEmailVerified = null;

      return;
    }

    final verificationRepository =
        _repository as AuthEmailVerificationRepository;

    _currentUserEmail = verificationRepository.currentUserEmail;

    _isEmailVerified = verificationRepository.isCurrentUserEmailVerified;
  }

  void _setLoading(bool value) {
    if (_isLoading == value) {
      return;
    }

    _isLoading = value;

    notifyListeners();
  }

  void _setValidatingSession(bool value) {
    if (_isValidatingSession == value) {
      return;
    }

    _isValidatingSession = value;

    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription.cancel();

    super.dispose();
  }
}
