import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';
import 'package:sendaris/features/atypical_situation/domain/repositories/atypical_situation_repository.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_id_generator.dart';
import 'package:sendaris/features/atypical_situation/presentation/views/atypical_situation_form_view.dart';

void main() {
  group('AtypicalSituationFormView', () {
    late _FakeAtypicalSituationRepository repository;

    setUp(() {
      repository = _FakeAtypicalSituationRepository();
    });

    testWidgets(
      'muestra el patrón de creación y los tres campos obligatorios',
      (tester) async {
        await _pumpView(tester, repository);

        final scrollable = find.byType(Scrollable).first;

        expect(find.text('Registrar otra situación'), findsOneWidget);

        expect(find.text('Registro de otra situación'), findsOneWidget);

        expect(find.text('Añade un acontecimiento'), findsNothing);

        expect(find.textContaining('seguimiento actual'), findsOneWidget);

        expect(find.textContaining('perfil activo'), findsNothing);

        expect(find.textContaining('identificador anónimo'), findsNothing);

        expect(find.text('Cuándo ocurrió'), findsOneWidget);

        expect(find.text('Sin seleccionar'), findsOneWidget);

        expect(find.text('Qué ocurrió'), findsOneWidget);

        final dateCard = find
            .ancestor(
              of: find.text('Cuándo ocurrió'),
              matching: find.byType(Card),
            )
            .first;

        expect(
          find.descendant(of: dateCard, matching: find.text('Obligatorio')),
          findsOneWidget,
        );

        final categoryCard = find
            .ancestor(of: find.text('Qué ocurrió'), matching: find.byType(Card))
            .first;

        expect(
          find.descendant(of: categoryCard, matching: find.text('Obligatorio')),
          findsOneWidget,
        );

        final description = find.text('Descripción');

        await tester.scrollUntilVisible(
          description,
          300,
          scrollable: scrollable,
        );

        await tester.pump();

        expect(description, findsOneWidget);

        final descriptionCard = find
            .ancestor(of: description, matching: find.byType(Card))
            .first;

        expect(
          find.descendant(
            of: descriptionCard,
            matching: find.text('Obligatorio'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'muestra las siete categorías sin checks y permite deseleccionarlas',
      (tester) async {
        await _pumpView(tester, repository);

        for (final category in AtypicalSituationCategory.values) {
          expect(find.text(category.label), findsOneWidget);
        }

        final scrollable = find.byType(Scrollable).first;

        final chip = find.byKey(
          const Key('atypical-situation-category-evento_inesperado'),
        );

        await tester.scrollUntilVisible(chip, 250, scrollable: scrollable);

        await tester.pump();

        var choiceChip = tester.widget<ChoiceChip>(chip);

        expect(choiceChip.selected, isFalse);

        expect(choiceChip.showCheckmark, isFalse);

        await tester.tap(chip);

        await tester.pump();

        choiceChip = tester.widget<ChoiceChip>(chip);

        expect(choiceChip.selected, isTrue);

        expect(choiceChip.showCheckmark, isFalse);

        await tester.tap(chip);

        await tester.pump();

        choiceChip = tester.widget<ChoiceChip>(chip);

        expect(choiceChip.selected, isFalse);
      },
    );

    testWidgets(
      'muestra los errores obligatorios y los oculta después de unos segundos',
      (tester) async {
        await _pumpView(tester, repository);

        final scrollable = find.byType(Scrollable).first;

        final saveButton = find.byKey(
          const Key('atypical-situation-save-button'),
        );

        await tester.scrollUntilVisible(
          saveButton,
          300,
          scrollable: scrollable,
        );

        await tester.pump();

        await tester.tap(saveButton);

        await tester.pump();

        await tester.pump(const Duration(milliseconds: 750));

        expect(find.text('Selecciona una fecha.'), findsOneWidget);

        final categoryError = find.text(
          'Selecciona una categoría para continuar.',
        );

        await tester.scrollUntilVisible(
          categoryError,
          250,
          scrollable: scrollable,
        );

        await tester.pump();

        expect(categoryError, findsOneWidget);

        final descriptionField = find.byKey(
          const Key('atypical-situation-observation-field'),
        );

        await tester.scrollUntilVisible(
          descriptionField,
          250,
          scrollable: scrollable,
        );

        await tester.pump();

        expect(find.text('Describe brevemente lo ocurrido.'), findsOneWidget);

        expect(repository.savedRecords, isEmpty);

        await tester.pump(const Duration(seconds: 5));

        await tester.pump();

        expect(find.text('Selecciona una fecha.'), findsNothing);

        expect(
          find.text('Selecciona una categoría para continuar.'),
          findsNothing,
        );

        expect(find.text('Describe brevemente lo ocurrido.'), findsNothing);
      },
    );

    testWidgets(
      'guarda una situación válida y regresa a la pantalla anterior',
      (tester) async {
        await _pumpView(tester, repository);

        final scrollable = find.byType(Scrollable).first;

        final datePicker = find.byKey(
          const Key('atypical-situation-date-picker'),
        );

        await tester.tap(datePicker);

        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(TextButton, 'Seleccionar').last);

        await tester.pumpAndSettle();

        final categoryChip = find.byKey(
          const Key('atypical-situation-category-evento_inesperado'),
        );

        await tester.scrollUntilVisible(
          categoryChip,
          250,
          scrollable: scrollable,
        );

        await tester.pump();

        await tester.tap(categoryChip);

        await tester.pump();

        final selectedChip = tester.widget<ChoiceChip>(categoryChip);

        expect(selectedChip.selected, isTrue);

        expect(selectedChip.showCheckmark, isFalse);

        final descriptionField = find.byKey(
          const Key('atypical-situation-observation-field'),
        );

        await tester.scrollUntilVisible(
          descriptionField,
          300,
          scrollable: scrollable,
        );

        await tester.pump();

        await tester.enterText(
          descriptionField,
          'La actividad prevista se realizó '
          'en un lugar diferente.',
        );

        final saveButton = find.byKey(
          const Key('atypical-situation-save-button'),
        );

        await tester.scrollUntilVisible(
          saveButton,
          300,
          scrollable: scrollable,
        );

        await tester.pump();

        await tester.tap(saveButton);

        await tester.pump();

        await tester.pump(const Duration(milliseconds: 500));

        expect(repository.savedRecords, hasLength(1));

        final record = repository.savedRecords.single;

        expect(record.category, AtypicalSituationCategory.unexpectedEvent);

        expect(
          record.observation,
          'La actividad prevista se realizó '
          'en un lugar diferente.',
        );

        expect(find.text('Destino Registrar'), findsOneWidget);

        expect(find.text('Situación guardada correctamente.'), findsOneWidget);
      },
    );
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeAtypicalSituationRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-atypical-situation-form'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AtypicalSituationFormView(
                        repository: repository,
                        recordFactory: const AtypicalSituationRecordFactory(
                          _FakeRecordIdGenerator(),
                        ),
                        anonymousId: 'anonimo-test',
                      ),
                    ),
                  );
                },
                child: const Text('Destino Registrar'),
              ),
            ),
          );
        },
      ),
    ),
  );

  await tester.tap(find.byKey(const Key('open-atypical-situation-form')));

  await tester.pumpAndSettle();
}

class _FakeAtypicalSituationRepository implements AtypicalSituationRepository {
  final List<AtypicalSituationRecord> savedRecords = [];

  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<List<AtypicalSituationRecord>> recoverAtypicalSituations({
    required String anonymousId,
  }) async {
    return [];
  }
}

class _FakeRecordIdGenerator implements AtypicalSituationRecordIdGenerator {
  const _FakeRecordIdGenerator();

  @override
  String generate() {
    return 'situacion-widget-test';
  }
}
