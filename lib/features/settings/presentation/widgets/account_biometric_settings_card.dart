import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/session/account_biometric_settings_controller.dart';
import '../../../../app/session/biometric_binding_policy.dart';
import '../../../../app/session/firebase_account_contexts.dart';

/// Tarjeta de seguridad de las cuentas independientes.
///
/// Muestra mensajes sencillos para el usuario sin
/// exponer detalles de los mecanismos internos.
///
/// Las operaciones reales siguen siendo responsabilidad
/// del controlador de seguridad.
final class AccountBiometricSettingsCard extends StatefulWidget {
  const AccountBiometricSettingsCard({
    required this.controller,
    required this.isAccountReady,
    super.key,
  });

  final AccountBiometricSettingsController controller;
  final bool isAccountReady;

  @override
  State<AccountBiometricSettingsCard> createState() =>
      _AccountBiometricSettingsCardState();
}

final class _AccountBiometricSettingsCardState
    extends State<AccountBiometricSettingsCard> {
  BiometricBindingState? _binding;
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
          _reading = false;
        });
      }

      return;
    }

    setState(() {
      _reading = true;
      _binding = null;
    });

    BiometricBindingState binding;

    try {
      binding = await controller.gateway.readBinding();
    } catch (_) {
      binding = const BiometricBindingUnavailable();
    }

    if (!_sameIdentity(controller, slot, userId, revision)) {
      return;
    }

    setState(() {
      _binding = binding;
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
              ? 'Deberás verificar tu huella o reconocimiento '
                    'facial para activar esta opción.'
              : 'Deberás verificar tu huella o reconocimiento '
                    'facial para desactivarlo.',
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

  String _statusText(String? selectedUserId) {
    if (!widget.isAccountReady || !widget.controller.selection.value) {
      return 'Se requiere una sesión autorizada '
          'y un correo verificado.';
    }

    if (_reading || _binding == null) {
      return 'Comprobando el acceso seguro '
          'de este dispositivo...';
    }

    final binding = _binding;

    if (binding is BiometricBindingDisabled) {
      return 'La opción de huella o reconocimiento facial '
          'no está configurada para esta instalación.';
    }

    if (binding is BiometricBindingEnabled) {
      return binding.userId == selectedUserId
          ? 'El acceso con huella o reconocimiento facial '
                'está activado para esta cuenta.'
          : 'Existe una vinculación protegida de otra cuenta.';
    }

    return 'No fue posible comprobar la vinculación '
        'de forma segura.';
  }

  String? _resultText() => switch (_lastResult) {
    null => null,
    AccountBiometricSettingsResult.activated =>
      'Acceso seguro activado. Permaneces en la cuenta actual.',
    AccountBiometricSettingsResult.deactivated =>
      'Acceso seguro desactivado. Tus datos permanecen intactos.',
    AccountBiometricSettingsResult.alreadyEnabled =>
      'Esta cuenta ya tiene activado el acceso con '
          'huella o reconocimiento facial.',
    AccountBiometricSettingsResult.notEnabled =>
      'No existe una vinculación activa.',
    AccountBiometricSettingsResult.otherAccountBound =>
      'Otra cuenta ya está vinculada a este dispositivo.',
    AccountBiometricSettingsResult.cancelled => 'Operación cancelada.',
    AccountBiometricSettingsResult.busy =>
      'Ya hay otra verificación de seguridad en curso.',
    AccountBiometricSettingsResult.denied =>
      'Android no confirmó tu huella o reconocimiento facial.',
    AccountBiometricSettingsResult.notAuthorized ||
    AccountBiometricSettingsResult.invalidSession ||
    AccountBiometricSettingsResult.identityChanged ||
    AccountBiometricSettingsResult.unavailable =>
      'No fue posible verificar la operación. '
          'El acceso permanecerá protegido.',
  };

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
            if (canDeactivate)
              FilledButton.icon(
                key: const Key('settings-biometric-deactivate'),
                onPressed: () {
                  unawaited(_confirmAndExecute(activate: false));
                },
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Desactivar acceso seguro'),
              )
            else
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
