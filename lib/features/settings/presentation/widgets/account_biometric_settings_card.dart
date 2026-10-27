import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../../app/session/account_biometric_settings_controller.dart';
import '../../../../app/session/biometric_binding_policy.dart';
import '../../../../app/session/biometric_vault_gateway.dart';
import '../../../../app/session/firebase_account_contexts.dart';

final class AccountBiometricSettingsCard extends StatefulWidget {
  const AccountBiometricSettingsCard({
    required this.controller,
    required this.isAccountReady,
    this.reauthenticateForRecovery,
    super.key,
  });

  final AccountBiometricSettingsController controller;
  final bool isAccountReady;

  final Future<bool> Function()? reauthenticateForRecovery;

  @override
  State<AccountBiometricSettingsCard> createState() =>
      _AccountBiometricSettingsCardState();
}

final class _AccountBiometricSettingsCardState
    extends State<AccountBiometricSettingsCard> {
  BiometricBindingState? _binding;
  bool _bindingInvalidated = false;

  AccountBiometricSettingsResult? _lastResult;

  bool _reading = false;
  bool _requestPending = false;

  int _revision = 0;

  @override
  void initState() {
    super.initState();

    _attach(widget.controller);
    _scheduleRead();
  }

  @override
  void didUpdateWidget(covariant AccountBiometricSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.controller, widget.controller)) {
      _detach(oldWidget.controller);
      _attach(widget.controller);

      _invalidate();
      _scheduleRead();
    } else if (oldWidget.isAccountReady != widget.isAccountReady) {
      _invalidate();
      _scheduleRead();
    }
  }

  void _attach(AccountBiometricSettingsController controller) {
    controller.addListener(_notify);
    controller.selection.addListener(_identityChanged);
  }

  void _detach(AccountBiometricSettingsController controller) {
    controller.removeListener(_notify);
    controller.selection.removeListener(_identityChanged);
  }

  void _notify() {
    if (mounted) {
      setState(() {});
    }
  }

  void _invalidate() {
    ++_revision;
    _binding = null;
    _bindingInvalidated = false;
    _lastResult = null;
    _reading = false;
  }

  void _identityChanged() {
    if (!mounted) {
      return;
    }

    setState(_invalidate);
    _scheduleRead();
  }

  void _scheduleRead() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_readBinding());
      }
    });
  }

  bool _sameIdentity(
    AccountBiometricSettingsController controller,
    FirebaseAccountSlot slot,
    String userId,
    int revision,
  ) {
    if (!mounted ||
        !identical(controller, widget.controller) ||
        revision != _revision ||
        !widget.isAccountReady ||
        !controller.selection.value ||
        controller.selection.selectedSlot != slot ||
        controller.selection.selectedUserId != userId) {
      return false;
    }

    final session = switch (slot) {
      FirebaseAccountSlot.primary => controller.primarySession,
      FirebaseAccountSlot.secondary => controller.secondarySession,
    };

    return session.currentUserId == userId;
  }

  Future<void> _readBinding() async {
    final controller = widget.controller;
    final selection = controller.selection;

    final slot = selection.selectedSlot;
    final userId = selection.selectedUserId;
    final revision = ++_revision;

    if (!widget.isAccountReady ||
        !selection.value ||
        slot == null ||
        userId == null ||
        userId.isEmpty) {
      if (mounted) {
        setState(() {
          _binding = null;
          _bindingInvalidated = false;
          _reading = false;
        });
      }

      return;
    }

    setState(() {
      _reading = true;
      _binding = null;
      _bindingInvalidated = false;
    });

    BiometricBindingState binding;

    try {
      binding = await controller.gateway.readBinding();
    } catch (_) {
      binding = const BiometricBindingUnavailable();
    }

    var invalidated = false;

    if (binding is BiometricBindingEnabled &&
        binding.userId == userId &&
        controller.gateway is BiometricInvalidatedRecoveryGateway) {
      final recovery =
          controller.gateway as BiometricInvalidatedRecoveryGateway;

      invalidated = await recovery.isPermanentlyInvalidated(
        expectedUserId: userId,
      );
    }

    if (!_sameIdentity(controller, slot, userId, revision)) {
      return;
    }

    setState(() {
      _binding = binding;
      _bindingInvalidated = invalidated;
      _reading = false;
    });
  }

  Future<void> _confirmAndExecute({required bool activate}) async {
    final controller = widget.controller;

    final slot = controller.selection.selectedSlot;
    final userId = controller.selection.selectedUserId;
    final revision = _revision;

    if (slot == null || userId == null || _requestPending) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: Key(
          activate
              ? 'biometric-enrollment-confirmation-dialog'
              : 'biometric-deactivation-confirmation-dialog',
        ),
        title: Text(
          activate ? '¿Activar acceso seguro?' : '¿Desactivar acceso seguro?',
        ),
        content: Text(
          activate
              ? 'Usa tu huella o reconocimiento facial '
                    'para confirmar que eres tú.'
              : 'Confirma con tu huella o reconocimiento '
                    'facial que deseas desactivar este acceso.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: Key(
              activate
                  ? 'biometric-enrollment-confirm'
                  : 'biometric-deactivation-confirm',
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirmed != true ||
        !_sameIdentity(controller, slot, userId, revision) ||
        controller.isBusy ||
        _reading ||
        _requestPending) {
      return;
    }

    final binding = _binding;

    if (activate && binding is! BiometricBindingDisabled) {
      return;
    }

    if (!activate &&
        (binding is! BiometricBindingEnabled || binding.userId != userId)) {
      return;
    }

    setState(() {
      _requestPending = true;
    });

    try {
      final result = activate
          ? await controller.activate()
          : await controller.deactivate();

      if (!mounted || !identical(controller, widget.controller)) {
        return;
      }

      if (controller.selection.value &&
          controller.selection.selectedSlot == slot &&
          controller.selection.selectedUserId == userId) {
        setState(() {
          _lastResult = result;
        });

        await _readBinding();
      }
    } finally {
      if (mounted) {
        setState(() {
          _requestPending = false;
        });
      }
    }
  }

  Future<bool> _reauthenticateCurrentAccount(String expectedUid) async {
    final callback = widget.reauthenticateForRecovery;

    if (callback != null) {
      return callback();
    }

    final auth = context.read<AuthViewModel>();

    if (!auth.isAuthenticated || auth.currentUserId != expectedUid) {
      return false;
    }

    if (auth.canReauthenticateWithGoogle) {
      final verified = await auth.reauthenticateWithGoogle();

      return verified && auth.currentUserId == expectedUid;
    }

    final passwordController = TextEditingController();

    try {
      final password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          key: const Key('biometric-recovery-password-dialog'),
          title: const Text('Confirma que eres tú'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Escribe la contraseña de tu cuenta '
                'para continuar. Tus registros no cambiarán.',
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('biometric-recovery-password'),
                controller: passwordController,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(labelText: 'Contraseña'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('biometric-recovery-password-confirm'),
              onPressed: () {
                Navigator.of(dialogContext).pop(passwordController.text);
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      );

      if (!mounted ||
          password == null ||
          password.isEmpty ||
          auth.currentUserId != expectedUid) {
        return false;
      }

      final confirmed = await auth.reauthenticateWithPassword(
        password: password,
      );

      return confirmed && auth.currentUserId == expectedUid;
    } finally {
      passwordController.clear();
      passwordController.dispose();
    }
  }

  Future<void> _recoverInvalidatedBinding() async {
    if (_requestPending || !widget.isAccountReady) {
      return;
    }

    final controller = widget.controller;
    final slot = controller.selection.selectedSlot;
    final uid = controller.selection.selectedUserId;

    if (slot == null || uid == null || !controller.selection.value) {
      return;
    }

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        key: const Key('biometric-recovery-confirmation'),
        title: const Text('¿Volver a usar tu huella?'),
        content: const Text(
          'Para proteger tus datos, te pediremos confirmar '
          'tu cuenta y desbloquear el teléfono con tu PIN, '
          'patrón o contraseña.\n\n'
          'Después podrás activar de nuevo el acceso '
          'con huella. Tus registros no se borrarán.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('biometric-recovery-confirm'),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (accepted != true ||
        !mounted ||
        !widget.isAccountReady ||
        controller.selection.selectedSlot != slot ||
        controller.selection.selectedUserId != uid ||
        !controller.selection.value) {
      return;
    }

    setState(() {
      _requestPending = true;
    });

    try {
      final result = await controller.recoverInvalidated(
        reauthenticate: () => _reauthenticateCurrentAccount(uid),
      );

      if (!mounted || !identical(widget.controller, controller)) {
        return;
      }

      setState(() {
        _lastResult = result;
      });

      await _readBinding();
    } finally {
      if (mounted) {
        setState(() {
          _requestPending = false;
        });
      }
    }
  }

  String _statusText(String? selectedUserId) {
    if (!widget.isAccountReady || !widget.controller.selection.value) {
      return 'Para cambiar esta opción, primero '
          'inicia sesión en tu cuenta.';
    }

    if (_reading || _binding == null) {
      return 'Comprobando el acceso con huella...';
    }

    final binding = _binding;

    if (binding is BiometricBindingDisabled) {
      return 'La opción de huella no está configurada '
          'para esta cuenta. Puedes activarla cuando quieras.';
    }

    if (binding is BiometricBindingEnabled) {
      if (binding.userId == selectedUserId && _bindingInvalidated) {
        return 'Por seguridad, necesitas configurar de nuevo '
            'el acceso con huella. Tus registros siguen protegidos.';
      }

      return binding.userId == selectedUserId
          ? 'Puedes usar tu huella o reconocimiento facial '
                'para entrar a esta cuenta.'
          : 'El acceso con huella ya está configurado '
                'para otra cuenta en este teléfono.';
    }

    return 'No se pudo comprobar el acceso con huella. '
        'Inténtalo de nuevo.';
  }

  String? _resultText() {
    return switch (_lastResult) {
      null => null,

      AccountBiometricSettingsResult.activated =>
        'El acceso con huella está activado.',

      AccountBiometricSettingsResult.deactivated =>
        'El acceso con huella se desactivó. '
            'Ahora puedes volver a activarlo.',

      AccountBiometricSettingsResult.alreadyEnabled =>
        'Ya puedes entrar a esta cuenta con tu huella.',

      AccountBiometricSettingsResult.notEnabled =>
        'El acceso con huella ya está desactivado.',

      AccountBiometricSettingsResult.otherAccountBound =>
        'El acceso con huella está configurado '
            'para otra cuenta en este teléfono.',

      AccountBiometricSettingsResult.cancelled =>
        'Operación cancelada. No se realizó ningún cambio.',

      AccountBiometricSettingsResult.busy => 'Hay otra comprobación en curso.',

      AccountBiometricSettingsResult.denied =>
        'No se pudo confirmar tu identidad. '
            'Inténtalo nuevamente.',

      AccountBiometricSettingsResult.notAuthorized ||
      AccountBiometricSettingsResult.invalidSession ||
      AccountBiometricSettingsResult.identityChanged ||
      AccountBiometricSettingsResult.unavailable =>
        'No pudimos completar la verificación. '
            'Tu cuenta sigue protegida.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final userId = controller.selection.selectedUserId;
    final binding = _binding;

    final busy = controller.isBusy || _reading || _requestPending;

    final authorized =
        widget.isAccountReady &&
        controller.selection.value &&
        userId != null &&
        userId.isNotEmpty;

    final canActivate =
        authorized && !busy && binding is BiometricBindingDisabled;

    final canDeactivate =
        authorized &&
        !busy &&
        binding is BiometricBindingEnabled &&
        binding.userId == userId;

    final colors = Theme.of(context).colorScheme;
    final feedback = _resultText();

    return Card(
      key: const Key('settings-biometric-card'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.fingerprint_rounded,
                  color: colors.primary,
                  size: 36,
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Huella o reconocimiento facial',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              _statusText(userId),
              key: const Key('settings-biometric-binding-status'),
            ),

            if (feedback != null) ...[
              const SizedBox(height: 10),
              Text(feedback, key: const Key('settings-biometric-feedback')),
            ],

            const SizedBox(height: 16),

            if (canDeactivate && _bindingInvalidated) ...[
              const Text(
                'Si cambiaste las huellas guardadas en tu '
                'teléfono, puedes volver a configurar el '
                'acceso después de confirmar que eres tú.',
              ),

              const SizedBox(height: 10),

              OutlinedButton.icon(
                key: const Key('settings-biometric-recover-invalidated'),
                onPressed: busy
                    ? null
                    : () {
                        unawaited(_recoverInvalidatedBinding());
                      },
                icon: const Icon(Icons.security_update_good_rounded),
                label: const Text('Recuperar acceso con huella'),
              ),

              const SizedBox(height: 12),
            ],

            if (canDeactivate && !_bindingInvalidated)
              FilledButton.icon(
                key: const Key('settings-biometric-deactivate'),
                onPressed: () {
                  unawaited(_confirmAndExecute(activate: false));
                },
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Desactivar acceso seguro'),
              )
            else if (!canDeactivate)
              FilledButton.icon(
                key: const Key('settings-biometric-activate'),
                onPressed: canActivate
                    ? () {
                        unawaited(_confirmAndExecute(activate: true));
                      }
                    : null,
                icon: const Icon(Icons.fingerprint_rounded),
                label: Text(busy ? 'Comprobando...' : 'Activar acceso seguro'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    ++_revision;
    _detach(widget.controller);
    super.dispose();
  }
}
