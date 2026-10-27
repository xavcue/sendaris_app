import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/session/biometric_enrollment_controller.dart';
import '../../../../app/session/biometric_enrollment_coordinator.dart';
import '../../../../app/session/biometric_settings_binding_reader.dart';

/// Presenta el estado real de la vinculación biométrica.
///
/// Nunca interpreta un estado desconocido como desactivado.
/// El enrolamiento continúa bajo las verificaciones del
/// coordinador de seguridad y Android Keystore.
final class BiometricEnrollmentSettingsCard extends StatefulWidget {
  const BiometricEnrollmentSettingsCard({
    required this.controller,
    required this.isAccountReady,
    super.key,
  });

  final BiometricEnrollmentController controller;
  final bool isAccountReady;

  @override
  State<BiometricEnrollmentSettingsCard> createState() =>
      _BiometricEnrollmentSettingsCardState();
}

final class _BiometricEnrollmentSettingsCardState
    extends State<BiometricEnrollmentSettingsCard> {
  @override
  void initState() {
    super.initState();
    _scheduleBindingRead();
  }

  @override
  void didUpdateWidget(covariant BiometricEnrollmentSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.controller, widget.controller)) {
      _scheduleBindingRead();
    }
  }

  void _scheduleBindingRead() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      unawaited(widget.controller.refreshBindingStatus());
    });
  }

  Future<void> _confirmActivation(BuildContext context) async {
    final controller = widget.controller;

    if (!widget.isAccountReady || !controller.canConfigureBiometrics) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          key: const Key('biometric-enrollment-confirmation-dialog'),
          title: const Text('¿Configurar acceso biométrico?'),
          content: const Text(
            'Se vinculará el acceso a Sendaris con la cuenta actual '
            'de este dispositivo.\n\n'
            'Android solicitará una verificación biométrica '
            'para confirmar la activación.\n\n'
            'Después, Sendaris volverá a comprobar la seguridad '
            'de la sesión antes de permitir el acceso.',
          ),
          actions: [
            TextButton(
              key: const Key('biometric-enrollment-cancel'),
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('biometric-enrollment-confirm'),
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
        !mounted ||
        !context.mounted ||
        !identical(widget.controller, controller) ||
        !widget.isAccountReady ||
        !controller.canConfigureBiometrics) {
      return;
    }

    await controller.activate();

    // Si la tarjeta continúa montada después de la
    // reevaluación del componente raíz, actualizamos
    // también el estado que se presenta en Ajustes.
    if (mounted && identical(widget.controller, controller)) {
      await controller.refreshBindingStatus();
    }
  }

  String? _resultMessage(BiometricEnrollmentResult? result) {
    return switch (result) {
      null => null,
      BiometricEnrollmentResult.enabled =>
        'La vinculación biométrica se configuró. '
            'Sendaris comprobará nuevamente el acceso.',
      BiometricEnrollmentResult.alreadyBound =>
        'Esta cuenta ya tiene una vinculación biométrica '
            'en el dispositivo.',
      BiometricEnrollmentResult.cancelled =>
        'La configuración biométrica fue cancelada.',
      BiometricEnrollmentResult.unavailable =>
        'La biometría no está disponible en este momento. '
            'Comprueba la configuración del dispositivo.',
      BiometricEnrollmentResult.denied =>
        'Android no pudo confirmar la activación biométrica.',
      BiometricEnrollmentResult.identityChanged =>
        'La cuenta cambió durante la operación. '
            'El acceso deberá verificarse nuevamente.',
      BiometricEnrollmentResult.invalidSession =>
        'La sesión no pudo validarse. '
            'Inicia sesión nuevamente para continuar.',
      BiometricEnrollmentResult.unverifiedEmail =>
        'Verifica tu correo electrónico antes de '
            'configurar la biometría.',
      BiometricEnrollmentResult.bindingMismatch =>
        'Existe una vinculación biométrica correspondiente '
            'a otra cuenta en este dispositivo.',
    };
  }

  String _bindingMessage(BiometricSettingsBindingStatus? status) {
    return switch (status) {
      null => 'Comprobando la vinculación biométrica del dispositivo...',
      BiometricSettingsBindingStatus.notAuthenticated =>
        'Necesitas iniciar sesión para consultar esta configuración.',
      BiometricSettingsBindingStatus.disabled =>
        'La biometría todavía no está configurada para esta instalación.',
      BiometricSettingsBindingStatus.enabledForCurrentUser =>
        'La biometría ya está configurada para tu cuenta.',
      BiometricSettingsBindingStatus.enabledForDifferentUser =>
        'Este dispositivo tiene una vinculación biométrica '
            'correspondiente a otra cuenta.',
      BiometricSettingsBindingStatus.unavailable =>
        'No fue posible comprobar de forma segura '
            'la vinculación biométrica.',
      BiometricSettingsBindingStatus.identityChanged =>
        'La cuenta cambió durante la comprobación. '
            'Vuelve a ingresar para continuar.',
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
        final controller = widget.controller;

        final busy = controller.isBusy;
        final status = controller.bindingStatus;
        final resultMessage = _resultMessage(controller.lastResult);

        final canActivate =
            widget.isAccountReady && controller.canConfigureBiometrics;

        final buttonLabel = busy
            ? 'Comprobando biometría...'
            : status == BiometricSettingsBindingStatus.enabledForCurrentUser
            ? 'Biometría configurada'
            : 'Configurar biometría';

        return Card(
          key: const Key('settings-biometric-card'),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.fingerprint_rounded,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Acceso biométrico',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Configura la huella digital para proteger '
                            'el acceso a tu cuenta de Sendaris.',
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
                const SizedBox(height: 16),
                Text(
                  _bindingMessage(status),
                  key: const Key('settings-biometric-binding-status'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                if (!widget.isAccountReady) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Necesitas una sesión activa y un correo '
                    'verificado para configurar esta opción.',
                    key: Key('settings-biometric-account-not-ready'),
                  ),
                ],
                if (resultMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    resultMessage,
                    key: const Key('settings-biometric-feedback'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const Key('settings-biometric-activate'),
                  onPressed: canActivate
                      ? () => unawaited(_confirmActivation(context))
                      : null,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.fingerprint_rounded),
                  label: Text(buttonLabel),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
