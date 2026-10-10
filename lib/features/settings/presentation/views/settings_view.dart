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
        trackingViewModel.isLoading) {
      return;
    }

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

    if (confirmed != true || !context.mounted) {
      return;
    }

    final password = await _requestDeletionPassword(context);

    if (password == null || !context.mounted) {
      return;
    }

    setState(() {
      _isDeletingAccount = true;
    });

    try {
      final reauthenticated = await authViewModel.reauthenticateWithPassword(
        password: password,
      );

      if (!reauthenticated) {
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

      final accountDeleted = await authViewModel.deleteCurrentAccount();

      if (!accountDeleted) {
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

      trackingViewModel.clearAuthenticationState();
    } finally {
      if (mounted) {
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
                        ? 'Personaliza la apariencia '
                              'y administra tu sesión.'
                        : 'Personaliza la apariencia '
                              'de Sendaris.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            const AnimatedEntrance(
              delay: Duration(milliseconds: 90),
              child: SendarisSectionLabel(label: 'Apariencia'),
            ),
            const SizedBox(height: 14),
            AnimatedEntrance(
              delay: const Duration(milliseconds: 150),
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
            if (accountManagementAvailable) ...[
              const SizedBox(height: 28),
              const AnimatedEntrance(
                delay: Duration(milliseconds: 220),
                child: SendarisSectionLabel(label: 'Sesión'),
              ),
              const SizedBox(height: 14),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 280),
                duration: const Duration(milliseconds: 450),
                beginScale: 0.99,
                child: Card(
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    key: const Key('settings-sign-out-action'),
                    borderRadius: BorderRadius.circular(22),
                    onTap: isSessionBusy
                        ? null
                        : () {
                            _confirmSignOut(
                              context,
                              authViewModel,
                              trackingViewModel,
                            );
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.logout_rounded,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Cerrar sesión',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Finaliza el acceso '
                                  'actual a Sendaris.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (authViewModel.isLoading && !_isDeletingAccount)
                            const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              Icons.chevron_right_rounded,
                              color: colorScheme.outline,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const AnimatedEntrance(
                delay: Duration(milliseconds: 340),
                child: SendarisSectionLabel(label: 'Cuenta'),
              ),
              const SizedBox(height: 14),
              AnimatedEntrance(
                delay: const Duration(milliseconds: 400),
                duration: const Duration(milliseconds: 450),
                beginScale: 0.99,
                child: Card(
                  key: const Key('settings-delete-account-card'),
                  margin: EdgeInsets.zero,
                  child: InkWell(
                    key: const Key('settings-delete-account-action'),
                    borderRadius: BorderRadius.circular(22),
                    onTap: isSessionBusy
                        ? null
                        : () {
                            _confirmDeleteAccount(
                              context,
                              authViewModel,
                              trackingViewModel,
                            );
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              Icons.delete_forever_rounded,
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Eliminar cuenta',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'Elimina definitivamente '
                                  'tu cuenta y todos '
                                  'los datos asociados.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_isDeletingAccount)
                            const SizedBox(
                              key: Key('settings-delete-account-progress'),
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(
                              Icons.chevron_right_rounded,
                              color: colorScheme.error,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
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
