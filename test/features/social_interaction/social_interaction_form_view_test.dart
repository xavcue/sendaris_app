import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_record.dart';
import 'package:sendaris/features/social_interaction/domain/repositories/social_interaction_repository.dart';
import 'package:sendaris/features/social_interaction/domain/services/social_interaction_record_factory.dart';
import 'package:sendaris/features/social_interaction/domain/services/social_interaction_record_id_generator.dart';
import 'package:sendaris/features/social_interaction/presentation/views/social_interaction_form_view.dart';

void main() {
  group('SocialInteractionFormView', () {
    late _FakeSocialInteractionRepository repository;

    setUp(() {
      repository = _FakeSocialInteractionRepository();
    });

    testWidgets('muestra información descriptiva y fecha sin seleccionar', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      expect(find.text('Registrar interacción social'), findsOneWidget);

      expect(find.text('Registro de interacción social'), findsOneWidget);

      expect(find.text('Cuándo ocurrió'), findsOneWidget);

      expect(find.text('Categoría de interacción'), findsOneWidget);

      expect(find.text('Sin seleccionar'), findsOneWidget);

      expect(find.text('Obligatorio'), findsNWidgets(2));

      expect(
        find.textContaining('no evalúa habilidades sociales'),
        findsOneWidget,
      );

      expect(find.textContaining('puntuaciones clínicas'), findsOneWidget);

      expect(find.textContaining('nivel social'), findsNothing);

      expect(find.textContaining('severidad'), findsNothing);

      expect(find.textContaining('diagnóstico'), findsNothing);
    });

    testWidgets(
      'muestra las cinco categorías sin checks y permite deseleccionarlas',
      (tester) async {
        await _pumpView(tester, repository);

        final scrollable = find.byType(Scrollable).first;

        expect(find.text('Inicio de interacción'), findsOneWidget);

        expect(find.text('Respuesta a interacción'), findsOneWidget);

        expect(find.text('Intercambio social'), findsOneWidget);

        expect(find.text('Actividad compartida'), findsOneWidget);

        expect(find.text('Otro'), findsOneWidget);

        final chip = find.byKey(
          const Key('social-interaction-category-intercambio_social'),
        );

        await tester.scrollUntilVisible(chip, 250, scrollable: scrollable);

        await tester.pump();

        expect(chip, findsOneWidget);

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

        expect(widget.showCheckmark, isFalse);
      },
    );

    testWidgets(
      'muestra errores obligatorios y los oculta después de unos segundos',
      (tester) async {
        await _pumpView(tester, repository);

        final scrollable = find.byType(Scrollable).first;

        final saveButton = find.byKey(
          const Key('social-interaction-save-button'),
        );

        await tester.scrollUntilVisible(
          saveButton,
          300,
          scrollable: scrollable,
        );

        await tester.pump();

        await tester.tap(saveButton);

        await tester.pump();

        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Selecciona una fecha.'), findsOneWidget);

        expect(
          find.text('Selecciona una categoría de interacción social.'),
          findsOneWidget,
        );

        expect(repository.savedRecords, isEmpty);

        await tester.pump(const Duration(seconds: 5));

        await tester.pump();

        expect(find.text('Selecciona una fecha.'), findsNothing);

        expect(
          find.text('Selecciona una categoría de interacción social.'),
          findsNothing,
        );
      },
    );

    testWidgets('contexto y observación se presentan como datos opcionales', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      final scrollable = find.byType(Scrollable).first;

      final contextField = find.byKey(
        const Key('social-interaction-context-field'),
      );

      await tester.scrollUntilVisible(
        contextField,
        300,
        scrollable: scrollable,
      );

      await tester.pump();

      expect(contextField, findsOneWidget);

      expect(find.text('Contexto general (opcional)'), findsOneWidget);

      expect(
        find.text(
          'Describe brevemente dónde o bajo qué situación ocurrió, solo si es necesario.',
        ),
        findsOneWidget,
      );

      final observationField = find.byKey(
        const Key('social-interaction-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationField,
        300,
        scrollable: scrollable,
      );

      await tester.pump();

      expect(observationField, findsOneWidget);

      expect(find.text('Observación (opcional)'), findsOneWidget);
    });

    testWidgets('guarda correctamente y regresa a Registrar', (tester) async {
      await _pumpView(tester, repository);

      final scrollable = find.byType(Scrollable).first;

      final datePicker = find.byKey(
        const Key('social-interaction-date-picker'),
      );

      await tester.tap(datePicker);

      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Seleccionar').last);

      await tester.pumpAndSettle();

      final categoryChip = find.byKey(
        const Key('social-interaction-category-intercambio_social'),
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

      final contextField = find.byKey(
        const Key('social-interaction-context-field'),
      );

      await tester.scrollUntilVisible(
        contextField,
        300,
        scrollable: scrollable,
      );

      await tester.pump();

      await tester.enterText(contextField, 'Durante una actividad cotidiana.');

      final observationField = find.byKey(
        const Key('social-interaction-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationField,
        300,
        scrollable: scrollable,
      );

      await tester.pump();

      await tester.enterText(
        observationField,
        'Registro ficticio descriptivo.',
      );

      final saveButton = find.byKey(
        const Key('social-interaction-save-button'),
      );

      await tester.scrollUntilVisible(saveButton, 300, scrollable: scrollable);

      await tester.pump();

      await tester.tap(saveButton);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 500));

      expect(repository.savedRecords, hasLength(1));

      final record = repository.savedRecords.single;

      expect(record.category, SocialInteractionCategory.socialExchange);

      expect(record.context, 'Durante una actividad cotidiana.');

      expect(record.observation, 'Registro ficticio descriptivo.');

      expect(find.text('Destino Registrar'), findsOneWidget);

      expect(
        find.text('Registro de interacción social guardado correctamente.'),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeSocialInteractionRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-social-interaction-form'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SocialInteractionFormView(
                        repository: repository,
                        recordFactory: const SocialInteractionRecordFactory(
                          _FakeSocialInteractionRecordIdGenerator(),
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

  await tester.tap(find.byKey(const Key('open-social-interaction-form')));

  await tester.pumpAndSettle();
}

class _FakeSocialInteractionRepository implements SocialInteractionRepository {
  final List<SocialInteractionRecord> savedRecords = [];

  @override
  Future<void> saveSocialInteraction(SocialInteractionRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<List<SocialInteractionRecord>> recoverSocialInteractions({
    required String anonymousId,
  }) async {
    return [];
  }
}

class _FakeSocialInteractionRecordIdGenerator
    implements SocialInteractionRecordIdGenerator {
  const _FakeSocialInteractionRecordIdGenerator();

  @override
  String generate() {
    return 'registro-interaccion-social-widget';
  }
}
