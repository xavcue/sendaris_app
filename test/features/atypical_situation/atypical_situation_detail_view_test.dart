import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';
import 'package:sendaris/features/atypical_situation/presentation/views/atypical_situation_detail_view.dart';

void main() {
  group('AtypicalSituationDetailView', () {
    testWidgets('muestra fecha categoría y descripción registradas', (
      tester,
    ) async {
      await _pumpDetail(tester, _record());

      expect(find.text('Detalle de otra situación'), findsOneWidget);

      expect(find.text('Registro de otra situación'), findsOneWidget);

      expect(find.text('Evento inesperado'), findsNWidgets(2));

      expect(find.text('22 sep 2026'), findsNWidgets(2));

      expect(
        find.text('Se suspendió una actividad programada.'),
        findsOneWidget,
      );
    });

    testWidgets('usa la nomenclatura descriptiva aprobada', (tester) async {
      await _pumpDetail(
        tester,
        _record(
          category: AtypicalSituationCategory.scheduleChange,
          observation: 'Se modificó el horario previsto.',
        ),
      );

      expect(find.text('Fecha'), findsOneWidget);

      expect(find.text('Categoría'), findsOneWidget);

      expect(find.text('Descripción'), findsOneWidget);

      expect(find.text('Cambio de horario'), findsNWidgets(2));

      expect(find.text('Se modificó el horario previsto.'), findsOneWidget);
    });

    testWidgets('no expone identificadores técnicos', (tester) async {
      await _pumpDetail(tester, _record());

      expect(find.text('situacion-test'), findsNothing);

      expect(find.text('seguimiento-actual'), findsNothing);
    });
  });
}

Future<void> _pumpDetail(
  WidgetTester tester,
  AtypicalSituationRecord record,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));

  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(home: AtypicalSituationDetailView(record: record)),
  );

  await tester.pumpAndSettle();
}

AtypicalSituationRecord _record({
  AtypicalSituationCategory category =
      AtypicalSituationCategory.unexpectedEvent,
  String observation = 'Se suspendió una actividad programada.',
}) {
  return AtypicalSituationRecord(
    recordId: 'situacion-test',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 22),
    category: category,
    observation: observation,
    createdAt: DateTime.utc(2026, 9, 22, 12),
    updatedAt: DateTime.utc(2026, 9, 22, 12),
  );
}
