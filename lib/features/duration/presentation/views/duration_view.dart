import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/repositories/duration_repository.dart';
import '../viewmodels/duration_overview_view_model.dart';
import '../widgets/duration_summary_cards.dart';

class DurationView extends StatefulWidget {
  const DurationView({
    required this.repository,
    required this.anonymousId,
    super.key,
  });

  final DurationRepository repository;
  final String anonymousId;

  @override
  State<DurationView> createState() => _DurationViewState();
}

class _DurationViewState extends State<DurationView> {
  late DurationOverviewViewModel _viewModel;

  @override
  void initState() {
    super.initState();

    _viewModel = _createViewModel();
    unawaited(_viewModel.load());
  }

  DurationOverviewViewModel _createViewModel() {
    return DurationOverviewViewModel(
      widget.repository,
      anonymousId: widget.anonymousId,
    );
  }

  @override
  void didUpdateWidget(covariant DurationView oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.anonymousId != widget.anonymousId ||
        oldWidget.repository != widget.repository) {
      final previousViewModel = _viewModel;

      _viewModel = _createViewModel();

      previousViewModel.dispose();

      unawaited(_viewModel.load());
    }
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<DurationOverviewViewModel>.value(
      value: _viewModel,
      child: const _DurationContent(),
    );
  }
}

class _DurationContent extends StatelessWidget {
  const _DurationContent();

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  Future<void> _pickDate(
    BuildContext context,
    DurationOverviewViewModel viewModel, {
    required bool isStartDate,
  }) async {
    final now = DateTime.now();

    final firstDate = DateTime(2000);
    final lastDate = DateTime(now.year + 1, 12, 31);

    final current = isStartDate ? viewModel.startDate : viewModel.endDate;

    var initialDate = current;

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }

    if (initialDate.isAfter(lastDate)) {
      initialDate = lastDate;
    }

    final selectedDate = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDate: initialDate,
      helpText: isStartDate ? 'Fecha inicial' : 'Fecha final',
      cancelText: 'Cancelar',
      confirmText: 'Aceptar',
    );

    if (!context.mounted || selectedDate == null || viewModel.isDisposed) {
      return;
    }

    final activeViewModel = context.read<DurationOverviewViewModel>();

    if (!identical(activeViewModel, viewModel)) {
      return;
    }

    await viewModel.setDate(isStartDate: isStartDate, date: selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<DurationOverviewViewModel>();

    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      key: const Key('duration-screen'),
      appBar: AppBar(title: const Text('Duraciones y promedios')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: viewModel.load,
          child: ListView(
            key: const Key('duration-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
            children: [
              Text(
                'Resumen de duraciones',
                key: const Key('duration-overview-title'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                'Consulta automáticamente las duraciones '
                'y los promedios del seguimiento actual.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Card(
                key: const Key('duration-period-filters'),
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Periodo de consulta',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Selecciona el intervalo para los '
                        'tres resúmenes.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          ChoiceChip(
                            key: const Key('duration-period-seven-days'),
                            label: const Text('Últimos 7 días'),
                            selected:
                                viewModel.selectedPeriod ==
                                DurationPeriod.sevenDays,
                            onSelected: (_) {
                              unawaited(
                                viewModel.selectPeriod(
                                  DurationPeriod.sevenDays,
                                ),
                              );
                            },
                          ),
                          ChoiceChip(
                            key: const Key('duration-period-this-month'),
                            label: const Text('Este mes'),
                            selected:
                                viewModel.selectedPeriod ==
                                DurationPeriod.thisMonth,
                            onSelected: (_) {
                              unawaited(
                                viewModel.selectPeriod(
                                  DurationPeriod.thisMonth,
                                ),
                              );
                            },
                          ),
                          ChoiceChip(
                            key: const Key('duration-period-thirty-days'),
                            label: const Text('Últimos 30 días'),
                            selected:
                                viewModel.selectedPeriod ==
                                DurationPeriod.thirtyDays,
                            onSelected: (_) {
                              unawaited(
                                viewModel.selectPeriod(
                                  DurationPeriod.thirtyDays,
                                ),
                              );
                            },
                          ),
                          ChoiceChip(
                            key: const Key('duration-period-custom'),
                            label: const Text('Personalizado'),
                            selected:
                                viewModel.selectedPeriod ==
                                DurationPeriod.custom,
                            onSelected: (_) {
                              unawaited(
                                viewModel.selectPeriod(DurationPeriod.custom),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        '${_formatDate(viewModel.startDate)} – '
                        '${_formatDate(viewModel.endDate)}',
                        key: const Key('duration-selected-period'),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (viewModel.selectedPeriod ==
                          DurationPeriod.custom) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key('duration-start-date-button'),
                                onPressed: () {
                                  unawaited(
                                    _pickDate(
                                      context,
                                      viewModel,
                                      isStartDate: true,
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.calendar_today_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  'Desde: '
                                  '${_formatDate(viewModel.startDate)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                key: const Key('duration-end-date-button'),
                                onPressed: () {
                                  unawaited(
                                    _pickDate(
                                      context,
                                      viewModel,
                                      isStartDate: false,
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.event_outlined,
                                  size: 18,
                                ),
                                label: Text(
                                  'Hasta: '
                                  '${_formatDate(viewModel.endDate)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      viewModel.isLoading
                          ? 'Actualizando duraciones…'
                          : 'Promedios descriptivos',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const Key('duration-refresh'),
                    tooltip: 'Actualizar duraciones',
                    onPressed: viewModel.isLoading
                        ? null
                        : () {
                            unawaited(viewModel.load());
                          },
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (viewModel.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: CircularProgressIndicator(
                      key: Key('duration-loading'),
                    ),
                  ),
                )
              else if (viewModel.errorMessage != null)
                Card(
                  key: const Key('duration-general-error'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline_rounded, color: colors.error),
                        const SizedBox(width: 12),
                        Expanded(child: Text(viewModel.errorMessage!)),
                      ],
                    ),
                  ),
                )
              else if (viewModel.overview != null)
                DurationSummaryCards(overview: viewModel.overview!),
            ],
          ),
        ),
      ),
    );
  }
}
