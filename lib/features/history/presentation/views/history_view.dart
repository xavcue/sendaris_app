import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/history_record.dart';
import '../../domain/models/history_record_type.dart';
import '../../domain/repositories/history_repository.dart';
import '../viewmodels/history_view_model.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({
    required this.repository,
    required this.anonymousId,
    super.key,
  });

  final HistoryRepository repository;
  final String anonymousId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          HistoryViewModel(repository, anonymousId: anonymousId)..initialize(),
      child: const _HistoryContent(),
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<HistoryViewModel>();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial'),
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            key: const Key('history-refresh-button'),
            tooltip: 'Actualizar',
            onPressed: viewModel.isLoading ? null : viewModel.reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          onRefresh: () async {
            await viewModel.reload();
          },
          child: _buildBody(context, viewModel),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HistoryViewModel viewModel) {
    if (viewModel.isLoading && !viewModel.hasLoaded) {
      return ListView(
        key: const Key('history-loading-state'),
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 180),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (viewModel.errorMessage != null && !viewModel.hasRecords) {
      return ListView(
        key: const Key('history-error-state'),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 36),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _HistoryErrorState(
            message: viewModel.errorMessage!,
            onRetry: viewModel.reload,
          ),
        ],
      );
    }

    if (viewModel.isEmpty) {
      return ListView(
        key: const Key('history-empty-state'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          _HistoryIntroCard(),
          SizedBox(height: 24),
          _HistoryEmptyState(),
        ],
      );
    }

    return ListView(
      key: const Key('history-records-list'),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const _HistoryIntroCard(),

        if (viewModel.errorMessage != null) ...[
          const SizedBox(height: 16),

          _HistoryInlineError(message: viewModel.errorMessage!),
        ],

        const SizedBox(height: 24),

        const _HistorySectionHeader(),

        const SizedBox(height: 12),

        for (final record in viewModel.records)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _HistoryRecordCard(
              key: Key('history-record-${record.recordId}'),
              record: record,
            ),
          ),
      ],
    );
  }
}

class _HistoryIntroCard extends StatelessWidget {
  const _HistoryIntroCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Container(
      key: const Key('history-intro-card'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(Icons.history_rounded, color: colorScheme.onPrimary),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consulta tus registros',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  'Revisa la información registrada '
                  'para el perfil activo, ordenada '
                  'desde la más reciente.',
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
    );
  }
}

class _HistorySectionHeader extends StatelessWidget {
  const _HistorySectionHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            'Registros',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.arrow_downward_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),

              const SizedBox(width: 5),

              Text(
                'Más reciente',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HistoryRecordCard extends StatelessWidget {
  const _HistoryRecordCard({required this.record, super.key});

  final HistoryRecord record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    final accentColor = _accentColorFor(record.type);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: accentColor.withValues(
                  alpha: theme.brightness == Brightness.dark ? 0.20 : 0.14,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                _iconFor(record.type),
                color: theme.brightness == Brightness.dark
                    ? Color.lerp(accentColor, Colors.white, 0.25)
                    : accentColor,
                size: 25,
              ),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.type.label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 16,
                        color: colorScheme.onSurfaceVariant,
                      ),

                      const SizedBox(width: 6),

                      Expanded(
                        child: Text(
                          _formatEventDate(record.eventDate),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_toggle_off_rounded,
                size: 32,
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'Aún no hay registros',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              'Cuando registres información '
              'para el perfil activo, '
              'aparecerá aquí.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryErrorState extends StatelessWidget {
  const _HistoryErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<bool> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 34, 24, 34),
        child: Column(
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.72),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: colorScheme.onErrorContainer,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'No pudimos cargar el historial',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              key: const Key('history-retry-button'),
              onPressed: () {
                onRetry();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Intentar nuevamente'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryInlineError extends StatelessWidget {
  const _HistoryInlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: colorScheme.onErrorContainer,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _iconFor(HistoryRecordType type) {
  switch (type) {
    case HistoryRecordType.behavior:
      return Icons.psychology_alt_outlined;

    case HistoryRecordType.sleep:
      return Icons.bedtime_outlined;

    case HistoryRecordType.feeding:
      return Icons.restaurant_outlined;

    case HistoryRecordType.socialInteraction:
      return Icons.groups_outlined;

    case HistoryRecordType.dysregulation:
      return Icons.sentiment_dissatisfied_outlined;

    case HistoryRecordType.atypicalSituation:
      return Icons.event_note_outlined;

    case HistoryRecordType.routineStatus:
      return Icons.event_available_outlined;
  }
}

Color _accentColorFor(HistoryRecordType type) {
  switch (type) {
    case HistoryRecordType.behavior:
      return const Color(0xFFE56F61);

    case HistoryRecordType.sleep:
      return const Color(0xFF78AFC1);

    case HistoryRecordType.feeding:
      return const Color(0xFFC9A353);

    case HistoryRecordType.socialInteraction:
      return const Color(0xFF69AA98);

    case HistoryRecordType.dysregulation:
      return const Color(0xFF8173AE);

    case HistoryRecordType.atypicalSituation:
      return const Color(0xFF9B8564);

    case HistoryRecordType.routineStatus:
      return const Color(0xFF5DAE98);
  }
}

String _formatEventDate(DateTime value) {
  final local = value.toLocal();

  const months = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];

  return '${local.day.toString().padLeft(2, '0')} '
      '${months[local.month - 1]} '
      '${local.year}';
}
