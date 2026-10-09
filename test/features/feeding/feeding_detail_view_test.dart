import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_record.dart';
import 'package:sendaris/features/feeding/presentation/views/feeding_detail_view.dart';

void main() {
  group('FeedingDetailView', () {
    testWidgets(
      'muestra todos los datos funcionales sin exponer identificadores',
      (tester) async {
        await _pumpView(tester, _record());

        expect(find.text('Detalle de alimentación'), findsOneWidget);

        expect(find.text('Registro de alimentación'), findsOneWidget);

        expect(find.text('Categoría'), findsOneWidget);

        expect(find.text('Almuerzo'), findsNWidgets(2));

        expect(find.text('Fecha'), findsOneWidget);

        expect(find.text('22 sep 2026'), findsNWidgets(2));

        expect(find.text('Observación'), findsOneWidget);

        expect(find.text('Registro ficticio descriptivo.'), findsOneWidget);

        expect(find.text('alimentacion-1'), findsNothing);

        expect(find.text('seguimiento-actual'), findsNothing);

        expect(find.textContaining('UUID'), findsNothing);

        expect(find.textContaining('identificador'), findsNothing);
      },
    );

    testWidgets(
      'muestra Sin observación cuando el campo opcional no fue registrado',
      (tester) async {
        await _pumpView(tester, _record(observation: null));

        expect(find.text('Observación'), findsOneWidget);

        expect(find.text('Sin observación'), findsOneWidget);
      },
    );
  });
}

Future<void> _pumpView(WidgetTester tester, FeedingRecord record) async {
  await tester.pumpWidget(MaterialApp(home: FeedingDetailView(record: record)));

  await tester.pumpAndSettle();
}

FeedingRecord _record({
  String? observation = 'Registro ficticio descriptivo.',
}) {
  return FeedingRecord(
    recordId: 'alimentacion-1',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 22),
    category: FeedingCategory.lunch,
    observation: observation,
    createdAt: DateTime.utc(2026, 9, 22, 18),
    updatedAt: DateTime.utc(2026, 9, 22, 18),
  );
}
