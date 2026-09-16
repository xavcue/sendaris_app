import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/history/domain/exceptions/history_failure.dart';
import 'package:sendaris/features/history/domain/models/history_record.dart';
import 'package:sendaris/features/history/domain/models/history_record_type.dart';
import 'package:sendaris/features/history/domain/repositories/history_repository.dart';
import 'package:sendaris/features/history/presentation/views/history_view.dart';

void main() {
  group('HistoryView', () {
    testWidgets('muestra un estado de carga mientras recupera el historial', (
      tester,
    ) async {
      final repository = _FakeHistoryRepository();

      repository.pendingLoad = Completer<List<HistoryRecord>>();

      await _pumpView(tester, repository);

      await tester.pump();

      expect(find.byKey(const Key('history-loading-state')), findsOneWidget);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      repository.pendingLoad!.complete(const []);

      await tester.pumpAndSettle();
    });

    testWidgets(
      'muestra tipo y fecha de los registros con lenguaje orientado al usuario',
      (tester) async {
        final repository = _FakeHistoryRepository(
          records: [
            _record(
              recordId: 'desregulacion-1',
              type: HistoryRecordType.dysregulation,
              eventDate: DateTime(2026, 9, 15, 16, 45),
            ),
            _record(
              recordId: 'sueno-1',
              type: HistoryRecordType.sleep,
              eventDate: DateTime(2026, 9, 14, 8),
            ),
          ],
        );

        await _pumpView(tester, repository);

        expect(find.text('Historial'), findsOneWidget);

        expect(find.text('Consulta tus registros'), findsOneWidget);

        expect(find.text('Desregulación'), findsOneWidget);

        expect(find.text('Sueño'), findsOneWidget);

        expect(find.text('15 sep 2026'), findsOneWidget);

        expect(find.text('14 sep 2026'), findsOneWidget);

        expect(find.text('Más reciente'), findsOneWidget);

        expect(find.textContaining('identificador interno'), findsNothing);

        expect(find.textContaining('seguimiento anónimo'), findsNothing);

        expect(find.textContaining('uid'), findsNothing);
      },
    );

    testWidgets('presenta los registros del más reciente al más antiguo', (
      tester,
    ) async {
      final repository = _FakeHistoryRepository(
        records: [
          _record(
            recordId: 'antiguo',
            type: HistoryRecordType.behavior,
            eventDate: DateTime(2026, 9, 13),
          ),
          _record(
            recordId: 'reciente',
            type: HistoryRecordType.dysregulation,
            eventDate: DateTime(2026, 9, 15),
          ),
        ],
      );

      await _pumpView(tester, repository);

      final recentCard = find.byKey(const Key('history-record-reciente'));

      final oldCard = find.byKey(const Key('history-record-antiguo'));

      expect(recentCard, findsOneWidget);

      expect(oldCard, findsOneWidget);

      expect(
        tester.getTopLeft(recentCard).dy,
        lessThan(tester.getTopLeft(oldCard).dy),
      );
    });

    testWidgets('muestra un estado vacío cuando no existen registros', (
      tester,
    ) async {
      final repository = _FakeHistoryRepository();

      await _pumpView(tester, repository);

      expect(find.byKey(const Key('history-empty-state')), findsOneWidget);

      expect(find.text('Aún no hay registros'), findsOneWidget);

      expect(find.textContaining('aparecerá aquí'), findsOneWidget);

      expect(find.byKey(const Key('history-filter-card')), findsNothing);
    });

    testWidgets(
      'muestra un error controlado cuando no puede cargar el historial',
      (tester) async {
        final repository = _FakeHistoryRepository(
          error: const HistoryFailure(
            'No tienes autorización para consultar este historial.',
          ),
        );

        await _pumpView(tester, repository);

        expect(find.byKey(const Key('history-error-state')), findsOneWidget);

        expect(find.text('No pudimos cargar el historial'), findsOneWidget);

        expect(
          find.text('No tienes autorización para consultar este historial.'),
          findsOneWidget,
        );

        expect(find.byKey(const Key('history-retry-button')), findsOneWidget);
      },
    );

    testWidgets('permite reintentar después de un error', (tester) async {
      final repository = _FakeHistoryRepository(
        error: const HistoryFailure('Error controlado.'),
      );

      await _pumpView(tester, repository);

      expect(repository.requestedAnonymousIds, ['perfil-a']);

      repository.error = null;

      repository.records = [
        _record(
          recordId: 'conducta-1',
          type: HistoryRecordType.behavior,
          eventDate: DateTime(2026, 9, 15),
        ),
      ];

      await tester.tap(find.byKey(const Key('history-retry-button')));

      await tester.pumpAndSettle();

      expect(repository.requestedAnonymousIds, ['perfil-a', 'perfil-a']);

      expect(find.text('Conducta'), findsOneWidget);

      expect(find.byKey(const Key('history-error-state')), findsNothing);
    });

    testWidgets('el botón actualizar vuelve a consultar el historial', (
      tester,
    ) async {
      final repository = _FakeHistoryRepository(
        records: [
          _record(
            recordId: 'conducta-1',
            type: HistoryRecordType.behavior,
            eventDate: DateTime(2026, 9, 15),
          ),
        ],
      );

      await _pumpView(tester, repository);

      expect(repository.requestedAnonymousIds, ['perfil-a']);

      await tester.tap(find.byKey(const Key('history-refresh-button')));

      await tester.pumpAndSettle();

      expect(repository.requestedAnonymousIds, ['perfil-a', 'perfil-a']);
    });

    testWidgets('permite desplegar y ocultar el panel de filtros', (
      tester,
    ) async {
      final repository = _FakeHistoryRepository(records: _filterRecords());

      await _pumpView(tester, repository);

      expect(find.byKey(const Key('history-filter-panel')), findsNothing);

      await tester.tap(find.byKey(const Key('history-filter-toggle-button')));

      await tester.pump();

      expect(find.byKey(const Key('history-filter-panel')), findsOneWidget);

      await tester.tap(find.byKey(const Key('history-filter-toggle-button')));

      await tester.pump();

      expect(find.byKey(const Key('history-filter-panel')), findsNothing);
    });

    testWidgets(
      'filtra por un tipo de registro sin volver a consultar el repositorio',
      (tester) async {
        final repository = _FakeHistoryRepository(records: _filterRecords());

        await _pumpView(tester, repository);

        await _openFilters(tester);

        final sleepChip = find.byKey(const Key('history-filter-type-sueno'));

        await tester.ensureVisible(sleepChip);

        await tester.tap(sleepChip);

        final applyButton = find.byKey(
          const Key('history-apply-filters-button'),
        );

        await tester.ensureVisible(applyButton);

        await tester.tap(applyButton);

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('history-record-sueno-15')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('history-record-conducta-10')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('history-active-filters-indicator')),
          findsOneWidget,
        );

        expect(repository.requestedAnonymousIds, ['perfil-a']);
      },
    );

    testWidgets('permite filtrar por más de un tipo de registro', (
      tester,
    ) async {
      final repository = _FakeHistoryRepository(records: _filterRecords());

      await _pumpView(tester, repository);

      await _openFilters(tester);

      final behaviorChip = find.byKey(
        const Key('history-filter-type-conducta'),
      );

      final sleepChip = find.byKey(const Key('history-filter-type-sueno'));

      await tester.ensureVisible(behaviorChip);

      await tester.tap(behaviorChip);

      await tester.ensureVisible(sleepChip);

      await tester.tap(sleepChip);

      final applyButton = find.byKey(const Key('history-apply-filters-button'));

      await tester.ensureVisible(applyButton);

      await tester.tap(applyButton);

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-record-sueno-15')), findsOneWidget);

      expect(
        find.byKey(const Key('history-record-conducta-10')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('history-record-desregulacion-15')),
        findsNothing,
      );
    });

    testWidgets(
      'permite seleccionar un periodo y muestra únicamente sus registros',
      (tester) async {
        final repository = _FakeHistoryRepository(records: _filterRecords());

        await _pumpView(tester, repository);

        await _openFilters(tester);

        final startButton = find.byKey(const Key('history-start-date-button'));

        await tester.ensureVisible(startButton);

        await tester.tap(startButton);

        await tester.pumpAndSettle();

        expect(find.byType(DatePickerDialog), findsOneWidget);

        await tester.tap(find.text('10').last);

        await tester.tap(find.text('Aceptar'));

        await tester.pumpAndSettle();

        final endButton = find.byKey(const Key('history-end-date-button'));

        await tester.ensureVisible(endButton);

        await tester.tap(endButton);

        await tester.pumpAndSettle();

        expect(find.byType(DatePickerDialog), findsOneWidget);

        await tester.tap(find.text('15').last);

        await tester.tap(find.text('Aceptar'));

        await tester.pumpAndSettle();

        final applyButton = find.byKey(
          const Key('history-apply-filters-button'),
        );

        await tester.ensureVisible(applyButton);

        await tester.tap(applyButton);

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('history-record-antiguo-5')), findsNothing);

        expect(
          find.byKey(const Key('history-record-conducta-10')),
          findsOneWidget,
        );

        expect(
          find.byKey(const Key('history-record-sueno-15')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'muestra estado sin coincidencias cuando el filtro no produce resultados',
      (tester) async {
        final repository = _FakeHistoryRepository(records: _filterRecords());

        await _pumpView(tester, repository);

        await _openFilters(tester);

        final socialChip = find.byKey(
          const Key('history-filter-type-interaccionSocial'),
        );

        await tester.ensureVisible(socialChip);

        await tester.tap(socialChip);

        final applyButton = find.byKey(
          const Key('history-apply-filters-button'),
        );

        await tester.ensureVisible(applyButton);

        await tester.tap(applyButton);

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('history-no-filter-results')),
          findsOneWidget,
        );

        expect(find.text('No hay registros que coincidan'), findsOneWidget);
      },
    );

    testWidgets('quitar filtros restaura todos los registros', (tester) async {
      final repository = _FakeHistoryRepository(records: _filterRecords());

      await _pumpView(tester, repository);

      await _openFilters(tester);

      final sleepChip = find.byKey(const Key('history-filter-type-sueno'));

      await tester.ensureVisible(sleepChip);

      await tester.tap(sleepChip);

      final applyButton = find.byKey(const Key('history-apply-filters-button'));

      await tester.ensureVisible(applyButton);

      await tester.tap(applyButton);

      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-record-conducta-10')), findsNothing);

      expect(find.text('1 de 5 registros visibles'), findsOneWidget);

      await _openFilters(tester);

      final clearButton = find.byKey(const Key('history-clear-filters-button'));

      await _scrollHistoryUntilVisible(tester, clearButton);

      await tester.tap(clearButton);

      await tester.pumpAndSettle();

      final clearButtonWidget = tester.widget<OutlinedButton>(clearButton);

      expect(clearButtonWidget.onPressed, isNull);

      expect(
        find.byKey(const Key('history-active-filters-indicator')),
        findsNothing,
      );

      expect(
        find.text('Filtra por periodo y tipo de registro.'),
        findsOneWidget,
      );

      expect(find.text('1 de 5 registros visibles'), findsNothing);

      expect(repository.requestedAnonymousIds, ['perfil-a']);
    });

    testWidgets(
      'el botón del estado sin coincidencias también restaura la vista completa',
      (tester) async {
        final repository = _FakeHistoryRepository(records: _filterRecords());

        await _pumpView(tester, repository);

        await _openFilters(tester);

        final socialChip = find.byKey(
          const Key('history-filter-type-interaccionSocial'),
        );

        await tester.ensureVisible(socialChip);

        await tester.tap(socialChip);

        final applyButton = find.byKey(
          const Key('history-apply-filters-button'),
        );

        await tester.ensureVisible(applyButton);

        await tester.tap(applyButton);

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('history-no-filter-results')),
          findsOneWidget,
        );

        final clearButton = find.byKey(
          const Key('history-no-results-clear-button'),
        );

        await tester.ensureVisible(clearButton);

        await tester.tap(clearButton);

        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('history-no-filter-results')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('history-active-filters-indicator')),
          findsNothing,
        );

        expect(
          find.byKey(const Key('history-record-desregulacion-15')),
          findsOneWidget,
        );

        expect(repository.requestedAnonymousIds, ['perfil-a']);
      },
    );

    testWidgets('el panel presenta los siete tipos permitidos', (tester) async {
      final repository = _FakeHistoryRepository(records: _filterRecords());

      await _pumpView(tester, repository);

      await _openFilters(tester);

      for (final type in HistoryRecordType.values) {
        final chip = find.byKey(Key('history-filter-type-${type.code}'));

        await tester.ensureVisible(chip);

        expect(chip, findsOneWidget);
      }
    });
  });
}

