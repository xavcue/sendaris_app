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
            HistoryRecord(
              recordId: 'desregulacion-1',
              anonymousId: 'perfil-a',
              type: HistoryRecordType.dysregulation,
              eventDate: DateTime(2026, 9, 15, 16, 45),
            ),
            HistoryRecord(
              recordId: 'sueno-1',
              anonymousId: 'perfil-a',
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
          HistoryRecord(
            recordId: 'antiguo',
            anonymousId: 'perfil-a',
            type: HistoryRecordType.behavior,
            eventDate: DateTime(2026, 9, 13),
          ),
          HistoryRecord(
            recordId: 'reciente',
            anonymousId: 'perfil-a',
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
        HistoryRecord(
          recordId: 'conducta-1',
          anonymousId: 'perfil-a',
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
          HistoryRecord(
            recordId: 'conducta-1',
            anonymousId: 'perfil-a',
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
  });
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
