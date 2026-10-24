import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/animation/app_motion.dart';
import '../../../../app/session/account_biometric_access_coordinator.dart';
import '../../../../app/session/account_conventional_access_coordinator.dart';
import '../../../../app/session/firebase_account_contexts.dart';
import '../../../../app/session/sendaris_dual_account_root.dart';
import '../../../../app/theme/theme_mode_controller.dart';
import '../../data/repositories/firebase_password_reset_repository.dart';
import '../../domain/repositories/password_reset_repository.dart';
import '../viewmodels/auth_view_model.dart';
import '../widgets/auth_top_bar.dart';
import 'password_reset_dialog.dart';
import 'registration_email_view.dart';

/// Pantalla única de inicio de sesión de Sendaris.
///
/// Mantiene correo, contraseña, Google, recuperación,
/// registro y verificación del correo electrónico.
///
/// El acceso biométrico solo se habilita cuando la raíz
/// dual proporciona una cuenta vinculada y su coordinador.
class LoginView extends StatefulWidget {
  const LoginView({this.passwordResetRepository, super.key});

  final PasswordResetRepository? passwordResetRepository;

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  late final AnimationController _entranceController;

  late final Animation<double> _logoOpacity;
  late final Animation<double> _logoScale;
  late final Animation<double> _headingOpacity;
  late final Animation<Offset> _headingSlide;
  late final Animation<double> _formOpacity;
  late final Animation<Offset> _formSlide;
  late final Animation<double> _footerOpacity;

  bool _obscurePassword = true;
  bool _showRegistration = false;
  bool _localAccessBusy = false;

  String? _accessError;

  bool _showFieldErrors = false;
  Timer? _fieldErrorTimer;
  int _errorAttemptRevision = 0;

  static const Duration _errorVisibility = Duration(seconds: 6);

  bool _validateLoginFields() {
    _fieldErrorTimer?.cancel();
    _showFieldErrors = true;

    final valid = _formKey.currentState!.validate();

    if (valid) {
      _showFieldErrors = false;
      return true;
    }

    _fieldErrorTimer = Timer(_errorVisibility, () {
      if (!mounted) {
        return;
      }

      _showFieldErrors = false;
      _formKey.currentState?.validate();
    });

    return false;
  }

