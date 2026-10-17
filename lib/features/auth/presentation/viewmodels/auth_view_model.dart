import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/exceptions/auth_failure.dart';
import '../../domain/models/password_requirements.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/email_identity_normalizer.dart';

class AuthViewModel extends ChangeNotifier {
  AuthViewModel(this._repository)
    : _isAuthenticated = _repository.isAuthenticated {
    _synchronizeIdentityFields();
    _synchronizeEmailVerificationFields();

    _authSubscription = _repository.authStateChanges.listen(
      _handleAuthenticationChange,
    );

    if (_repository is AuthIdentityRepository) {
      final identityRepository = _repository as AuthIdentityRepository;

      _identitySubscription = identityRepository.userIdChanges.listen(
        (_) => _synchronizeAuthenticationState(),
      );
    }
  }

  final AuthRepository _repository;

  late final StreamSubscription<bool> _authSubscription;
  StreamSubscription<String?>? _identitySubscription;

  bool _isAuthenticated;
  bool _isLoading = false;
  bool _isValidatingSession = false;
  bool _isDisposed = false;

  int _authenticationGeneration = 0;
  int _sessionOperationRevision = 0;

  int? _pendingSignOutGeneration;
  String? _pendingSignOutUserId;
  int? _runningObservedLoadingId;
  int? _queuedSessionLoadingId;

  String? _currentUserId;
  String? _currentUserEmail;
  bool? _isEmailVerified;
  String? _errorMessage;

  int _nextLoadingOperationId = 0;
  final Set<int> _activeLoadingOperations = <int>{};

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  bool get isValidatingSession => _isValidatingSession;

  bool get isAuthenticatedAppReady {
    if (!_isAuthenticated) return false;

    if (_repository is AuthEmailVerificationRepository) {
      return _isEmailVerified == true;
    }

    return true;
  }

  String? get currentUserId => _currentUserId;
  String? get currentUserEmail => _currentUserEmail;
  bool? get isEmailVerified => _isEmailVerified;
  String? get errorMessage => _errorMessage;

  /// Indica si la cuenta actual permite confirmar su identidad con Google.
  ///
  /// No intenta autenticar ni modifica la sesión.
  bool get canReauthenticateWithGoogle {
    if (_isDisposed ||
        !_isAuthenticated ||
        _repository is! AuthGoogleAccountManagementRepository) {
      return false;
    }

    return (_repository as AuthGoogleAccountManagementRepository)
        .canReauthenticateWithGoogle;
  }

  Future<bool> signIn({required String email, required String password}) async {
    if (_isDisposed) return false;

    final normalizedEmail = EmailIdentityNormalizer.normalize(email);

    if (normalizedEmail.isEmpty || password.isEmpty) {
      _errorMessage = 'Ingresa tu correo y contraseña.';
      notifyListeners();
      return false;
    }

    return _runSessionOperation(
      signsOut: false,
      fallbackMessage: 'No fue posible iniciar sesión. Inténtalo nuevamente.',
      action: (observation) async {
        if (_repository is AuthObservedSessionOperationsRepository) {
          return (_repository as AuthObservedSessionOperationsRepository)
              .signInObserved(
                email: normalizedEmail,
                password: password,
                onExecutionStarted: observation.onExecutionStarted,
              );
        }

        if (_repository is AuthIdentitySessionOperationsRepository) {
          return (_repository as AuthIdentitySessionOperationsRepository)
              .signInAndGetUserId(email: normalizedEmail, password: password);
        }

        await _repository.signIn(email: normalizedEmail, password: password);

        return null;
      },
    );
  }

  /// Inicia sesión con Google reutilizando las protecciones de sesión.
  ///
  /// La cancelación devuelve false sin mostrar un error.
  /// El repositorio es responsable de ejecutar la selección de Google
  /// dentro de la cola serializada de Firebase Authentication.
  Future<bool> signInWithGoogle() async {
    if (_isDisposed) return false;

    if (_repository is! AuthGoogleSignInRepository) {
      _errorMessage =
          'El inicio de sesión con Google no está disponible '
          'en este momento.';
      notifyListeners();
      return false;
    }

    final googleRepository = _repository as AuthGoogleSignInRepository;

    return _runSessionOperation(
      signsOut: false,
      fallbackMessage:
          'No fue posible iniciar sesión con Google. '
          'Inténtalo nuevamente.',
      action: (observation) {
        return googleRepository.signInWithGoogleObserved(
          onExecutionStarted: observation.onExecutionStarted,
        );
      },
    );
  }

