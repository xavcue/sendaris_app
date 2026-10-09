import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_record.dart';
import 'package:sendaris/features/social_interaction/presentation/views/social_interaction_detail_view.dart';

void main() {
  group('SocialInteractionDetailView', () {
    testWidgets(
      'muestra todos los datos funcionales sin exponer identificadores',
      (tester) async {
        await _pumpView(tester, _record());

        expect(find.text('Detalle de interacción social'), findsOneWidget);

        expect(find.text('Registro de interacción social'), findsOneWidget);

        expect(find.text('Categoría'), findsOneWidget);

        expect(find.text('Intercambio social'), findsNWidgets(2));

        expect(find.text('Fecha'), findsOneWidget);

        expect(find.text('22 sep 2026'), findsNWidgets(2));

        expect(find.text('Contexto'), findsOneWidget);

        expect(find.text('Actividad recreativa'), findsOneWidget);

        expect(find.text('Observación'), findsOneWidget);

        expect(find.text('Registro ficticio descriptivo.'), findsOneWidget);

        expect(find.text('interaccion-1'), findsNothing);

        expect(find.text('seguimiento-actual'), findsNothing);

        expect(find.textContaining('UUID'), findsNothing);

        expect(find.textContaining('identificador'), findsNothing);
      },
    );

    testWidgets(
      'muestra Sin contexto cuando el campo opcional no fue registrado',
      (tester) async {
        await _pumpView(tester, _record(context: null));

        expect(find.text('Contexto'), findsOneWidget);

        expect(find.text('Sin contexto'), findsOneWidget);
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

Future<void> _pumpView(
  WidgetTester tester,
  SocialInteractionRecord record,
) async {
  await tester.pumpWidget(
    MaterialApp(home: SocialInteractionDetailView(record: record)),
  );

  await tester.pumpAndSettle();
}

SocialInteractionRecord _record({
  String? context = 'Actividad recreativa',
  String? observation = 'Registro ficticio descriptivo.',
}) {
  return SocialInteractionRecord(
    recordId: 'interaccion-1',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 22),
    category: SocialInteractionCategory.socialExchange,
    context: context,
    observation: observation,
    createdAt: DateTime.utc(2026, 9, 22, 18),
    updatedAt: DateTime.utc(2026, 9, 22, 18),
  );
}