  bool _accessBusy(AuthViewModel model) {
    return model.isLoading || _localAccessBusy;
  }

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: AppMotion.loginEntranceDuration,
    );

    _logoOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0, 0.45, curve: AppMotion.standardCurve),
    );

    _logoScale = Tween<double>(begin: 0.94, end: 1).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0, 0.55, curve: AppMotion.emphasizedCurve),
      ),
    );

    _headingOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.12, 0.62, curve: AppMotion.standardCurve),
    );

    _headingSlide =
        Tween<Offset>(begin: const Offset(0, 0.075), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.12, 0.62, curve: AppMotion.standardCurve),
          ),
        );

    _formOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.28, 0.82, curve: AppMotion.standardCurve),
    );

    _formSlide = Tween<Offset>(begin: const Offset(0, 0.045), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: const Interval(0.28, 0.82, curve: AppMotion.standardCurve),
          ),
        );

    _footerOpacity = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.58, 1, curve: AppMotion.standardCurve),
    );

    _entranceController.forward();
  }

  @override
  void dispose() {
    _fieldErrorTimer?.cancel();
    _entranceController.dispose();
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  /// Autenticación convencional por correo y contraseña.
  Future<void> _submit() async {
    final authViewModel = context.read<AuthViewModel>();

    if (_accessBusy(authViewModel)) {
      return;
    }

    _errorAttemptRevision++;

    if (!_validateLoginFields()) {
      return;
    }

    final conventionalCoordinator = context
        .read<AccountConventionalAccessCoordinator?>();

    final configuration = context.read<SendarisAccountSessionConfiguration?>();

    if (conventionalCoordinator == null && configuration == null) {
      await authViewModel.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );
      return;
    }

    if (conventionalCoordinator == null || configuration == null) {
      setState(() {
        _accessError = 'El acceso no está disponible en este momento.';
      });
      return;
    }

    final email = _emailController.text;
    final password = _passwordController.text;

    setState(() {
      _localAccessBusy = true;
      _accessError = null;
    });

    try {
      final granted = await conventionalCoordinator.signIn(
        slot: configuration.conventionalSlot,
        authenticate: () {
          return authViewModel.signIn(email: email, password: password);
        },
      );

      if (!mounted) {
        return;
      }

      if (!granted &&
          authViewModel.errorMessage == null &&
          authViewModel.isEmailVerified != false) {
        setState(() {
          _accessError =
              'No se pudo autorizar esta sesión. '
              'Comprueba tu conexión y vuelve a intentarlo.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _accessError =
              'No fue posible comprobar el acceso. '
              'Inténtalo nuevamente.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _localAccessBusy = false;
        });
      }
    }
  }

  /// Inicio convencional con Google.
  Future<void> _signInWithGoogle() async {
    _errorAttemptRevision++;

    final authViewModel = context.read<AuthViewModel>();

    if (_accessBusy(authViewModel)) {
      return;
    }

    final conventionalCoordinator = context
        .read<AccountConventionalAccessCoordinator?>();

    final configuration = context.read<SendarisAccountSessionConfiguration?>();

    if (conventionalCoordinator == null && configuration == null) {
      await authViewModel.signInWithGoogle();
      return;
    }

    if (conventionalCoordinator == null || configuration == null) {
      setState(() {
        _accessError = 'El acceso no está disponible en este momento.';
      });
      return;
    }

    setState(() {
      _localAccessBusy = true;
      _accessError = null;
    });

    try {
      final granted = await conventionalCoordinator.signIn(
        slot: configuration.conventionalSlot,
        authenticate: authViewModel.signInWithGoogle,
      );

      if (!mounted) {
        return;
      }

      if (!granted &&
          authViewModel.errorMessage == null &&
          authViewModel.isEmailVerified != false &&
          authViewModel.isAuthenticated) {
        setState(() {
          _accessError =
              'No se pudo autorizar esta sesión. '
              'Comprueba tu conexión y vuelve a intentarlo.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _accessError = 'No fue posible comprobar el acceso con Google.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _localAccessBusy = false;
        });
      }
    }
  }

  /// Acceso mediante la cuenta vinculada a Android Keystore.
  ///
  /// Cancelar no constituye un fallo y no produce mensajes.
  /// Solo el coordinador puede autorizar el acceso privado.
  Future<void> _signInWithBiometrics() async {
    _errorAttemptRevision++;

    final authViewModel = context.read<AuthViewModel>();

    if (_accessBusy(authViewModel)) {
      return;
    }

    final configuration = context.read<SendarisAccountSessionConfiguration?>();

    final biometricCoordinator = context
        .read<AccountBiometricAccessCoordinator?>();

    final linkedSlot = configuration?.linkedSlot;

    if (configuration == null ||
        biometricCoordinator == null ||
        linkedSlot == null) {
      return;
    }

    // Evita que un error anterior permanezca visible
    // después de cancelar el diálogo de huella.
    authViewModel.clearError();

    setState(() {
      _localAccessBusy = true;
      _accessError = null;
    });

    try {
      final outcome = await biometricCoordinator.unlockLinkedAccountWithOutcome(
        slot: linkedSlot,
      );

      if (!mounted) {
        return;
      }

      final message = switch (outcome) {
        AccountBiometricAccessOutcome.granted => null,
        AccountBiometricAccessOutcome.cancelled => null,
        AccountBiometricAccessOutcome.denied =>
          'No se pudo verificar tu identidad. '
              'Inténtalo de nuevo con una huella registrada en este dispositivo.',
        AccountBiometricAccessOutcome.unavailable =>
          'La autenticación biométrica no está disponible en este momento. '
              'Inténtalo nuevamente.',
        AccountBiometricAccessOutcome.sessionUnavailable =>
          'No se pudo confirmar la sesión vinculada. '
              'Comprueba tu conexión e inténtalo nuevamente.',
      };

      if (message != null) {
        setState(() {
          _accessError = message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _accessError =
              'No fue posible comprobar el acceso biométrico. '
              'Inténtalo nuevamente.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _localAccessBusy = false;
        });
      }
    }
  }

  /// Reinicia la autenticación convencional después de
  /// una verificación de correo completada.
  Future<void> _restartConventionalSignIn() async {
    _errorAttemptRevision++;

    final authViewModel = context.read<AuthViewModel>();

    final configuration = context.read<SendarisAccountSessionConfiguration?>();

    if (configuration == null ||
        _accessBusy(authViewModel) ||
        !authViewModel.isAuthenticated ||
        authViewModel.isEmailVerified != true) {
      return;
    }

    setState(() {
      _localAccessBusy = true;
      _accessError = null;
    });

    try {
      final signedOut = await authViewModel.signOut();

      if (!mounted) {
        return;
      }

      if (!signedOut) {
        setState(() {
          _accessError =
              authViewModel.errorMessage ??
              'No fue posible reiniciar el acceso. Inténtalo nuevamente.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _accessError = 'No fue posible reiniciar el acceso.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _localAccessBusy = false;
        });
      }
    }
  }

  PasswordResetRepository _passwordResetRepository() {
    final provided = widget.passwordResetRepository;

    if (provided != null) {
      return provided;
    }

    final configuration = context.read<SendarisAccountSessionConfiguration?>();

    final FirebaseAuth auth;

    if (configuration == null ||
        configuration.conventionalSlot == FirebaseAccountSlot.primary) {
      auth = FirebaseAuth.instance;
    } else {
      final secondaryApp = Firebase.app(
        FirebaseAccountContextManager.secondaryApplicationName,
      );

      auth = FirebaseAuth.instanceFor(app: secondaryApp);
    }

    return FirebasePasswordResetRepository(auth);
  }

  Future<void> _openPasswordReset(AuthViewModel authViewModel) async {
    if (_accessBusy(authViewModel)) {
      return;
    }

    authViewModel.clearError();

    final repository = _passwordResetRepository();

    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return PasswordResetDialog(
          repository: repository,
          initialEmail: _emailController.text.trim(),
        );
      },
    );
  }

  void _openRegistration(AuthViewModel authViewModel) {
    if (_accessBusy(authViewModel)) {
      return;
    }

    authViewModel.clearError();

    setState(() {
      _accessError = null;
      _showRegistration = true;
    });
  }

  void _keepRegistrationOpen() {
    if (_showRegistration) {
      return;
    }

    setState(() {
      _showRegistration = true;
    });
  }

  void _closeRegistration() {
    final authViewModel = context.read<AuthViewModel>();

    authViewModel.clearError();

    setState(() {
      _showRegistration = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    final hasUnverifiedSession =
        authViewModel.isAuthenticated && authViewModel.isEmailVerified == false;

    if (_showRegistration || hasUnverifiedSession) {
      return RegistrationEmailView(
        initialVerificationPending: hasUnverifiedSession,
        initialVerificationEmail: hasUnverifiedSession
            ? authViewModel.currentUserEmail
            : null,
        onUseAnotherEmailRequested: _keepRegistrationOpen,
        onBack: _closeRegistration,
        onLogin: _closeRegistration,
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final themeModeController = context.watch<ThemeModeController?>();

    final configuration = context.watch<SendarisAccountSessionConfiguration?>();

    final biometricCoordinator = context
        .read<AccountBiometricAccessCoordinator?>();

    final biometricAvailable =
        configuration?.linkedSlot != null && biometricCoordinator != null;

    final mustRestartVerifiedSession =
        configuration != null &&
        authViewModel.isAuthenticated &&
        authViewModel.isEmailVerified == true;

    final isBusy = _accessBusy(authViewModel);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 78, 24, 32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Consumer<AuthViewModel>(
                      builder: (context, authViewModel, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FadeTransition(
                              opacity: _logoOpacity,
                              child: ScaleTransition(
                                scale: _logoScale,
                                child: Center(
                                  child: Container(
                                    width: 104,
                                    height: 104,
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface.withValues(
                                        alpha: isDark ? 0.82 : 0.90,
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant
                                            .withValues(alpha: 0.45),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: colorScheme.shadow.withValues(
                                            alpha: isDark ? 0.22 : 0.08,
                                          ),
                                          blurRadius: 24,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(25),
                                      child: Image.asset(
                                        'assets/branding/sendaris_app_icon.png',
                                        key: const Key('sendaris-brand-icon'),
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 22),

                            FadeTransition(
                              opacity: _headingOpacity,
                              child: SlideTransition(
                                position: _headingSlide,
                                child: Column(
                                  children: [
                                    Text(
                                      'Sendaris',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.displaySmall
                                          ?.copyWith(
                                            fontSize: 38,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: -1.25,
                                          ),
                                    ),
                                    const SizedBox(height: 9),
                                    Text(
                                      'Organiza registros y rutinas '
                                      'en un solo lugar.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            height: 1.45,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 34),

                            FadeTransition(
                              opacity: _formOpacity,
                              child: SlideTransition(
                                position: _formSlide,
                                child: Card(
                                  child: Padding(
                                    padding: const EdgeInsets.all(22),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                width: 42,
                                                height: 42,
                                                decoration: BoxDecoration(
                                                  color: colorScheme
                                                      .primaryContainer
                                                      .withValues(
                                                        alpha: isDark
                                                            ? 0.38
                                                            : 0.65,
                                                      ),
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                ),
                                                child: Icon(
                                                  Icons.person_outline_rounded,
                                                  color: colorScheme.primary,
                                                  size: 22,
                                                ),
                                              ),
                                              const SizedBox(width: 13),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      'Accede a tu cuenta',
                                                      style: theme
                                                          .textTheme
                                                          .titleLarge,
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      'Ingresa tus datos '
                                                      'para continuar.',
                                                      style: theme
                                                          .textTheme
                                                          .bodySmall,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 24),

                                          TextFormField(
                                            key: const Key('login-email-field'),
                                            controller: _emailController,
                                            enabled: !isBusy,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            textInputAction:
                                                TextInputAction.next,
                                            autofillHints: const [
                                              AutofillHints.username,
                                              AutofillHints.email,
                                            ],
                                            decoration: const InputDecoration(
                                              labelText: 'Correo electrónico',
                                              hintText: 'correo@ejemplo.com',
                                              prefixIcon: Icon(
                                                Icons.mail_outline_rounded,
                                              ),
                                            ),
                                            validator: (value) {
                                              if (!_showFieldErrors) {
                                                return null;
                                              }
                                              if (value == null ||
                                                  value.trim().isEmpty) {
                                                return 'Ingresa tu '
                                                    'correo electrónico.';
                                              }
                                              return null;
                                            },
                                            onChanged: (_) {
                                              authViewModel.clearError();
                                              if (_accessError != null) {
                                                setState(() {
                                                  _accessError = null;
                                                });
                                              }
                                            },
                                          ),

                                          const SizedBox(height: 16),

                                          TextFormField(
                                            key: const Key(
                                              'login-password-field',
                                            ),
                                            controller: _passwordController,
                                            enabled: !isBusy,
                                            obscureText: _obscurePassword,
                                            textInputAction:
                                                TextInputAction.done,
                                            autofillHints: const [
                                              AutofillHints.password,
                                            ],
                                            decoration: InputDecoration(
                                              labelText: 'Contraseña',
                                              prefixIcon: const Icon(
                                                Icons.lock_outline_rounded,
                                              ),
                                              suffixIcon: IconButton(
                                                tooltip: _obscurePassword
                                                    ? 'Mostrar contraseña'
                                                    : 'Ocultar contraseña',
                                                onPressed: isBusy
                                                    ? null
                                                    : () {
                                                        setState(() {
                                                          _obscurePassword =
                                                              !_obscurePassword;
                                                        });
                                                      },
                                                icon: Icon(
                                                  _obscurePassword
                                                      ? Icons
                                                            .visibility_outlined
                                                      : Icons
                                                            .visibility_off_outlined,
                                                ),
                                              ),
                                            ),
                                            validator: (value) {
                                              if (!_showFieldErrors) {
                                                return null;
                                              }
                                              if (value == null ||
                                                  value.isEmpty) {
                                                return 'Ingresa tu '
                                                    'contraseña.';
                                              }
                                              return null;
                                            },
                                            onChanged: (_) {
                                              authViewModel.clearError();
                                              if (_accessError != null) {
                                                setState(() {
                                                  _accessError = null;
                                                });
                                              }
                                            },
                                            onFieldSubmitted: (_) {
                                              if (!isBusy) {
                                                _submit();
                                              }
                                            },
                                          ),

                                          const SizedBox(height: 4),

                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              key: const Key(
                                                'login-forgot-password-button',
                                              ),
                                              onPressed: isBusy
                                                  ? null
                                                  : () {
                                                      _openPasswordReset(
                                                        authViewModel,
                                                      );
                                                    },
                                              child: const Text(
                                                '¿Olvidaste tu contraseña?',
                                              ),
                                            ),
                                          ),

                                          if (_accessError != null ||
                                              authViewModel.errorMessage !=
                                                  null) ...[
                                            const SizedBox(height: 16),
                                            _TimedLoginErrorBanner(
                                              key: ValueKey<int>(
                                                _errorAttemptRevision,
                                              ),
                                              message:
                                                  _accessError ??
                                                  authViewModel.errorMessage!,
                                              isAccessError:
                                                  _accessError != null,
                                              visibility: _errorVisibility,
                                              onDismiss: () {
                                                if (!mounted) {
                                                  return;
                                                }
                                                if (_accessError != null) {
                                                  setState(() {
                                                    _accessError = null;
                                                  });
                                                }
                                                authViewModel.clearError();
                                              },
                                            ),
                                          ],

                                          if (mustRestartVerifiedSession) ...[
                                            const SizedBox(height: 12),
                                            Text(
                                              'Tu correo ya está '
                                              'verificado. Vuelve a '
                                              'iniciar sesión para '
                                              'continuar de forma segura.',
                                              style: theme.textTheme.bodySmall,
                                            ),
                                            TextButton(
                                              key: const Key(
                                                'login-restart-verified-session',
                                              ),
                                              onPressed: isBusy
                                                  ? null
                                                  : _restartConventionalSignIn,
                                              child: const Text(
                                                'Volver a iniciar sesión',
                                              ),
                                            ),
                                          ],

                                          const SizedBox(height: 24),

                                          FilledButton.icon(
                                            key: const Key(
                                              'login-submit-button',
                                            ),
                                            onPressed:
                                                isBusy ||
                                                    mustRestartVerifiedSession
                                                ? null
                                                : _submit,
                                            icon: isBusy
                                                ? SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: colorScheme
                                                              .onPrimary,
                                                        ),
                                                  )
                                                : const Icon(
                                                    Icons.login_rounded,
                                                  ),
                                            label: Text(
                                              isBusy
                                                  ? 'Ingresando...'
                                                  : 'Iniciar sesión',
                                            ),
                                          ),

                                          const SizedBox(height: 20),

                                          Row(
                                            children: [
                                              Expanded(
                                                child: Divider(
                                                  color: colorScheme
                                                      .outlineVariant,
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ),
                                                child: Text(
                                                  'o continúa con',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Divider(
                                                  color: colorScheme
                                                      .outlineVariant,
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 16),

                                          OutlinedButton.icon(
                                            key: const Key(
                                              'login-google-button',
                                            ),
                                            onPressed:
                                                isBusy ||
                                                    mustRestartVerifiedSession
                                                ? null
                                                : _signInWithGoogle,
                                            style: OutlinedButton.styleFrom(
                                              minimumSize:
                                                  const Size.fromHeight(52),
                                            ),
                                            icon: Container(
                                              width: 28,
                                              height: 28,
                                              alignment: Alignment.center,
                                              decoration: BoxDecoration(
                                                color: Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Image.asset(
                                                'assets/branding/google_g_logo.png',
                                                key: const Key(
                                                  'login-google-logo',
                                                ),
                                                width: 24,
                                                height: 24,
                                                fit: BoxFit.contain,
                                                semanticLabel: 'Google',
                                              ),
                                            ),
                                            label: const Text(
                                              'Continuar con Google',
                                            ),
                                          ),

                                          if (biometricAvailable) ...[
                                            const SizedBox(height: 14),
                                            OutlinedButton(
                                              key: const Key(
                                                'login-biometric-button',
                                              ),
                                              onPressed: isBusy
                                                  ? null
                                                  : _signInWithBiometrics,
                                              style: OutlinedButton.styleFrom(
                                                minimumSize:
                                                    const Size.fromHeight(64),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 16,
                                                      vertical: 12,
                                                    ),
                                              ),
                                              child: const Row(
                                                children: [
                                                  Icon(
                                                    Icons.fingerprint_rounded,
                                                    size: 20,
                                                  ),
                                                  SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Ingresar con huella o '
                                                      'reconocimiento facial',
                                                      textAlign:
                                                          TextAlign.center,
                                                      softWrap: true,
                                                    ),
                                                  ),
                                                  SizedBox(width: 28),
                                                ],
                                              ),
                                            ),
                                          ],

                                          const SizedBox(height: 22),

                                          Row(
                                            children: [
                                              Expanded(
                                                child: Divider(
                                                  color: colorScheme
                                                      .outlineVariant,
                                                ),
                                              ),
                                              Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                    ),
                                                child: Text(
                                                  '¿Aún no tienes cuenta?',
                                                  style: theme
                                                      .textTheme
                                                      .bodySmall
                                                      ?.copyWith(
                                                        color: colorScheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Divider(
                                                  color: colorScheme
                                                      .outlineVariant,
                                                ),
                                              ),
                                            ],
                                          ),

                                          const SizedBox(height: 16),

                                          OutlinedButton.icon(
                                            key: const Key(
                                              'login-create-account-button',
                                            ),
                                            onPressed: isBusy
                                                ? null
                                                : () {
                                                    _openRegistration(
                                                      authViewModel,
                                                    );
                                                  },
                                            style: OutlinedButton.styleFrom(
                                              minimumSize:
                                                  const Size.fromHeight(52),
                                            ),
                                            icon: const Icon(
                                              Icons.person_add_alt_1_rounded,
                                            ),
                                            label: const Text('Crear cuenta'),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            FadeTransition(
                              opacity: _footerOpacity,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.shield_outlined,
                                    size: 18,
                                    color: colorScheme.primary,
                                  ),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      'Sendaris utiliza tu cuenta '
                                      'para mantener tus registros '
                                      'disponibles de forma privada.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            height: 1.4,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            Align(
              alignment: Alignment.topCenter,
              child: AuthTopBar(themeModeController: themeModeController),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso temporal utilizado para errores reales de autenticación.
///
/// Las cancelaciones biométricas nunca crean este componente.
final class _TimedLoginErrorBanner extends StatefulWidget {
  const _TimedLoginErrorBanner({
    required this.message,
    required this.isAccessError,
    required this.visibility,
    required this.onDismiss,
    super.key,
  });

  final String message;
  final bool isAccessError;
  final Duration visibility;
  final VoidCallback onDismiss;

  @override
  State<_TimedLoginErrorBanner> createState() => _TimedLoginErrorBannerState();
}

final class _TimedLoginErrorBannerState extends State<_TimedLoginErrorBanner> {
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _startDismissal();
  }

  void _startDismissal() {
    _dismissTimer?.cancel();

    _dismissTimer = Timer(widget.visibility, () {
      if (!mounted) {
        return;
      }

      widget.onDismiss();
    });
  }

  @override
  void didUpdateWidget(covariant _TimedLoginErrorBanner oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.message != widget.message ||
        oldWidget.isAccessError != widget.isAccessError ||
        oldWidget.visibility != widget.visibility) {
      _startDismissal();
    }
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('login-error-banner'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.errorContainer.withValues(alpha: isDark ? 0.64 : 0.86),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: colors.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.message,
                key: widget.isAccessError
                    ? const Key('login-account-access-error')
                    : const Key('login-authentication-error'),
                style: TextStyle(color: colors.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
