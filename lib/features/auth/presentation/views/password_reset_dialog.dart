import 'package:flutter/material.dart';

import '../../domain/repositories/password_reset_repository.dart';
import '../viewmodels/password_reset_view_model.dart';

class PasswordResetDialog extends StatefulWidget {
  const PasswordResetDialog({
    required this.repository,
    this.initialEmail = '',
    super.key,
  });

  final PasswordResetRepository repository;
  final String initialEmail;

  @override
  State<PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<PasswordResetDialog> {
  late final PasswordResetViewModel _viewModel;

  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();

    _viewModel = PasswordResetViewModel(widget.repository);

    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _emailController.dispose();

    super.dispose();
  }

  Future<void> _submit() async {
    if (_viewModel.isLoading || _viewModel.isSent) {
      return;
    }

    FocusScope.of(context).unfocus();

    await _viewModel.requestPasswordReset(email: _emailController.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: _viewModel,
      builder: (context, child) {
        return AlertDialog(
          key: const Key('password-reset-dialog'),
          title: Row(
            children: [
              Icon(Icons.mark_email_read_outlined, color: colorScheme.primary),
              const SizedBox(width: 12),
              const Expanded(child: Text('Recuperar contraseña')),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_viewModel.isSent) ...[
                  Text(
                    'Ingresa el correo electrónico de tu cuenta '
                    'para solicitar un enlace que te permita '
                    'restablecer tu contraseña.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    key: const Key('password-reset-email-field'),
                    controller: _emailController,
                    enabled: !_viewModel.isLoading,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      hintText: 'correo@ejemplo.com',
                      prefixIcon: Icon(Icons.mail_outline_rounded),
                    ),
                    onChanged: (_) {
                      _viewModel.clearError();
                    },
                    onSubmitted: (_) {
                      _submit();
                    },
                  ),
                ],
                if (_viewModel.errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _viewModel.errorMessage!,
                      key: const Key('password-reset-error'),
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ],
                if (_viewModel.isSent)
                  Semantics(
                    liveRegion: true,
                    child: Column(
                      key: const Key('password-reset-success'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          color: colorScheme.primary,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        const Text(PasswordResetViewModel.confirmationMessage),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const Key('password-reset-close-button'),
              onPressed: _viewModel.isLoading
                  ? null
                  : () => Navigator.of(context).pop(),
              child: Text(_viewModel.isSent ? 'Cerrar' : 'Cancelar'),
            ),
            if (!_viewModel.isSent)
              FilledButton(
                key: const Key('password-reset-submit-button'),
                onPressed: _viewModel.isLoading ? null : _submit,
                child: _viewModel.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Enviar enlace'),
              ),
          ],
        );
      },
    );
  }
}
