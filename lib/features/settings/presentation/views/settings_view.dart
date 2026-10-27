import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/animation/animated_entrance.dart';
import '../../../../app/session/account_biometric_settings_controller.dart';
import '../../../../app/session/account_session_exit_coordinator.dart';
import '../../../../app/session/account_session_selection_controller.dart';
import '../../../../app/session/biometric_enrollment_controller.dart';
import '../../../../app/session/sendaris_dual_account_root.dart';
import '../../../../app/theme/sendaris_section_label.dart';
import '../../../../app/theme/theme_mode_controller.dart';
import '../../../../app/widgets/sendaris_primary_app_bar.dart';
import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../tracking/presentation/viewmodels/tracking_view_model.dart';
import '../widgets/account_biometric_settings_card.dart';
import '../widgets/biometric_enrollment_settings_card.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() {
    return _SettingsViewState();
  }
}

class _SettingsViewState extends State<SettingsView> {
  bool _isDeletingAccount = false;
  bool _isSigningOut = false;

  /// Cierra el acceso a la cuenta seleccionada.
  ///
  /// En el nuevo componente raiz:
  /// - Cuenta vinculada: bloqueo visual sin Firebase signOut.
  /// - Cuenta convencional: signOut de su contexto.
  ///
  /// En el arranque anterior conserva el flujo existente.
  ///
  /// Cualquier cambio de identidad durante el dialogo
  /// invalida la confirmacion, incluyendo A -> B -> A.
  Future<void> _confirmSignOut(
    BuildContext context,
    AuthViewModel authViewModel,
    TrackingViewModel trackingViewModel,
    AccountSessionExitCoordinator? exitCoordinator,
    AccountSessionSelectionController? selection,
    SendarisAccountSessionConfiguration? configuration,
  ) async {
    if (_isSigningOut ||
        authViewModel.isLoading ||
        trackingViewModel.isLoading ||
        _isDeletingAccount) {
      return;
    }

    final dualMode =
        exitCoordinator != null || selection != null || configuration != null;

    // No utilizar el cierre de sesion antiguo si
    // el nuevo contexto existe pero esta incompleto.
    if (dualMode &&
        (exitCoordinator == null ||
            selection == null ||
            configuration == null ||
            !selection.value ||
            selection.selectedUserId != authViewModel.currentUserId)) {
      _showErrorMessage(
        context,
        'No fue posible comprobar la cuenta actual. '
        'Vuelve a intentarlo.',
      );
      return;
    }

    final initialSlot = selection?.selectedSlot;
    final initialUserId = selection?.selectedUserId;

    // Este indicador queda invalidado si el selector
    // cambia mientras se muestra la confirmacion.
    var authorizationChanged = false;

    void observeAuthorization() {
      if (selection?.selectedSlot != initialSlot ||
          selection?.selectedUserId != initialUserId ||
          selection?.value != true) {
        authorizationChanged = true;
      }
    }

    if (dualMode) {
      selection!.addListener(observeAuthorization);
    }

    final bool? confirmed;

    try {
      confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('¿Cerrar sesión?'),
            content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
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
    } finally {
      if (dualMode) {
        selection!.removeListener(observeAuthorization);
      }
    }

    if (confirmed != true || !mounted || !context.mounted) {
      return;
    }

    if (dualMode &&
        (authorizationChanged ||
            selection!.selectedSlot != initialSlot ||
            selection.selectedUserId != initialUserId ||
            !selection.value ||
            authViewModel.currentUserId != initialUserId)) {
      _showErrorMessage(
        context,
        'La cuenta cambió durante la confirmación. '
        'Vuelve a intentarlo.',
      );
      return;
    }

    setState(() {
      _isSigningOut = true;
    });

    try {
      if (dualMode) {
        // El coordinador revoca primero el permiso
        // privado y solo cierra Firebase cuando
        // la cuenta activa no es la vinculada.
        final success = await exitCoordinator!.closeActiveSession();

        if (!success && mounted && context.mounted) {
          _showErrorMessage(
            context,
            'No se pudo cerrar la sesión. Inténtalo nuevamente.',
          );
        }

        return;
      }

      // Compatibilidad con el arranque actual.
      final success = await authViewModel.signOut();

      if (success) {
        trackingViewModel.clearAuthenticationState();
        return;
      }

      if (mounted && context.mounted) {
        _showErrorMessage(
          context,
          authViewModel.errorMessage ?? 'No fue posible cerrar la sesión.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  /// Conserva el procedimiento actual de eliminacion
  /// de cuenta, incluyendo reautenticacion y limpieza.
  ///
  /// La eliminacion de una cuenta vinculada a biometria
  /// se deshabilita en la interfaz mientras no exista
  /// una desvinculacion autenticada integrada.
  Future<void> _confirmDeleteAccount(
    BuildContext context,
    AuthViewModel authViewModel,
    TrackingViewModel trackingViewModel,
  ) async {
    if (_isDeletingAccount ||
        _isSigningOut ||
        authViewModel.isLoading ||
        trackingViewModel.isLoading ||
        !authViewModel.isAuthenticated) {
      return;
    }

    final initiatingUserId = authViewModel.currentUserId;
    final initiatingAuthenticated = authViewModel.isAuthenticated;

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

      // No se eliminan los datos sin reautenticacion.
      final reauthenticated = useGoogle
          ? await authViewModel.reauthenticateWithGoogle()
          : await authViewModel.reauthenticateWithPassword(password: password!);

      if (!isOriginalAuthenticationContext()) {
        return;
      }

      if (!reauthenticated) {
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

      final dataDeleted = await trackingViewModel.deleteAllProfilesForAccount();

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

      if (!isOriginalAuthenticationContext()) {
        return;
      }

      final accountDeleted = await authViewModel.deleteCurrentAccount();

      if (!accountDeleted) {
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

      if (!authViewModel.isAuthenticated &&
          authViewModel.currentUserId == null) {
        trackingViewModel.clearAuthenticationState();
      }
    } finally {
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

    final biometricController = context.watch<BiometricEnrollmentController?>();

    final accountBiometricController = context
        .watch<AccountBiometricSettingsController?>();

    final exitCoordinator = context.watch<AccountSessionExitCoordinator?>();

    final selection = exitCoordinator?.selection;

    final accountConfiguration = context
        .watch<SendarisAccountSessionConfiguration?>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final accountManagementAvailable =
        authViewModel != null && trackingViewModel != null;

    final hasAuthenticatedAccount =
        accountManagementAvailable && authViewModel.isAuthenticated;

    final currentEmail = authViewModel?.currentUserEmail?.trim() ?? '';

    final isSessionBusy =
        _isDeletingAccount ||
        _isSigningOut ||
        exitCoordinator?.isBusy == true ||
        accountBiometricController?.isBusy == true ||
        authViewModel?.isLoading == true ||
        trackingViewModel?.isLoading == true;

    // El contexto nuevo tiene prioridad. Nunca usar el controlador
    // anterior como respaldo de una configuracion dual incompleta.
    final dualMode =
        exitCoordinator != null ||
        accountConfiguration != null ||
        accountBiometricController != null;

    final dualAuthorizationReady =
        exitCoordinator != null &&
        accountConfiguration != null &&
        accountBiometricController != null &&
        selection != null &&
        selection.value &&
        selection.selectedSlot != null &&
        selection.selectedUserId != null &&
        selection.selectedUserId == authViewModel?.currentUserId &&
        (selection.selectedSlot == accountConfiguration.conventionalSlot ||
            selection.selectedSlot == accountConfiguration.linkedSlot);

    // Si existe una cuenta vinculada, esta configuracion se reserva
    // exclusivamente para ella. Las cuentas convencionales no ven
    // ni la tarjeta ni el encabezado de Seguridad.
    //
    // Cuando no existe vinculacion, cualquier cuenta convencional
    // autenticada y autorizada puede configurar el acceso seguro.
    final showDualBiometrics =
        dualMode &&
        hasAuthenticatedAccount &&
        dualAuthorizationReady &&
        (accountConfiguration.linkedSlot == null ||
            selection.selectedSlot == accountConfiguration.linkedSlot);

    final showConventionalBiometrics =
        !dualMode && hasAuthenticatedAccount && biometricController != null;

    // En modo dual, una identidad no seleccionada no puede realizar
    // operaciones destructivas ni cerrar una sesion por error.
    final sensitiveActionBlocked =
        isSessionBusy || (dualMode && !dualAuthorizationReady);

    // Una cuenta vinculada solo puede eliminarse despues de una
    // desvinculacion biometrica autenticada.
    final protectedLinkedAccount =
        dualAuthorizationReady &&
        accountConfiguration.linkedSlot != null &&
        selection.selectedSlot == accountConfiguration.linkedSlot;

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

            // Cuenta actual.
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

            // Privacidad.
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

            // Apariencia.
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

            // Seguridad biometrica.
            // La configuracion dual solo utiliza su propio controlador.
            // El arranque convencional conserva la tarjeta anterior.
            if (showDualBiometrics || showConventionalBiometrics) ...[
              const SizedBox(height: 28),

              const AnimatedEntrance(
                delay: Duration(milliseconds: 330),
                child: SendarisSectionLabel(label: 'Seguridad'),
              ),

              const SizedBox(height: 14),

              AnimatedEntrance(
                delay: const Duration(milliseconds: 345),
                duration: const Duration(milliseconds: 450),
                beginScale: 0.99,
                child: showDualBiometrics
                    ? AccountBiometricSettingsCard(
                        key: ValueKey<String>(
                          'settings-biometric-identity-'
                          '${authViewModel.currentUserId}',
                        ),
                        controller: accountBiometricController,
                        isAccountReady:
                            authViewModel.isAuthenticatedAppReady &&
                            authViewModel.isEmailVerified == true &&
                            authViewModel.currentUserId != null &&
                            authViewModel.currentUserId!.isNotEmpty &&
                            dualAuthorizationReady &&
                            !isSessionBusy,
                      )
                    : BiometricEnrollmentSettingsCard(
                        key: ValueKey<String>(
                          'settings-biometric-identity-'
                          '${authViewModel.currentUserId}',
                        ),
                        controller: biometricController!,
                        isAccountReady:
                            authViewModel.isAuthenticatedAppReady &&
                            authViewModel.isEmailVerified == true &&
                            authViewModel.currentUserId != null &&
                            authViewModel.currentUserId!.isNotEmpty &&
                            !isSessionBusy,
                      ),
              ),
            ],

            // Acciones sensibles.
            if (authViewModel != null && trackingViewModel != null) ...[
              const SizedBox(height: 28),

              if (protectedLinkedAccount) ...[
                const Text(
                  'Para eliminar esta cuenta, primero desactiva '
                  'el acceso con huella o reconocimiento facial '
                  'desde Seguridad.',
                  key: Key('settings-linked-delete-protection'),
                ),

                const SizedBox(height: 12),
              ],

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
                  onTap: sensitiveActionBlocked || protectedLinkedAccount
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

              // Un unico boton para ambos modos.
              AnimatedEntrance(
                delay: const Duration(milliseconds: 410),
                child: _SettingsActionCard(
                  actionKey: const Key('settings-sign-out-action'),
                  title: 'Cerrar sesión',
                  subtitle: 'Finaliza el acceso actual a Sendaris.',
                  icon: Icons.logout_rounded,
                  showProgress:
                      _isSigningOut ||
                      (authViewModel.isLoading && !_isDeletingAccount),
                  onTap: sensitiveActionBlocked
                      ? null
                      : () {
                          _confirmSignOut(
                            context,
                            authViewModel,
                            trackingViewModel,
                            exitCoordinator,
                            selection,
                            accountConfiguration,
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
