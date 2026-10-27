import 'dart:async';

import 'package:flutter/material.dart';

import 'account_linked_session_recovery_coordinator.dart';

/// Autenticacion de A mediante correo y contrasena.
///
/// El callback debe utilizar exclusivamente el contexto
/// Firebase reservado para la cuenta vinculada.
typedef PasswordLinkedRecovery = Future<AccountLinkedRecoveryResult> Function(
  String email,
  String password,
);

/// Autenticacion de A mediante Google.
///
/// La implementacion debe verificar que el UID
/// corresponda a la vinculacion existente.
typedef GoogleLinkedRecovery = Future<AccountLinkedRecoveryResult> Function();

/// Pantalla para recuperar una sesion Firebase perdida.
///
/// No concede acceso privado ni ejecuta operaciones
/// biometricas. Es responsabilidad del componente raiz:
///
/// - Elegir el contexto Firebase reservado.
/// - Comprobar el UID vinculado.
/// - Limpiar sesiones equivocadas de forma segura.
/// - Verificar nuevamente Android Keystore.
/// - Exigir autorizacion biometrica para acceder.
///
/// [onSessionRecovered] confirma solamente que la
/// recuperacion de Firebase termino correctamente.
/// No representa una autorizacion privada.
final class AccountLinkedSessionRecoveryScreen extends StatefulWidget {
  const AccountLinkedSessionRecoveryScreen({
    required this.onPasswordRecovery,
    required this.onSessionRecovered,
    this.onGoogleRecovery,
    super.key,
  });

  final PasswordLinkedRecovery onPasswordRecovery;
  final GoogleLinkedRecovery? onGoogleRecovery;
  final VoidCallback onSessionRecovered;

  @override
  State<AccountLinkedSessionRecoveryScreen> createState() =>
      _AccountLinkedSessionRecoveryScreenState();
}

final class _AccountLinkedSessionRecoveryScreenState
    extends State<AccountLinkedSessionRecoveryScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _working = false;
  bool _completed = false;
  bool _obscurePassword = true;

  String? _message;

  bool get _canSubmit => !_working && !_completed;

  Future<void> _recover({
    required Future<AccountLinkedRecoveryResult> Function() operation,
  }) async {
    if (!_canSubmit) {
      return;
    }

    setState(() {
      _working = true;
      _message = null;
    });

    AccountLinkedRecoveryResult result;

    try {
      result = await operation();
    } catch (_) {
      result = AccountLinkedRecoveryResult.unavailable;
    }

    if (!mounted) {
      return;
    }

    if (result == AccountLinkedRecoveryResult.recovered) {
      setState(() {
        _working = false;
        _completed = true;
        _message = null;
      });

      // No concede acceso privado.
      //
      // La raiz debe revalidar el estado Firebase
      // y reconstruir su configuracion segura.
      widget.onSessionRecovered();

      return;
    }

    setState(() {
      _working = false;
      _message = _messageFor(result);
    });
  }

  Future<void> _recoverWithPassword() async {
    if (!_canSubmit) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _message = 'Ingresa tu correo y contraseña.';
      });

      return;
    }

    // La pantalla no conserva la contrasena despues
    // de iniciar el intento de autenticacion.
    _passwordController.clear();

    await _recover(operation: () => widget.onPasswordRecovery(email, password));
  }

  Future<void> _recoverWithGoogle() async {
    final operation = widget.onGoogleRecovery;

    if (!_canSubmit || operation == null) {
      return;
    }

    _passwordController.clear();

    await _recover(operation: operation);
  }

  String _messageFor(AccountLinkedRecoveryResult result) {
    return switch (result) {
      AccountLinkedRecoveryResult.recovered =>
        'La sesión Firebase fue recuperada.',
      AccountLinkedRecoveryResult.busy =>
        'Ya existe una verificación en curso.',
      AccountLinkedRecoveryResult.unavailable =>
        'No fue posible completar la recuperación. '
            'Comprueba tu conexión e inténtalo nuevamente.',
      AccountLinkedRecoveryResult.bindingUnavailable =>
        'No se pudo comprobar la vinculación biométrica '
            'del dispositivo. El acceso permanece protegido.',
      AccountLinkedRecoveryResult.bindingChanged =>
        'La vinculación biométrica cambió durante '
            'la recuperación. El acceso permanece protegido.',
      AccountLinkedRecoveryResult.alreadyAuthenticated =>
        'Ya existe una sesión en el contexto reservado. '
            'Es necesario comprobarla antes de continuar.',
      AccountLinkedRecoveryResult.otherContextOccupied =>
        'Hay otro contexto de autenticación ocupado. '
            'No es posible recuperar la cuenta de forma segura.',
      AccountLinkedRecoveryResult.accountMismatch =>
        'La cuenta autenticada no coincide con '
            'la cuenta vinculada a este dispositivo.',
      AccountLinkedRecoveryResult.identityChanged =>
        'La identidad cambió durante la recuperación. '
            'Comprueba tus credenciales e inténtalo nuevamente.',
      AccountLinkedRecoveryResult.sessionInvalid =>
        'Firebase no pudo confirmar una sesión válida '
            'con el correo verificado.',
      AccountLinkedRecoveryResult.cancelled =>
        'La recuperación fue cancelada. '
            'Puedes volver a intentarlo.',
    };
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      key: const Key('linked-recovery-screen'),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Recuperar acceso'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.verified_user_outlined,
                      color: colors.onPrimaryContainer,
                      size: 32,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Recupera tu cuenta vinculada',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'La vinculación biométrica permanece '
                  'guardada en este dispositivo, pero es '
                  'necesario confirmar nuevamente tu sesión.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Utiliza las credenciales de la misma '
                  'cuenta que vinculaste anteriormente.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),
                AutofillGroup(
                  child: Column(
                    children: [
                      TextField(
                        key: const Key('linked-recovery-email'),
                        controller: _emailController,
                        enabled: _canSubmit,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          prefixIcon: Icon(Icons.mail_outline_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        key: const Key('linked-recovery-password'),
                        controller: _passwordController,
                        enabled: _canSubmit,
                        obscureText: _obscurePassword,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        onSubmitted: (_) {
                          unawaited(_recoverWithPassword());
                        },
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          suffixIcon: IconButton(
                            key: const Key(
                              'linked-recovery-password-visibility',
                            ),
                            tooltip: _obscurePassword
                                ? 'Mostrar contraseña'
                                : 'Ocultar contraseña',
                            onPressed: !_canSubmit
                                ? null
                                : () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const Key('linked-recovery-password-submit'),
                  onPressed: _canSubmit
                      ? () {
                          unawaited(_recoverWithPassword());
                        }
                      : null,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Recuperar con contraseña'),
                ),
                if (widget.onGoogleRecovery != null) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    key: const Key('linked-recovery-google-submit'),
                    onPressed: _canSubmit
                        ? () {
                            unawaited(_recoverWithGoogle());
                          }
                        : null,
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('Continuar con Google'),
                  ),
                ],
                if (_working) ...[
                  const SizedBox(height: 22),
                  const LinearProgressIndicator(
                    key: Key('linked-recovery-progress'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Verificando tu identidad...',
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (_message != null) ...[
                  const SizedBox(height: 22),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _message!,
                      key: const Key('linked-recovery-message'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Text(
                  'Recuperar la sesión no desbloquea '
                  'automáticamente la aplicación. '
                  'Después deberás confirmar tu identidad '
                  'mediante la seguridad del dispositivo.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
