import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/animation/animated_entrance.dart';
import '../../../../app/theme/sendaris_section_label.dart';
import '../../../../app/theme/theme_mode_controller.dart';
import '../../../../app/widgets/sendaris_primary_app_bar.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../tracking/presentation/viewmodels/tracking_view_model.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() {
    return _SettingsViewState();
  }
}

class _SettingsViewState extends State<SettingsView> {
  bool _isDeletingAccount = false;

  Future<void> _confirmSignOut(
    BuildContext context,
    AuthViewModel authViewModel,
    TrackingViewModel trackingViewModel,
  ) async {
    if (authViewModel.isLoading ||
        trackingViewModel.isLoading ||
        _isDeletingAccount) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¿Cerrar sesión?'),
          content: const Text(
            'Se cerrará tu sesión actual. '
            'Podrás volver a ingresar con tu cuenta.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton.icon(
              key: const Key('settings-confirm-sign-out-button'),
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    final success = await authViewModel.signOut();

    if (success) {
      trackingViewModel.clearAuthenticationState();
      return;
    }

    if (context.mounted) {
      _showErrorMessage(
        context,
        authViewModel.errorMessage ?? 'No fue posible cerrar la sesión.',
      );
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AuthViewModel authViewModel,
    TrackingViewModel trackingViewModel,
  ) async {
    if (_isDeletingAccount ||
        authViewModel.isLoading ||
        trackingViewModel.isLoading ||
        !authViewModel.isAuthenticated) {
      return;
    }

    // Captura la cuenta que inicia el procedimiento.
    //
    // La autorización de esta cuenta nunca debe
    // utilizarse para eliminar datos de otra.
    final initiatingUserId = authViewModel.currentUserId;
    final initiatingAuthenticated = authViewModel.isAuthenticated;

    // Este indicador permanece invalidado incluso
    // cuando el usuario cambia A -> B -> A.
    //
    // No es suficiente comparar el UID al finalizar.
    var authenticationContextChanged = false;

    void observeAuthenticationContext() {
      if (authViewModel.currentUserId != initiatingUserId ||
          authViewModel.isAuthenticated != initiatingAuthenticated) {
        authenticationContextChanged = true;
      }
    }

    bool isOriginalAuthenticationContext() {
      observeAuthenticationContext();
      return !authenticationContextChanged;
    }

    // El observador se activa antes de mostrar
    // cualquier diálogo o esperar una operación.
    authViewModel.addListener(observeAuthenticationContext);

    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final colorScheme = Theme.of(dialogContext).colorScheme;

          return AlertDialog(
            key: const Key('settings-delete-account-warning-dialog'),
            icon: Icon(Icons.warning_amber_rounded, color: colorScheme.error),
            title: const Text('¿Eliminar cuenta definitivamente?'),
            content: const Text(
              'Se eliminarán de forma permanente '
              'todos tus seguimientos, eventos, rutinas, '
              'estados de rutina y tu cuenta de acceso.\n\n'
              'Esta acción no se puede deshacer.',
            ),
            actions: [
              TextButton(
                key: const Key('settings-cancel-delete-account-button'),
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancelar'),
              ),
              FilledButton(
                key: const Key('settings-continue-delete-account-button'),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Continuar'),
              ),
            ],
          );
        },
      );

      if (confirmed != true ||
          !context.mounted ||
          !isOriginalAuthenticationContext()) {
        return;
      }

      // Las cuentas con proveedor Google pueden confirmar
      // su identidad sin disponer de una contraseña local.
      //
      // Si ambos proveedores están vinculados, se utiliza
      // Google en este incremento. Las cuentas tradicionales
      // conservan el procedimiento mediante contraseña.
      final useGoogle = authViewModel.canReauthenticateWithGoogle;

      String? password;

      if (!useGoogle) {
        password = await _requestDeletionPassword(context);

        if (password == null ||
            !context.mounted ||
            !isOriginalAuthenticationContext()) {
          return;
        }
      }

      if (!context.mounted || !isOriginalAuthenticationContext()) {
        return;
      }

      setState(() {
        _isDeletingAccount = true;
      });

      // Ningún dato se elimina antes de que Firebase
      // confirme nuevamente la identidad vigente.
      final reauthenticated = useGoogle
          ? await authViewModel.reauthenticateWithGoogle()
          : await authViewModel.reauthenticateWithPassword(password: password!);

      // Aunque Firebase haya confirmado la identidad
      // de A, la operación no puede continuar si la
      // sesión cambió a B o atravesó A -> B -> A.
      if (!isOriginalAuthenticationContext()) {
        return;
      }

      if (!reauthenticated) {
        // Una cancelación del selector Google no es un
        // error y jamás autoriza una eliminación.
        if (useGoogle && authViewModel.errorMessage == null) {
          return;
        }

        if (context.mounted) {
          _showErrorMessage(
            context,
            authViewModel.errorMessage ??
                'No fue posible confirmar tu identidad.',
          );

          authViewModel.clearError();
        }

        return;
      }

      // Solo se inicia la limpieza cuando la cuenta
      // autorizada continúa autenticada.
      final dataDeleted = await trackingViewModel.deleteAllProfilesForAccount();

      // Una limpieza iniciada en A no debe autorizar
      // posteriormente la eliminación de Authentication
      // si la sesión cambió durante el proceso.
      if (!isOriginalAuthenticationContext()) {
        return;
      }

      if (!dataDeleted) {
        if (context.mounted) {
          _showErrorMessage(
            context,
            trackingViewModel.errorMessage ??
                'No fue posible eliminar todos '
                    'los datos de la cuenta. '
                    'La cuenta no fue eliminada.',
          );
        }

        return;
      }

      // Última comprobación antes de invocar
      // la eliminación de Firebase Authentication.
      if (!isOriginalAuthenticationContext()) {
        return;
      }

      final accountDeleted = await authViewModel.deleteCurrentAccount();

      if (!accountDeleted) {
        // No se muestran errores pertenecientes a
        // otra sesión que pudo iniciar mientras tanto.
        if (!isOriginalAuthenticationContext()) {
          return;
        }

        if (context.mounted) {
          final authMessage = authViewModel.errorMessage;

          _showErrorMessage(
            context,
            authMessage == null
                ? 'Los datos de la cuenta se eliminaron, '
                      'pero no fue posible eliminar '
                      'la cuenta de acceso. '
                      'Inténtalo nuevamente.'
                : 'Los datos de la cuenta se eliminaron, '
                      'pero no fue posible eliminar '
                      'la cuenta de acceso. '
                      '$authMessage',
          );

          authViewModel.clearError();
        }

        return;
      }

      // La eliminación correcta de la cuenta produce
      // una transición esperada a sesión no autenticada.
      //
      // No debemos limpiar el estado de seguimiento
      // de una nueva cuenta B si apareció mientras
      // terminaba la operación anterior.
      if (!authViewModel.isAuthenticated &&
          authViewModel.currentUserId == null) {
        trackingViewModel.clearAuthenticationState();
      }
    } finally {
      // El observador es temporal y siempre se retira,
      // incluyendo cancelaciones, errores o cambios
      // de identidad durante cualquier diálogo.
      authViewModel.removeListener(observeAuthenticationContext);

      if (mounted && _isDeletingAccount) {
        setState(() {
          _isDeletingAccount = false;
        });
      }
    }
  }

  Future<String?> _requestDeletionPassword(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return const _DeleteAccountPasswordDialog();
      },
    );
  }

  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final themeModeController = context.watch<ThemeModeController>();
    final authViewModel = context.watch<AuthViewModel?>();
    final trackingViewModel = context.watch<TrackingViewModel?>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final accountManagementAvailable =
        authViewModel != null && trackingViewModel != null;

    final hasAuthenticatedAccount =
        accountManagementAvailable && authViewModel.isAuthenticated;

    final currentEmail = authViewModel?.currentUserEmail?.trim() ?? '';

    final isSessionBusy =
        _isDeletingAccount ||
        authViewModel?.isLoading == true ||
        trackingViewModel?.isLoading == true;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const SendarisPrimaryAppBar(
        showSettingsAction: false,
        showBackButton: true,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
          children: [
            AnimatedEntrance(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajustes',
                    key: const Key('settings-title'),
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 7),
                  Text(
                    accountManagementAvailable
                        ? 'Consulta tu cuenta, revisa la privacidad '
                              'y administra la configuración de Sendaris.'
                        : 'Personaliza la apariencia y consulta '
                              'la información de privacidad de Sendaris.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Cuenta actual: solo para sesiones autenticadas.
            if (hasAuthenticatedAccount) ...[
              const SizedBox(height: 28),
              const AnimatedEntrance(
                delay: Duration(milliseconds: 60),
                child: SendarisSectionLabel(label: 'Cuenta actual'),
              ),
              const SizedBox(height: 14),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 110),
                duration: const Duration(milliseconds: 450),
                beginScale: 0.99,
                child: Card(
                  key: const Key('settings-current-account-card'),
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer.withValues(
                              alpha: 0.62,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.account_circle_outlined,
                            color: colorScheme.primary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Correo de la cuenta',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                currentEmail.isNotEmpty
                                    ? currentEmail
                                    : 'Correo no disponible',
                                key: const Key('settings-account-email'),
                                softWrap: true,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // Privacidad: contenido recuperado de ambos stashes.
            const SizedBox(height: 28),
            const AnimatedEntrance(
              delay: Duration(milliseconds: 150),
              child: SendarisSectionLabel(label: 'Privacidad'),
            ),
            const SizedBox(height: 14),
            AnimatedEntrance(
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 450),
              beginScale: 0.99,
              child: Card(
                key: const Key('settings-privacy-card'),
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withValues(
                            alpha: 0.62,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.shield_outlined,
                          color: colorScheme.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Seguimientos anónimos',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Los seguimientos no solicitan '
                              'nombres ni identificadores '
                              'personales del niño.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              'La información de cada seguimiento '
                              'se mantiene separada.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Apariencia: conserva el comportamiento de HU-29.
            const SizedBox(height: 28),
            const AnimatedEntrance(
              delay: Duration(milliseconds: 250),
              child: SendarisSectionLabel(label: 'Apariencia'),
            ),
            const SizedBox(height: 14),
            AnimatedEntrance(
              delay: const Duration(milliseconds: 300),
              duration: const Duration(milliseconds: 450),
              beginScale: 0.99,
              child: Card(
                key: const Key('settings-appearance-card'),
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tema de la aplicación',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Elige cómo quieres ver Sendaris.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _ThemeOption(
                        key: const Key('settings-theme-system'),
                        title: 'Sistema',
                        subtitle:
                            'Usar la configuración '
                            'del dispositivo',
                        icon: Icons.settings_suggest_outlined,
                        selected:
                            themeModeController.themeMode == ThemeMode.system,
                        onTap: () {
                          themeModeController.setThemeMode(ThemeMode.system);
                        },
                      ),
                      const SizedBox(height: 10),
                      _ThemeOption(
                        key: const Key('settings-theme-light'),
                        title: 'Claro',
                        subtitle:
                            'Mantener la aplicación '
                            'en modo claro',
                        icon: Icons.light_mode_outlined,
                        selected:
                            themeModeController.themeMode == ThemeMode.light,
                        onTap: () {
                          themeModeController.setThemeMode(ThemeMode.light);
                        },
                      ),
                      const SizedBox(height: 10),
                      _ThemeOption(
                        key: const Key('settings-theme-dark'),
                        title: 'Oscuro',
                        subtitle:
                            'Mantener la aplicación '
                            'en modo oscuro',
                        icon: Icons.dark_mode_outlined,
                        selected:
                            themeModeController.themeMode == ThemeMode.dark,
                        onTap: () {
                          themeModeController.setThemeMode(ThemeMode.dark);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Acciones sensibles: se conservan los flujos existentes.
            if (authViewModel != null && trackingViewModel != null) ...[
              const SizedBox(height: 28),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 360),
                child: _SettingsActionCard(
                  cardKey: const Key('settings-delete-account-card'),
                  actionKey: const Key('settings-delete-account-action'),
                  title: 'Eliminar cuenta',
                  subtitle:
                      'Elimina definitivamente tu cuenta '
                      'y todos los datos asociados.',
                  icon: Icons.delete_forever_rounded,
                  destructive: true,
                  showProgress: _isDeletingAccount,
                  onTap: isSessionBusy
                      ? null
                      : () {
                          _confirmDeleteAccount(
                            context,
                            authViewModel,
                            trackingViewModel,
                          );
                        },
                ),
              ),
              const SizedBox(height: 14),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 410),
                child: _SettingsActionCard(
                  actionKey: const Key('settings-sign-out-action'),
                  title: 'Cerrar sesión',
                  subtitle: 'Finaliza el acceso actual a Sendaris.',
                  icon: Icons.logout_rounded,
                  showProgress: authViewModel.isLoading && !_isDeletingAccount,
                  onTap: isSessionBusy
                      ? null
                      : () {
                          _confirmSignOut(
                            context,
                            authViewModel,
                            trackingViewModel,
                          );
                        },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SettingsActionCard extends StatelessWidget {
  const _SettingsActionCard({
    required this.actionKey,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.showProgress,
    required this.onTap,
    this.cardKey,
    this.destructive = false,
  });

  final Key? cardKey;
  final Key actionKey;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool destructive;
  final bool showProgress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final iconBackground = destructive
        ? colorScheme.errorContainer
        : colorScheme.surfaceContainerHighest;

    final iconForeground = destructive
        ? colorScheme.onErrorContainer
        : colorScheme.onSurface;

    return Card(
      key: cardKey,
      margin: EdgeInsets.zero,
      child: InkWell(
        key: actionKey,
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconForeground),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: destructive ? colorScheme.error : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (showProgress)
                SizedBox(
                  key: destructive
                      ? const Key('settings-delete-account-progress')
                      : null,
                  width: 22,
                  height: 22,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: destructive ? colorScheme.error : colorScheme.outline,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteAccountPasswordDialog extends StatefulWidget {
  const _DeleteAccountPasswordDialog();

  @override
  State<_DeleteAccountPasswordDialog> createState() {
    return _DeleteAccountPasswordDialogState();
  }
}

class _DeleteAccountPasswordDialogState
    extends State<_DeleteAccountPasswordDialog> {
  final TextEditingController _controller = TextEditingController();

  bool _obscureText = true;
  String? _errorText;

  void _submit() {
    final value = _controller.text;

    if (value.isEmpty) {
      setState(() {
        _errorText = 'Ingresa tu contraseña.';
      });

      return;
    }

    Navigator.of(context).pop(value);
  }

  @override
  void dispose() {
    _controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      key: const Key('settings-delete-account-password-dialog'),
      scrollable: true,
      title: const Text('Confirma tu identidad'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ingresa tu contraseña actual '
            'para autorizar la eliminación definitiva.',
          ),
          const SizedBox(height: 18),
          TextField(
            key: const Key('settings-delete-account-password-field'),
            controller: _controller,
            obscureText: _obscureText,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) {
              _submit();
            },
            decoration: InputDecoration(
              labelText: 'Contraseña',
              errorText: _errorText,
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                key: const Key('settings-delete-account-password-visibility'),
                tooltip: _obscureText
                    ? 'Mostrar contraseña'
                    : 'Ocultar contraseña',
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
                icon: Icon(
                  _obscureText
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          key: const Key('settings-cancel-delete-account-password-button'),
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          key: const Key('settings-confirm-delete-account-button'),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: _submit,
          icon: const Icon(Icons.delete_forever_rounded),
          label: const Text('Eliminar definitivamente'),
        ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      selected: selected,
      label: '$title. $subtitle',
      child: Material(
        color: selected
            ? colorScheme.primaryContainer.withValues(alpha: 0.58)
            : colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(17),
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.primary
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: selected
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: selected
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: const ValueKey('selected'),
                          color: colorScheme.primary,
                        )
                      : Icon(
                          Icons.circle_outlined,
                          key: const ValueKey('not-selected'),
                          color: colorScheme.outline,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
