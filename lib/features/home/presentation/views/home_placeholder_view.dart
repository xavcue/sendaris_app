import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/viewmodels/auth_view_model.dart';

class HomePlaceholderView extends StatelessWidget {
  const HomePlaceholderView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sendaris'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () async {
              final authViewModel = context.read<AuthViewModel>();

              final success = await authViewModel.signOut();

              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      authViewModel.errorMessage ??
                          'No fue posible cerrar la sesión.',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: const SafeArea(
        child: Center(
          child: Text(
            'Sesión autenticada',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
