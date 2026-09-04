import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../tracking/domain/repositories/tracking_repository.dart';
import '../../../tracking/domain/services/anonymous_tracking_profile_factory.dart';
import '../../../tracking/presentation/viewmodels/tracking_view_model.dart';

class HomePlaceholderView extends StatelessWidget {
  const HomePlaceholderView({
    required this.trackingRepository,
    required this.trackingProfileFactory,
    super.key,
  });

  final TrackingRepository trackingRepository;
  final AnonymousTrackingProfileFactory trackingProfileFactory;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          TrackingViewModel(trackingRepository, trackingProfileFactory),
      child: const _HomeContent(),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    final trackingViewModel = context.watch<TrackingViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sendaris'),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: trackingViewModel.isLoading
                ? null
                : () async {
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Sesión autenticada',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Validación técnica de persistencia segura',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 32),

            FilledButton.icon(
              onPressed: trackingViewModel.isLoading
                  ? null
                  : trackingViewModel.createAndPersistProfile,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Crear y guardar perfil anónimo'),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: trackingViewModel.isLoading
                  ? null
                  : trackingViewModel.recoverProfiles,
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Recuperar desde Firestore'),
            ),

            if (trackingViewModel.isLoading) ...[
              const SizedBox(height: 24),
              const Center(child: CircularProgressIndicator()),
            ],

            if (trackingViewModel.errorMessage != null) ...[
              const SizedBox(height: 24),
              Text(
                trackingViewModel.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],

            if (trackingViewModel.successMessage != null) ...[
              const SizedBox(height: 24),
              Text(
                trackingViewModel.successMessage!,
                textAlign: TextAlign.center,
              ),
            ],

            if (trackingViewModel.profiles.isNotEmpty) ...[
              const SizedBox(height: 32),
              Text(
                'Perfiles anónimos recuperados',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              for (final profile in trackingViewModel.profiles)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ID interno anónimo',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(profile.anonymousId),
                        const SizedBox(height: 12),
                        Text(
                          'Creación: '
                          '${profile.createdAt.toLocal()}',
                        ),
                        Text(
                          'Estado: '
                          '${profile.isActive ? 'Activo' : 'Inactivo'}',
                        ),
                      ],
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