Future<void> _scrollHistoryUntilVisible(
  WidgetTester tester,
  Finder target,
) async {
  final historyList = find.byKey(const Key('history-records-list'));

  final scrollable = find.descendant(
    of: historyList,
    matching: find.byType(Scrollable),
  );

  expect(scrollable, findsOneWidget);

  await tester.scrollUntilVisible(target, 250, scrollable: scrollable);

  await tester.pumpAndSettle();
}

Future<void> _openFilters(WidgetTester tester) async {
  final toggle = find.byKey(const Key('history-filter-toggle-button'));

  await tester.ensureVisible(toggle);

  await tester.tap(toggle);

  await tester.pump();

  expect(find.byKey(const Key('history-filter-panel')), findsOneWidget);
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeHistoryRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: HistoryView(repository: repository, anonymousId: 'perfil-a'),
    ),
  );

  await tester.pump();
}

List<HistoryRecord> _filterRecords() {
  return [
    _record(
      recordId: 'antiguo-5',
      type: HistoryRecordType.behavior,
      eventDate: DateTime(2026, 9, 5, 12),
    ),
    _record(
      recordId: 'alimentacion-10',
      type: HistoryRecordType.feeding,
      eventDate: DateTime(2026, 9, 10, 8),
    ),
    _record(
      recordId: 'conducta-10',
      type: HistoryRecordType.behavior,
      eventDate: DateTime(2026, 9, 10, 18),
    ),
    _record(
      recordId: 'sueno-15',
      type: HistoryRecordType.sleep,
      eventDate: DateTime(2026, 9, 15, 7),
    ),
    _record(
      recordId: 'desregulacion-15',
      type: HistoryRecordType.dysregulation,
      eventDate: DateTime(2026, 9, 15, 19),
    ),
  ];
}

HistoryRecord _record({
  required String recordId,
  required HistoryRecordType type,
  required DateTime eventDate,
}) {
  return HistoryRecord(
    recordId: recordId,
    anonymousId: 'perfil-a',
    type: type,
    eventDate: eventDate,
  );
}

class _FakeHistoryRepository implements HistoryRepository {
  _FakeHistoryRepository({List<HistoryRecord> records = const [], this.error})
    : records = List<HistoryRecord>.from(records);

  List<HistoryRecord> records;

  Object? error;

  Completer<List<HistoryRecord>>? pendingLoad;

  final List<String> requestedAnonymousIds = [];

  @override
  Future<List<HistoryRecord>> recoverHistory({
    required String anonymousId,
  }) async {
    requestedAnonymousIds.add(anonymousId);

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    final currentPendingLoad = pendingLoad;

    if (currentPendingLoad != null) {
      return currentPendingLoad.future;
    }

    return List.unmodifiable(records);
  }
}
