import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/theme/theme_mode_controller.dart';
import '../../domain/models/password_requirements.dart';
import '../viewmodels/auth_view_model.dart';
import '../widgets/auth_top_bar.dart';

class RegistrationEmailView extends StatefulWidget {
  const RegistrationEmailView({
    required this.onBack,
    required this.onLogin,
    this.initialVerificationPending = false,
    this.initialVerificationEmail,
    this.onUseAnotherEmailRequested,
    super.key,
  });

  final VoidCallback onBack;

  final VoidCallback onLogin;

  final bool initialVerificationPending;

  final String? initialVerificationEmail;

  final VoidCallback? onUseAnotherEmailRequested;

  @override
  State<RegistrationEmailView> createState() => _RegistrationEmailViewState();
}

class _RegistrationEmailViewState extends State<RegistrationEmailView> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();

  final _passwordController = TextEditingController();

  final _passwordConfirmationController = TextEditingController();

  PasswordRequirements _requirements = PasswordRequirements.evaluate('');

  bool _registrationCreated = false;

  bool _obscurePassword = true;

  bool _obscurePasswordConfirmation = true;

  bool _passwordWasEdited = false;

  String? _sentEmail;

  String? _verificationFeedback;

  @override
  void initState() {
    super.initState();

    if (widget.initialVerificationPending) {
      _registrationCreated = true;
      _sentEmail = widget.initialVerificationEmail;
    }
  }

  @override
  void didUpdateWidget(covariant RegistrationEmailView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.initialVerificationPending &&
        (!oldWidget.initialVerificationPending ||
            oldWidget.initialVerificationEmail !=
                widget.initialVerificationEmail)) {
      _registrationCreated = true;
      _sentEmail = widget.initialVerificationEmail;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();

    super.dispose();
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Ingresa tu correo electrónico.';
    }

    final validFormat = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);

    if (!validFormat) {
      return 'Ingresa un correo electrónico válido.';
    }

    return null;
  }

  void _handleEmailChanged(String value, AuthViewModel authViewModel) {
    authViewModel.clearError();

    setState(() {
      _verificationFeedback = null;
    });
  }

  void _handlePasswordChanged(String value, AuthViewModel authViewModel) {
    authViewModel.clearError();

    setState(() {
      _passwordWasEdited = true;
      _requirements = PasswordRequirements.evaluate(value);
      _verificationFeedback = null;
    });
  }

  void _handlePasswordConfirmationChanged(
    String value,
    AuthViewModel authViewModel,
  ) {
    authViewModel.clearError();

    setState(() {
      _verificationFeedback = null;
    });
  }

  bool _passwordsMatch() {
    final confirmation = _passwordConfirmationController.text;

    return confirmation.isNotEmpty && confirmation == _passwordController.text;
  }

  bool _canCreateAccount(AuthViewModel authViewModel) {
    return !authViewModel.isLoading &&
        _emailController.text.trim().isNotEmpty &&
        _requirements.isValid &&
        _passwordsMatch();
  }

  Future<void> _createAccount(AuthViewModel authViewModel) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_canCreateAccount(authViewModel)) {
      return;
    }

    authViewModel.clearError();

    final success = await authViewModel.createUnverifiedAccount(
      email: _emailController.text,
      password: _passwordController.text,
      passwordConfirmation: _passwordConfirmationController.text,
    );

    if (!mounted || !success) {
      return;
    }

    final createdEmail =
        authViewModel.currentUserEmail ?? _emailController.text.trim();

    _passwordController.clear();
    _passwordConfirmationController.clear();

    setState(() {
      _sentEmail = createdEmail;
      _registrationCreated = true;
      _requirements = PasswordRequirements.evaluate('');
      _passwordWasEdited = false;
      _verificationFeedback = null;
    });
  }

  Future<void> _resendVerification(AuthViewModel authViewModel) async {
    authViewModel.clearError();

    setState(() {
      _verificationFeedback = null;
    });

    final success = await authViewModel.sendEmailVerification();

    if (!mounted || !success) {
      return;
    }

    setState(() {
      _verificationFeedback = 'Enviamos nuevamente el correo de verificación.';
    });
  }

  Future<void> _checkVerification(AuthViewModel authViewModel) async {
    authViewModel.clearError();

    setState(() {
      _verificationFeedback = null;
    });

    final verified = await authViewModel.refreshEmailVerificationStatus();

    if (!mounted) {
      return;
    }

    if (verified) {
      setState(() {
        _verificationFeedback =
            'Correo verificado correctamente. '
            'Estamos preparando tu acceso.';
      });

      return;
    }

    if (authViewModel.errorMessage == null) {
      setState(() {
        _verificationFeedback =
            'Aún no detectamos la verificación. '
            'Confirma tu correo y vuelve a intentarlo.';
      });
    }
  }

  Future<void> _useAnotherEmail(AuthViewModel authViewModel) async {
    authViewModel.clearError();

    setState(() {
      _verificationFeedback = null;
    });

    if (authViewModel.isAuthenticated) {
      final cancelled = await authViewModel.cancelUnverifiedAccount();

      if (!mounted || !cancelled) {
        return;
      }
    }

    widget.onUseAnotherEmailRequested?.call();

    _emailController.clear();
    _passwordController.clear();
    _passwordConfirmationController.clear();

    if (!mounted) {
      return;
    }

    setState(() {
      _registrationCreated = false;
      _sentEmail = null;
      _requirements = PasswordRequirements.evaluate('');
      _passwordWasEdited = false;
      _obscurePassword = true;
      _obscurePasswordConfirmation = true;
      _verificationFeedback = null;
    });
  }

  Future<void> _returnToLogin(AuthViewModel authViewModel) async {
    authViewModel.clearError();

    if (authViewModel.isAuthenticated) {
      final signedOut = await authViewModel.signOut();

      if (!mounted || !signedOut) {
        return;
      }
    }

    if (!mounted) {
      return;
    }

    widget.onLogin();
  }

  void _handleBack(AuthViewModel authViewModel) {
    if (authViewModel.isLoading) {
      return;
    }

    if (_registrationCreated || authViewModel.isAuthenticated) {
      _returnToLogin(authViewModel);

      return;
    }

    authViewModel.clearError();
    widget.onBack();
  }

  double _passwordStrengthProgress() {
    if (!_passwordWasEdited || _passwordController.text.isEmpty) {
      return 0;
    }

    var fulfilled = 0;

    if (_requirements.hasMinimumLength) {
      fulfilled++;
    }

    if (_requirements.hasUppercase) {
      fulfilled++;
    }

    if (_requirements.hasLowercase) {
      fulfilled++;
    }

    if (_requirements.hasNumber) {
      fulfilled++;
    }

    if (_requirements.hasSpecialCharacter) {
      fulfilled++;
    }

    return fulfilled / 5;
  }

  String _passwordStrengthLabel() {
    if (!_passwordWasEdited || _passwordController.text.isEmpty) {
      return 'Sin evaluar';
    }

    final progress = _passwordStrengthProgress();

    if (progress <= 0.4) {
      return 'Débil';
    }

    if (progress <= 0.6) {
      return 'Media';
    }

    if (progress < 1) {
      return 'Buena';
    }

    return 'Fuerte';
  }

  @override
  Widget build(BuildContext context) {
    final authViewModel = context.watch<AuthViewModel>();

    final themeModeController = context.watch<ThemeModeController?>();

    final effectiveRegistrationCreated =
        _registrationCreated || widget.initialVerificationPending;

    final effectiveSentEmail =
        _sentEmail ??
        widget.initialVerificationEmail ??
        authViewModel.currentUserEmail;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack(authViewModel);
        }
      },
      child: Scaffold(
        key: const Key('registration-email-view'),
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 78, 24, 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: _RegistrationContent(
                        registrationCreated: effectiveRegistrationCreated,
                        sentEmail: effectiveSentEmail,
                        formKey: _formKey,
                        emailController: _emailController,
                        passwordController: _passwordController,
                        passwordConfirmationController:
                            _passwordConfirmationController,
                        authViewModel: authViewModel,
                        requirements: _requirements,
                        passwordWasEdited: _passwordWasEdited,
                        passwordsMatch: _passwordsMatch(),
                        obscurePassword: _obscurePassword,
                        obscurePasswordConfirmation:
                            _obscurePasswordConfirmation,
                        strengthLabel: _passwordStrengthLabel(),
                        strengthProgress: _passwordStrengthProgress(),
                        verificationFeedback: _verificationFeedback,
                        emailValidator: _validateEmail,
                        canCreateAccount: _canCreateAccount(authViewModel),
                        onEmailChanged: (value) {
                          _handleEmailChanged(value, authViewModel);
                        },
                        onPasswordChanged: (value) {
                          _handlePasswordChanged(value, authViewModel);
                        },
                        onPasswordConfirmationChanged: (value) {
                          _handlePasswordConfirmationChanged(
                            value,
                            authViewModel,
                          );
                        },
                        onTogglePasswordVisibility: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                        onTogglePasswordConfirmationVisibility: () {
                          setState(() {
                            _obscurePasswordConfirmation =
                                !_obscurePasswordConfirmation;
                          });
                        },
                        onCreateAccount: () {
                          _createAccount(authViewModel);
                        },
                        onCheckVerification: () {
                          _checkVerification(authViewModel);
                        },
                        onResendVerification: () {
                          _resendVerification(authViewModel);
                        },
                        onUseAnotherEmail: () {
                          _useAnotherEmail(authViewModel);
                        },
                        onLogin: () {
                          _returnToLogin(authViewModel);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: AuthTopBar(
                  onBack: () {
                    _handleBack(authViewModel);
                  },
                  backEnabled: !authViewModel.isLoading,
                  backButtonKey: const Key('registration-email-back-button'),
                  themeModeController: themeModeController,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RegistrationContent extends StatelessWidget {
  const _RegistrationContent({
    required this.registrationCreated,
    required this.sentEmail,
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordConfirmationController,
    required this.authViewModel,
    required this.requirements,
    required this.passwordWasEdited,
    required this.passwordsMatch,
    required this.obscurePassword,
    required this.obscurePasswordConfirmation,
    required this.strengthLabel,
    required this.strengthProgress,
    required this.verificationFeedback,
    required this.emailValidator,
    required this.canCreateAccount,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onPasswordConfirmationChanged,
    required this.onTogglePasswordVisibility,
    required this.onTogglePasswordConfirmationVisibility,
    required this.onCreateAccount,
    required this.onCheckVerification,
    required this.onResendVerification,
    required this.onUseAnotherEmail,
    required this.onLogin,
  });

  final bool registrationCreated;

  final String? sentEmail;

  final GlobalKey<FormState> formKey;

  final TextEditingController emailController;

  final TextEditingController passwordController;

  final TextEditingController passwordConfirmationController;

  final AuthViewModel authViewModel;

  final PasswordRequirements requirements;

  final bool passwordWasEdited;

  final bool passwordsMatch;

  final bool obscurePassword;

  final bool obscurePasswordConfirmation;

  final String strengthLabel;

  final double strengthProgress;

  final String? verificationFeedback;

  final FormFieldValidator<String> emailValidator;

  final bool canCreateAccount;

  final ValueChanged<String> onEmailChanged;

  final ValueChanged<String> onPasswordChanged;

  final ValueChanged<String> onPasswordConfirmationChanged;

  final VoidCallback onTogglePasswordVisibility;

  final VoidCallback onTogglePasswordConfirmationVisibility;

  final VoidCallback onCreateAccount;

  final VoidCallback onCheckVerification;

  final VoidCallback onResendVerification;

  final VoidCallback onUseAnotherEmail;

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 82,
            height: 82,
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.90),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(19),
              child: Image.asset(
                'assets/branding/sendaris_app_icon.png',
                key: const Key('registration-email-brand-icon'),
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (registrationCreated)
          _RegistrationVerificationPending(
            email: sentEmail ?? 'Correo pendiente de verificación',
            authViewModel: authViewModel,
            verificationFeedback: verificationFeedback,
            onCheckVerification: onCheckVerification,
            onResendVerification: onResendVerification,
            onUseAnotherEmail: onUseAnotherEmail,
            onLogin: onLogin,
          )
        else
          _RegistrationAccountForm(
            formKey: formKey,
            emailController: emailController,
            passwordController: passwordController,
            passwordConfirmationController: passwordConfirmationController,
            authViewModel: authViewModel,
            requirements: requirements,
            passwordWasEdited: passwordWasEdited,
            passwordsMatch: passwordsMatch,
            obscurePassword: obscurePassword,
            obscurePasswordConfirmation: obscurePasswordConfirmation,
            strengthLabel: strengthLabel,
            strengthProgress: strengthProgress,
            emailValidator: emailValidator,
            canCreateAccount: canCreateAccount,
            onEmailChanged: onEmailChanged,
            onPasswordChanged: onPasswordChanged,
            onPasswordConfirmationChanged: onPasswordConfirmationChanged,
            onTogglePasswordVisibility: onTogglePasswordVisibility,
            onTogglePasswordConfirmationVisibility:
                onTogglePasswordConfirmationVisibility,
            onCreateAccount: onCreateAccount,
            onLogin: onLogin,
          ),
      ],
    );
  }
}

class _RegistrationAccountForm extends StatelessWidget {
  const _RegistrationAccountForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.passwordConfirmationController,
    required this.authViewModel,
    required this.requirements,
    required this.passwordWasEdited,
    required this.passwordsMatch,
    required this.obscurePassword,
    required this.obscurePasswordConfirmation,
    required this.strengthLabel,
    required this.strengthProgress,
    required this.emailValidator,
    required this.canCreateAccount,
    required this.onEmailChanged,
    required this.onPasswordChanged,
    required this.onPasswordConfirmationChanged,
    required this.onTogglePasswordVisibility,
    required this.onTogglePasswordConfirmationVisibility,
    required this.onCreateAccount,
    required this.onLogin,
  });

  final GlobalKey<FormState> formKey;

  final TextEditingController emailController;

  final TextEditingController passwordController;

  final TextEditingController passwordConfirmationController;

  final AuthViewModel authViewModel;

  final PasswordRequirements requirements;

  final bool passwordWasEdited;

  final bool passwordsMatch;

  final bool obscurePassword;

  final bool obscurePasswordConfirmation;

  final String strengthLabel;

  final double strengthProgress;

  final FormFieldValidator<String> emailValidator;

  final bool canCreateAccount;

  final ValueChanged<String> onEmailChanged;

  final ValueChanged<String> onPasswordChanged;

  final ValueChanged<String> onPasswordConfirmationChanged;

  final VoidCallback onTogglePasswordVisibility;

  final VoidCallback onTogglePasswordConfirmationVisibility;

  final VoidCallback onCreateAccount;

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Crear cuenta',
            key: const Key('registration-email-title'),
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Verifica tu correo para continuar',
            key: const Key('registration-email-subtitle'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Ingresa tu correo y define una contraseña segura. '
            'Después enviaremos un correo para verificar '
            'que la dirección te pertenece.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 30),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    key: const Key('registration-email-field'),
                    controller: emailController,
                    enabled: !authViewModel.isLoading,
                    autofocus: true,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [
                      AutofillHints.email,
                      AutofillHints.username,
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'correo@ejemplo.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    validator: emailValidator,
                    onChanged: onEmailChanged,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('registration-password-field'),
                    controller: passwordController,
                    enabled: !authViewModel.isLoading,
                    obscureText: obscurePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        key: const Key(
                          'registration-password-visibility-button',
                        ),
                        onPressed: authViewModel.isLoading
                            ? null
                            : onTogglePasswordVisibility,
                        icon: Icon(
                          obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    onChanged: onPasswordChanged,
                  ),
                  const SizedBox(height: 14),
                  _PasswordStrengthIndicator(
                    label: strengthLabel,
                    progress: strengthProgress,
                  ),
                  const SizedBox(height: 14),
                  _PasswordRequirementsCard(
                    requirements: requirements,
                    active: passwordWasEdited,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('registration-password-confirmation-field'),
                    controller: passwordConfirmationController,
                    enabled: !authViewModel.isLoading,
                    obscureText: obscurePasswordConfirmation,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Confirmar contraseña',
                      prefixIcon: const Icon(Icons.lock_reset_rounded),
                      suffixIcon: IconButton(
                        key: const Key(
                          'registration-password-confirmation-visibility-button',
                        ),
                        onPressed: authViewModel.isLoading
                            ? null
                            : onTogglePasswordConfirmationVisibility,
                        icon: Icon(
                          obscurePasswordConfirmation
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    onChanged: onPasswordConfirmationChanged,
                    onFieldSubmitted: (_) {
                      if (canCreateAccount) {
                        onCreateAccount();
                      }
                    },
                  ),
                  if (passwordConfirmationController.text.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _PasswordMatchIndicator(matches: passwordsMatch),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.verified_user_outlined,
                        size: 19,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'La cuenta solo tendrá acceso a '
                          'Sendaris después de verificar '
                          'el correo electrónico.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (authViewModel.errorMessage != null) ...[
                    const SizedBox(height: 18),
                    _RegistrationEmailError(
                      message: authViewModel.errorMessage!,
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    key: const Key('registration-create-account-button'),
                    onPressed: canCreateAccount ? onCreateAccount : null,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: authViewModel.isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(
                      authViewModel.isLoading
                          ? 'Creando cuenta...'
                          : 'Crear cuenta',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextButton(
            key: const Key('registration-email-login-button'),
            onPressed: authViewModel.isLoading ? null : onLogin,
            child: const Text('¿Ya tienes una cuenta? Iniciar sesión'),
          ),
        ],
      ),
    );
  }
}

class _RegistrationVerificationPending extends StatelessWidget {
  const _RegistrationVerificationPending({
    required this.email,
    required this.authViewModel,
    required this.verificationFeedback,
    required this.onCheckVerification,
    required this.onResendVerification,
    required this.onUseAnotherEmail,
    required this.onLogin,
  });

  final String email;

  final AuthViewModel authViewModel;

  final String? verificationFeedback;

  final VoidCallback onCheckVerification;

  final VoidCallback onResendVerification;

  final VoidCallback onUseAnotherEmail;

  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Column(
      key: const Key('registration-verification-pending'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.72),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.mark_email_read_outlined,
              size: 36,
              color: colorScheme.primary,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Revisa tu correo',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Enviamos un correo de verificación a:',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            email,
            key: const Key('registration-email-sent-address'),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 22),
        Text(
          'Abre el mensaje y confirma tu dirección de correo. '
          'Después vuelve a Sendaris y comprueba la verificación.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        if (authViewModel.errorMessage != null) ...[
          const SizedBox(height: 20),
          _RegistrationEmailError(message: authViewModel.errorMessage!),
        ],
        if (verificationFeedback != null) ...[
          const SizedBox(height: 20),
          _RegistrationStatusMessage(message: verificationFeedback!),
        ],
        const SizedBox(height: 30),
        FilledButton.icon(
          key: const Key('registration-check-verification-button'),
          onPressed: authViewModel.isLoading ? null : onCheckVerification,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: authViewModel.isLoading
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.onPrimary,
                  ),
                )
              : const Icon(Icons.verified_rounded),
          label: Text(
            authViewModel.isLoading
                ? 'Comprobando...'
                : 'Ya verifiqué mi correo',
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          key: const Key('registration-resend-verification-button'),
          onPressed: authViewModel.isLoading ? null : onResendVerification,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reenviar correo'),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('registration-email-use-other-button'),
          onPressed: authViewModel.isLoading ? null : onUseAnotherEmail,
          child: const Text('Cambiar correo'),
        ),
        TextButton(
          key: const Key('registration-email-login-after-send-button'),
          onPressed: authViewModel.isLoading ? null : onLogin,
          child: const Text('Volver a iniciar sesión'),
        ),
      ],
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({
    required this.label,
    required this.progress,
  });

  final String label;

  final double progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Fortaleza', style: theme.textTheme.labelLarge),
            const Spacer(),
            Text(
              label,
              key: const Key('registration-password-strength-label'),
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          key: const Key('registration-password-strength-progress'),
          value: progress,
          minHeight: 7,
          borderRadius: BorderRadius.circular(999),
        ),
      ],
    );
  }
}

