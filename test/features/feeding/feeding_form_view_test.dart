import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_record.dart';
import 'package:sendaris/features/feeding/domain/repositories/feeding_repository.dart';
import 'package:sendaris/features/feeding/domain/services/feeding_record_factory.dart';
import 'package:sendaris/features/feeding/domain/services/feeding_record_id_generator.dart';
import 'package:sendaris/features/feeding/presentation/views/feeding_form_view.dart';

void main() {
  group('FeedingFormView', () {
    late _FakeFeedingRepository repository;

    setUp(() {
      repository = _FakeFeedingRepository();
    });

    testWidgets(
      'muestra la estructura descriptiva y la fecha sin seleccionar',
      (tester) async {
        await _pumpView(tester, repository);

        expect(find.text('Registrar alimentación'), findsOneWidget);

        expect(find.text('Registro de alimentación'), findsOneWidget);

        expect(find.text('Cuándo ocurrió'), findsOneWidget);

        expect(find.text('Tipo de alimentación'), findsOneWidget);

        expect(find.text('Sin seleccionar'), findsOneWidget);

        expect(find.text('Obligatorio'), findsNWidgets(2));

        expect(find.textContaining('no calcula calorías'), findsOneWidget);

        expect(find.textContaining('análisis'), findsOneWidget);

        expect(find.textContaining('peso'), findsNothing);

        expect(find.textContaining('nutrientes'), findsNothing);

        expect(find.textContaining('diagnóstico'), findsNothing);
      },
    );

    testWidgets(
      'muestra las cinco categorías sin checks y permite deseleccionarlas',
      (tester) async {
        await _pumpView(tester, repository);

        expect(find.text('Desayuno'), findsOneWidget);

        expect(find.text('Refrigerio'), findsOneWidget);

        expect(find.text('Almuerzo'), findsOneWidget);

        expect(find.text('Merienda / cena'), findsOneWidget);

        expect(find.text('Otro'), findsOneWidget);

        final chip = find.byKey(const Key('feeding-category-almuerzo'));

        var widget = tester.widget<ChoiceChip>(chip);

        expect(widget.selected, isFalse);

        expect(widget.showCheckmark, isFalse);

        await tester.tap(chip);
        await tester.pump();

        widget = tester.widget<ChoiceChip>(chip);

        expect(widget.selected, isTrue);

        expect(widget.showCheckmark, isFalse);

        await tester.tap(chip);
        await tester.pump();

        widget = tester.widget<ChoiceChip>(chip);

        expect(widget.selected, isFalse);
      },
    );

    testWidgets(
      'muestra errores obligatorios y los oculta después de unos segundos',
      (tester) async {
        await _pumpView(tester, repository);

        final saveButton = find.byKey(const Key('feeding-save-button'));

        await tester.scrollUntilVisible(
          saveButton,
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.pump();

        await tester.tap(saveButton);

        await tester.pump();

        expect(find.text('Selecciona una fecha.'), findsOneWidget);

        expect(
          find.text('Selecciona una categoría de alimentación.'),
          findsOneWidget,
        );

        expect(repository.savedRecords, isEmpty);

        await tester.pump(const Duration(seconds: 5));

        await tester.pump();

        expect(find.text('Selecciona una fecha.'), findsNothing);

        expect(
          find.text('Selecciona una categoría de alimentación.'),
          findsNothing,
        );
      },
    );

    testWidgets('la observación se presenta como información opcional', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      final observation = find.byKey(const Key('feeding-observation-field'));

      await tester.scrollUntilVisible(
        observation,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pump();

      expect(observation, findsOneWidget);

      expect(find.text('Observación (opcional)'), findsOneWidget);

      expect(
        find.text(
          'Añade información descriptiva complementaria solo si es necesaria.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('guarda correctamente y regresa a Registrar', (tester) async {
      await _pumpView(tester, repository);

      final datePicker = find.byKey(const Key('feeding-date-picker'));

      await tester.tap(datePicker);

      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Seleccionar').last);

      await tester.pumpAndSettle();

      final lunchChip = find.byKey(const Key('feeding-category-almuerzo'));

      await tester.tap(lunchChip);

      await tester.pump();

      final observation = find.byKey(const Key('feeding-observation-field'));

      await tester.scrollUntilVisible(
        observation,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.enterText(observation, 'Registro ficticio descriptivo.');

      final saveButton = find.byKey(const Key('feeding-save-button'));

      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.tap(saveButton);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 400));

      expect(repository.savedRecords, hasLength(1));

      final record = repository.savedRecords.single;

      expect(record.category, FeedingCategory.lunch);

      expect(record.observation, 'Registro ficticio descriptivo.');

      expect(find.text('Destino Registrar'), findsOneWidget);

      expect(
        find.text('Registro de alimentación guardado correctamente.'),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeFeedingRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-feeding-form'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => FeedingFormView(
                        repository: repository,
                        recordFactory: const FeedingRecordFactory(
                          _FakeFeedingRecordIdGenerator(),
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

  await tester.tap(find.byKey(const Key('open-feeding-form')));

  await tester.pumpAndSettle();
}

class _FakeFeedingRepository implements FeedingRepository {
  final List<FeedingRecord> savedRecords = [];

  @override
  Future<void> saveFeeding(FeedingRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  }) async {
    return [];
  }
}

class _FakeFeedingRecordIdGenerator implements FeedingRecordIdGenerator {
  const _FakeFeedingRecordIdGenerator();

  @override
  String generate() {
    return 'registro-alimentacion-widget';
  }
}
