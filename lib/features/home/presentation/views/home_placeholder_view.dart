import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../auth/presentation/viewmodels/auth_view_model.dart';
import '../../../tracking/presentation/viewmodels/tracking_view_model.dart';

class HomePlaceholderView extends StatefulWidget {
  const HomePlaceholderView({required this.trackingViewModel, super.key});

  final TrackingViewModel trackingViewModel;

  @override
  State<HomePlaceholderView> createState() => _HomePlaceholderViewState();
}

class _HomePlaceholderViewState extends State<HomePlaceholderView> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.trackingViewModel.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final trackingViewModel = context.watch<TrackingViewModel>();

    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sendaris'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
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
                                'No fue posible '
                                    'cerrar la sesión.',
                          ),
                        ),
                      );
                    }
                  },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(child: _buildBody(context, trackingViewModel)),
    );
  }

  Widget _buildBody(BuildContext context, TrackingViewModel viewModel) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    if (viewModel.isLoading && !viewModel.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!viewModel.hasActiveProfile) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: colorScheme.error,
              ),

              const SizedBox(height: 16),

              Text(
                'No fue posible preparar '
                'el seguimiento',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                viewModel.errorMessage ?? 'Inténtalo nuevamente.',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              FilledButton.icon(
                onPressed: viewModel.isLoading ? null : viewModel.initialize,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final profile = viewModel.activeProfile!;

    final shortId = profile.anonymousId.length > 8
        ? profile.anonymousId.substring(0, 8).toUpperCase()
        : profile.anonymousId.toUpperCase();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'Resumen de hoy',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          'Seguimiento $shortId',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),

        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: colorScheme.onPrimary,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Seguimiento listo',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'La información se '
                      'guardará en el ámbito '
                      'anónimo autorizado.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'Acciones rápidas',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              context.push('/register');
            },
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7A66).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.add_circle_outline,
                      color: Color(0xFFFF7A66),
                    ),
                  ),

                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Registrar',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        const Text(
                          'Añadir un nuevo '
                          'registro',
                        ),
                      ],
                    ),
                  ),

                  const Icon(Icons.arrow_forward_ios, size: 18),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Resumen del periodo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Sin datos suficientes '
                  'para mostrar un resumen '
                  'todavía.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