class _PasswordRequirementsCard extends StatelessWidget {
  const _PasswordRequirementsCard({
    required this.requirements,
    required this.active,
  });

  final PasswordRequirements requirements;

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('registration-password-requirements'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _PasswordRequirementRow(
            key: const Key('registration-password-requirement-minimum-length'),
            label: '12 caracteres como mínimo',
            fulfilled: requirements.hasMinimumLength,
            active: active,
          ),
          _PasswordRequirementRow(
            key: const Key('registration-password-requirement-uppercase'),
            label: 'Una letra mayúscula',
            fulfilled: requirements.hasUppercase,
            active: active,
          ),
          _PasswordRequirementRow(
            key: const Key('registration-password-requirement-lowercase'),
            label: 'Una letra minúscula',
            fulfilled: requirements.hasLowercase,
            active: active,
          ),
          _PasswordRequirementRow(
            key: const Key('registration-password-requirement-number'),
            label: 'Un número',
            fulfilled: requirements.hasNumber,
            active: active,
          ),
          _PasswordRequirementRow(
            key: const Key(
              'registration-password-requirement-special-character',
            ),
            label: 'Un símbolo',
            fulfilled: requirements.hasSpecialCharacter,
            active: active,
          ),
        ],
      ),
    );
  }
}

class _PasswordRequirementRow extends StatelessWidget {
  const _PasswordRequirementRow({
    required this.label,
    required this.fulfilled,
    required this.active,
    super.key,
  });

  final String label;

  final bool fulfilled;

  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final icon = !active
        ? Icons.radio_button_unchecked_rounded
        : fulfilled
        ? Icons.check_circle_rounded
        : Icons.cancel_outlined;

    final color = !active
        ? colorScheme.onSurfaceVariant
        : fulfilled
        ? colorScheme.primary
        : colorScheme.error;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _PasswordMatchIndicator extends StatelessWidget {
  const _PasswordMatchIndicator({required this.matches});

  final bool matches;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final color = matches ? colorScheme.primary : colorScheme.error;

    return Row(
      key: const Key('registration-password-match-indicator'),
      children: [
        Icon(
          matches ? Icons.check_circle_rounded : Icons.cancel_outlined,
          size: 20,
          color: color,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            matches
                ? 'Las contraseñas coinciden.'
                : 'Las contraseñas no coinciden.',
            style: theme.textTheme.bodyMedium?.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class _RegistrationStatusMessage extends StatelessWidget {
  const _RegistrationStatusMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('registration-verification-feedback'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: colorScheme.onPrimaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onPrimaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RegistrationEmailError extends StatelessWidget {
  const _RegistrationEmailError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('registration-email-error'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