  Future<bool> createUnverifiedAccount({
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    if (_isDisposed) return false;

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
      _errorMessage = 'No fue posible crear la cuenta. Inténtalo nuevamente.';
      notifyListeners();
      return false;
    }

    final registrationRepository = _repository as AuthRegistrationRepository;

    return _runSessionOperation(
      signsOut: false,
      fallbackMessage: 'No fue posible crear la cuenta. Inténtalo nuevamente.',
      action: (observation) async {
        if (_repository is AuthObservedSessionOperationsRepository) {
          return (_repository as AuthObservedSessionOperationsRepository)
              .createUnverifiedAccountObserved(
                email: normalizedEmail,
                password: password,
                onExecutionStarted: observation.onExecutionStarted,
                onProvisionalAccountCreated: observation.onProvisionalCreated,
                onProvisionalAccountCleaned: observation.onProvisionalCleaned,
              );
        }

        if (_repository is AuthIdentitySessionOperationsRepository) {
          return (_repository as AuthIdentitySessionOperationsRepository)
              .createUnverifiedAccountAndGetUserId(
                email: normalizedEmail,
                password: password,
              );
        }

        await registrationRepository.createUnverifiedAccount(
          email: normalizedEmail,
          password: password,
        );

        return null;
      },
    );
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

    final requestedGeneration = _authenticationGeneration;
    final requestedUserId = _currentUserId;
    final loadingOperation = _beginLoadingOperation();

    _errorMessage = null;

    try {
      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      await verificationRepository.sendEmailVerification();

      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      return true;
    } on AuthFailure catch (error) {
      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      _errorMessage = error.message;
      return false;
    } catch (_) {
      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      _errorMessage =
          'No fue posible enviar el correo de verificación. '
          'Inténtalo nuevamente.';
      return false;
    } finally {
      _finishLoadingOperation(loadingOperation);
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

    final requestedGeneration = _authenticationGeneration;
    final requestedUserId = _currentUserId;
    final loadingOperation = _beginLoadingOperation();

    _errorMessage = null;

    try {
      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      final verified = await verificationRepository
          .refreshEmailVerificationStatus();

      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

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
      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      _errorMessage = error.message;
      return false;
    } catch (_) {
      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      _errorMessage =
          'No fue posible comprobar la verificación del correo. '
          'Inténtalo nuevamente.';
      return false;
    } finally {
      _finishLoadingOperation(loadingOperation);
    }
  }

  Future<bool> signOut() async {
    return _runSessionOperation(
      signsOut: true,
      fallbackMessage: 'No fue posible cerrar la sesión. Inténtalo nuevamente.',
      action: (_) async {
        await _repository.signOut();
        return null;
      },
    );
  }

  Future<bool> _runSessionOperation({
    required bool signsOut,
    required String fallbackMessage,
    required Future<String?> Function(_SessionOperationObservation) action,
  }) async {
    if (_isDisposed) return false;

    final operationRevision = ++_sessionOperationRevision;
    _synchronizeAuthenticationState();

    if (_isDisposed || operationRevision != _sessionOperationRevision) {
      return false;
    }

    final requestedGeneration = _authenticationGeneration;
    final requestedUserId = _currentUserId;
    final requestedAuthenticated = _isAuthenticated;

    final queuedBehindOwnSignOut =
        !signsOut &&
        _pendingSignOutGeneration == requestedGeneration &&
        _pendingSignOutUserId == requestedUserId &&
        requestedAuthenticated;

    if (signsOut) {
      _pendingSignOutGeneration = requestedGeneration;
      _pendingSignOutUserId = requestedUserId;
    }

    bool isLatestOperation() =>
        !_isDisposed && operationRevision == _sessionOperationRevision;

    bool isOriginalContext() =>
        isLatestOperation() &&
        _authenticationGeneration == requestedGeneration &&
        _currentUserId == requestedUserId &&
        _isAuthenticated == requestedAuthenticated;

    _errorMessage = null;

    final loadingOperation = _beginLoadingOperation();

    if (queuedBehindOwnSignOut) {
      _queuedSessionLoadingId = loadingOperation;
    }

    late final _SessionOperationObservation observation;

    observation = _SessionOperationObservation(
      readGeneration: () => _authenticationGeneration,
      readUserId: () => _currentUserId,
      readAuthenticated: () => _isAuthenticated,
      onStart: () {
        // Una solicitud que dejo de ser la mas reciente
        // no puede iniciar una nueva autenticacion.
        //
        // Esta comprobacion ocurre al salir de la cola,
        // antes de llamar a Firebase.
        if (!isLatestOperation()) {
          throw StateError('La operación fue sustituida antes de ejecutarse.');
        }

        _synchronizeAuthenticationState();

        // La sincronizacion puede notificar observadores
        // que soliciten otra operacion de sesion.
        // Comprobamos nuevamente la revision.
        if (!isLatestOperation()) {
          throw StateError('La operación fue sustituida antes de ejecutarse.');
        }

        final allowedQueuedTransition =
            queuedBehindOwnSignOut &&
            _authenticationGeneration == requestedGeneration + 1 &&
            !_isAuthenticated &&
            _currentUserId == null;

        if (!isOriginalContext() && !allowedQueuedTransition) {
          throw StateError('La sesión cambió antes de ejecutar la operación.');
        }

        _runningObservedLoadingId = loadingOperation;
      },
    );

    bool isObservedResultCurrent(String? resultUserId) {
      if (!isLatestOperation() || !observation.started) {
        return false;
      }

      if (!_isAuthenticated ||
          resultUserId == null ||
          resultUserId.isEmpty ||
          _currentUserId != resultUserId) {
        return false;
      }

      if (observation.provisionalUserId != null) {
        return observation.provisionalUserId == resultUserId &&
            observation.createdAtExpectedTransition &&
            observation.provisionalCleanedAtGeneration == null &&
            _authenticationGeneration == observation.createdGeneration;
      }

      final expectedTransitions =
          observation.startedAuthenticated &&
              observation.startedUserId == resultUserId
          ? 0
          : 1;

      return _authenticationGeneration ==
          observation.startedGeneration + expectedTransitions;
    }

    bool isObservedErrorCurrent() {
      if (!isLatestOperation() || !observation.started) {
        return false;
      }

      if (observation.provisionalUserId != null) {
        return observation.createdAtExpectedTransition &&
            observation.provisionalCleanedAtGeneration ==
                observation.createdGeneration! + 1 &&
            _authenticationGeneration ==
                observation.provisionalCleanedAtGeneration &&
            _currentUserId == null &&
            !_isAuthenticated;
      }

      return _authenticationGeneration == observation.startedGeneration &&
          _currentUserId == observation.startedUserId &&
          _isAuthenticated == observation.startedAuthenticated;
    }

    try {
      if (!isOriginalContext()) {
        return false;
      }

      final resultUserId = await action(observation);

      if (!isLatestOperation()) {
        return false;
      }

      _synchronizeAuthenticationState();

      if (!isLatestOperation()) {
        return false;
      }

      if (observation.started) {
        return isObservedResultCurrent(resultUserId);
      }

      final unchangedContext = isOriginalContext();

      final singleTransition =
          _authenticationGeneration == requestedGeneration + 1;

      if (signsOut) {
        return !_isAuthenticated &&
            _currentUserId == null &&
            (unchangedContext || (requestedAuthenticated && singleTransition));
      }

      if (!_isAuthenticated || !(unchangedContext || singleTransition)) {
        return false;
      }

      if (_repository is AuthIdentitySessionOperationsRepository) {
        return resultUserId != null &&
            resultUserId.isNotEmpty &&
            resultUserId == _currentUserId;
      }

      if (_repository is AuthIdentityRepository) {
        return unchangedContext;
      }

      return unchangedContext || (!requestedAuthenticated && singleTransition);
    } on AuthFailure catch (error) {
      if (!isLatestOperation()) {
        return false;
      }

      _synchronizeAuthenticationState();

      if (observation.started
          ? isObservedErrorCurrent()
          : isOriginalContext()) {
        _errorMessage = error.message;
        notifyListeners();
      }

      return false;
    } catch (_) {
      if (!isLatestOperation()) {
        return false;
      }

      _synchronizeAuthenticationState();

      if (observation.started
          ? isObservedErrorCurrent()
          : isOriginalContext()) {
        _errorMessage = fallbackMessage;
        notifyListeners();
      }

      return false;
    } finally {
      if (signsOut &&
          _pendingSignOutGeneration == requestedGeneration &&
          _pendingSignOutUserId == requestedUserId) {
        _pendingSignOutGeneration = null;
        _pendingSignOutUserId = null;
      }

      if (_runningObservedLoadingId == loadingOperation) {
        _runningObservedLoadingId = null;
      }

      if (_queuedSessionLoadingId == loadingOperation) {
        _queuedSessionLoadingId = null;
      }

      _finishLoadingOperation(loadingOperation);
    }
  }

  Future<bool> validateCurrentSession() async {
    if (!_isAuthenticated || _isDisposed) {
      return false;
    }

    if (_isValidatingSession) {
      return _isAuthenticated;
    }

    if (_repository is! AuthSessionValidationRepository) {
      return _isAuthenticated;
    }

    final validationRepository = _repository as AuthSessionValidationRepository;

    final requestedGeneration = _authenticationGeneration;
    final requestedUserId = _currentUserId;

    _setValidatingSession(true);

    try {
      final valid = await validationRepository.validateCurrentSession();

      if (!_isCurrentValidationContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return _isAuthenticated;
      }

      if (!valid) {
        _handleAuthenticationChange(false);
        return false;
      }

      _synchronizeAuthenticationState();
      return _isAuthenticated;
    } on AuthFailure catch (error) {
      if (!_isCurrentValidationContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return _isAuthenticated;
      }

      _errorMessage = error.message;
      notifyListeners();
      return _isAuthenticated;
    } catch (_) {
      if (!_isCurrentValidationContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return _isAuthenticated;
      }

      _errorMessage =
          'No fue posible verificar la sesión. Inténtalo nuevamente.';
      notifyListeners();
      return _isAuthenticated;
    } finally {
      if (_isCurrentValidationContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        _setValidatingSession(false);
      }
    }
  }

  Future<bool> reauthenticateWithPassword({required String password}) async {
    if (!_isAuthenticated) {
      _errorMessage = 'Debes iniciar sesión nuevamente antes de continuar.';
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
          'No fue posible confirmar tu identidad. Inténtalo nuevamente.';
      notifyListeners();
      return false;
    }

    final accountRepository = _repository as AuthAccountManagementRepository;
    final requestedGeneration = _authenticationGeneration;
    final requestedUserId = _currentUserId;
    final loadingOperation = _beginLoadingOperation();

    _errorMessage = null;

    try {
      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      await accountRepository.reauthenticateWithPassword(password: password);

      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      return true;
    } on AuthFailure catch (error) {
      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      _errorMessage = error.message;
      return false;
    } catch (_) {
      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      _errorMessage =
          'No fue posible confirmar tu identidad. Inténtalo nuevamente.';
      return false;
    } finally {
      _finishLoadingOperation(loadingOperation);
    }
  }

  /// Confirma nuevamente la identidad con Google, sin cambiar de cuenta.
  ///
  /// Devuelve false si se cancela el selector, si la sesión cambia
  /// o si Firebase no puede comprobar la credencial.
  Future<bool> reauthenticateWithGoogle() async {
    if (_isDisposed) {
      return false;
    }

    if (!_isAuthenticated) {
      _errorMessage = 'Debes iniciar sesión nuevamente antes de continuar.';
      notifyListeners();
      return false;
    }

    if (!canReauthenticateWithGoogle) {
      _errorMessage =
          'La confirmación con Google no está disponible para esta cuenta.';
      notifyListeners();
      return false;
    }

    final accountRepository =
        _repository as AuthGoogleAccountManagementRepository;

    final requestedGeneration = _authenticationGeneration;
    final requestedUserId = _currentUserId;
    final loadingOperation = _beginLoadingOperation();

    _errorMessage = null;

    try {
      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      final confirmed = await accountRepository.reauthenticateWithGoogle();

      // Actualiza el contexto antes de aceptar el resultado.
      _synchronizeAuthenticationState();

      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      // Cancelar Google no genera un mensaje de error.
      return confirmed;
    } on AuthFailure catch (error) {
      _synchronizeAuthenticationState();

      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      _errorMessage = error.message;
      return false;
    } catch (_) {
      _synchronizeAuthenticationState();

      if (!_isCurrentAuthenticatedContext(
        generation: requestedGeneration,
        userId: requestedUserId,
      )) {
        return false;
      }

      _errorMessage =
          'No fue posible confirmar tu identidad con Google. '
          'Inténtalo nuevamente.';
      return false;
    } finally {
      _finishLoadingOperation(loadingOperation);
    }
  }

  Future<bool> cancelUnverifiedAccount() async {
    if (!_isAuthenticated) {
      _errorMessage =
          'Debes iniciar sesión nuevamente antes de cambiar el correo.';
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

    final requestedGeneration = _authenticationGeneration;
    final requestedUserId = _currentUserId;

    bool isOriginalCancellationContext() => _isCurrentAuthenticatedContext(
      generation: requestedGeneration,
      userId: requestedUserId,
    );

    bool isExpectedCancellationSignOut() =>
        !_isDisposed &&
        !_isAuthenticated &&
        _currentUserId == null &&
        _authenticationGeneration == requestedGeneration + 1;

    final loadingOperation = _beginLoadingOperation();
    _errorMessage = null;

    try {
      if (!isOriginalCancellationContext()) {
        return false;
      }

      final refreshedVerified = await verificationRepository
          .refreshEmailVerificationStatus();

      if (!isOriginalCancellationContext()) {
        return false;
      }

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
            'Tu correo ya está verificado. La cuenta no se eliminó.';
        notifyListeners();
        return false;
      }

      if (!isOriginalCancellationContext()) {
        return false;
      }

      await accountRepository.deleteCurrentAccount();

      if (isExpectedCancellationSignOut()) {
        return true;
      }

      if (!isOriginalCancellationContext()) {
        return false;
      }

      _synchronizeAuthenticationState();

      return isOriginalCancellationContext() || isExpectedCancellationSignOut();
    } on AuthFailure catch (error) {
      if (!isOriginalCancellationContext()) {
        return false;
      }

      _errorMessage = error.message;
      return false;
    } catch (_) {
      if (!isOriginalCancellationContext()) {
        return false;
      }

      _errorMessage =
          'No fue posible cancelar el registro pendiente. '
          'Inténtalo nuevamente.';
      return false;
    } finally {
      _finishLoadingOperation(loadingOperation);
    }
  }

  Future<bool> deleteCurrentAccount() async {
    if (!_isAuthenticated || _isDisposed) {
      _errorMessage =
          'Debes iniciar sesión nuevamente antes de eliminar la cuenta.';

      if (!_isDisposed) notifyListeners();
      return false;
    }

    if (_repository is! AuthAccountManagementRepository) {
      _errorMessage =
          'No fue posible eliminar la cuenta. Inténtalo nuevamente.';
      notifyListeners();
      return false;
    }

    final accountRepository = _repository as AuthAccountManagementRepository;
    final requestedGeneration = _authenticationGeneration;
    final requestedUserId = _currentUserId;

    bool isOriginalDeletionContext() => _isCurrentAuthenticatedContext(
      generation: requestedGeneration,
      userId: requestedUserId,
    );

    bool isExpectedDeletionSignOut() =>
        !_isDisposed &&
        !_isAuthenticated &&
        _currentUserId == null &&
        _authenticationGeneration == requestedGeneration + 1;

    final loadingOperation = _beginLoadingOperation();
    _errorMessage = null;

    try {
      if (!isOriginalDeletionContext()) {
        return false;
      }

      await accountRepository.deleteCurrentAccount();

      if (isExpectedDeletionSignOut()) {
        return true;
      }

      if (!isOriginalDeletionContext()) {
        return false;
      }

      _synchronizeAuthenticationState();

      return isOriginalDeletionContext() || isExpectedDeletionSignOut();
    } on AuthFailure catch (error) {
      if (!isOriginalDeletionContext()) {
        return false;
      }

      _errorMessage = error.message;
      return false;
    } catch (_) {
      if (!isOriginalDeletionContext()) {
        return false;
      }

      _errorMessage =
          'No fue posible eliminar la cuenta. '
          'Inténtalo nuevamente.';
      return false;
    } finally {
      _finishLoadingOperation(loadingOperation);
    }
  }

  void clearError() {
    if (_errorMessage == null) return;

    _errorMessage = null;
    notifyListeners();
  }

  void _synchronizeAuthenticationState() {
    _handleAuthenticationChange(_repository.isAuthenticated);
  }

  void _handleAuthenticationChange(bool isAuthenticated) {
    if (_isDisposed) return;

    final previousAuthenticated = _isAuthenticated;
    final previousUserId = _currentUserId;
    final previousEmail = _currentUserEmail;
    final previousEmailVerified = _isEmailVerified;

    _isAuthenticated = isAuthenticated;

    _synchronizeIdentityFields();
    _synchronizeEmailVerificationFields();

    final authenticationContextChanged =
        previousAuthenticated != _isAuthenticated ||
        previousUserId != _currentUserId;

    if (authenticationContextChanged) {
      _authenticationGeneration++;

      final observedLoadingId =
          _runningObservedLoadingId ?? _queuedSessionLoadingId;

      _activeLoadingOperations.removeWhere((id) => id != observedLoadingId);

      _isLoading = _activeLoadingOperations.isNotEmpty;
      _isValidatingSession = false;
      _errorMessage = null;
    }

    final changed =
        authenticationContextChanged ||
        previousEmail != _currentUserEmail ||
        previousEmailVerified != _isEmailVerified;

    if (changed) {
      notifyListeners();
    }
  }

  void _synchronizeIdentityFields() {
    if (!_isAuthenticated) {
      _currentUserId = null;
      return;
    }

    if (_repository is! AuthIdentityRepository) {
      _currentUserId = null;
      return;
    }

    _currentUserId = (_repository as AuthIdentityRepository).currentUserId;
  }

  bool _isCurrentValidationContext({
    required int generation,
    required String? userId,
  }) {
    return !_isDisposed &&
        generation == _authenticationGeneration &&
        userId == _currentUserId;
  }

  bool _isCurrentAuthenticatedContext({
    required int generation,
    required String? userId,
  }) {
    return _isAuthenticated &&
        _isCurrentValidationContext(generation: generation, userId: userId);
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

  int _beginLoadingOperation() {
    final operationId = ++_nextLoadingOperationId;

    _activeLoadingOperations.add(operationId);
    _setLoading(true);

    return operationId;
  }

  void _finishLoadingOperation(int operationId) {
    if (_isDisposed) return;

    final removed = _activeLoadingOperations.remove(operationId);

    if (!removed) return;

    _setLoading(_activeLoadingOperations.isNotEmpty);
  }

  void _setLoading(bool value) {
    if (_isDisposed || _isLoading == value) return;

    _isLoading = value;
    notifyListeners();
  }

  void _setValidatingSession(bool value) {
    if (_isDisposed || _isValidatingSession == value) return;

    _isValidatingSession = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _authenticationGeneration++;
    _activeLoadingOperations.clear();

    _identitySubscription?.cancel();
    _authSubscription.cancel();

    super.dispose();
  }
}

class _SessionOperationObservation {
  _SessionOperationObservation({
    required this.readGeneration,
    required this.readUserId,
    required this.readAuthenticated,
    required this.onStart,
  });

  final int Function() readGeneration;
  final String? Function() readUserId;
  final bool Function() readAuthenticated;
  final void Function() onStart;

  int? _startedGeneration;
  String? _startedUserId;
  bool _startedAuthenticated = false;

  String? provisionalUserId;
  int? createdGeneration;
  bool createdAtExpectedTransition = false;
  int? provisionalCleanedAtGeneration;

  bool get started => _startedGeneration != null;
  int get startedGeneration => _startedGeneration!;
  String? get startedUserId => _startedUserId;
  bool get startedAuthenticated => _startedAuthenticated;

  void onExecutionStarted() {
    if (started) {
      throw StateError('La operación ya había comenzado.');
    }

    onStart();

    _startedGeneration = readGeneration();
    _startedUserId = readUserId();
    _startedAuthenticated = readAuthenticated();
  }

  void onProvisionalCreated(String userId) {
    if (!started || provisionalUserId != null) {
      throw StateError('Registro provisional fuera de secuencia.');
    }

    provisionalUserId = userId;
    createdGeneration = readGeneration();

    createdAtExpectedTransition =
        readAuthenticated() &&
        readUserId() == userId &&
        createdGeneration == startedGeneration + 1 &&
        userId != startedUserId;
  }

  void onProvisionalCleaned(String userId) {
    if (provisionalUserId != userId || !createdAtExpectedTransition) {
      return;
    }

    provisionalCleanedAtGeneration = readGeneration();
  }
}
