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

    testWidgets(
      'muestra únicamente información descriptiva de interacción social',
      (tester) async {
        await _pumpView(tester, repository);

        expect(find.text('Registrar interacción social'), findsOneWidget);

        expect(find.text('Registro de interacción social'), findsOneWidget);

        expect(find.text('Cuándo ocurrió'), findsOneWidget);

        expect(find.text('Categoría de interacción'), findsOneWidget);

        expect(
          find.textContaining('no evalúa habilidades sociales'),
          findsOneWidget,
        );

        expect(find.textContaining('puntuaciones clínicas'), findsOneWidget);

        expect(find.textContaining('nivel social'), findsNothing);

        expect(find.textContaining('severidad'), findsNothing);

        expect(find.textContaining('diagnóstico'), findsNothing);
      },
    );

    testWidgets('muestra las cinco categorías generales definidas', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      expect(find.text('Inicio de interacción'), findsOneWidget);

      expect(find.text('Respuesta a interacción'), findsOneWidget);

      expect(find.text('Intercambio social'), findsOneWidget);

      expect(find.text('Actividad compartida'), findsOneWidget);

      expect(find.text('Otro'), findsOneWidget);
    });

    testWidgets('valida la categoría obligatoria antes de guardar', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      final saveButton = find.byKey(
        const Key('social-interaction-save-button'),
      );

      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      await tester.tap(saveButton);

      await tester.pump();

      expect(
        find.text('Selecciona una categoría de interacción social.'),
        findsOneWidget,
      );

      expect(repository.savedRecords, isEmpty);
    });

    testWidgets('contexto y observación se presentan como datos opcionales', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      final contextField = find.byKey(
        const Key('social-interaction-context-field'),
      );

      await tester.scrollUntilVisible(
        contextField,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      expect(contextField, findsOneWidget);

      expect(find.text('Contexto general'), findsOneWidget);

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
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      expect(observationField, findsOneWidget);

      expect(find.text('Observación'), findsOneWidget);

      expect(
        find.text(
          'Añade información descriptiva complementaria solo si es necesaria.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'guarda una categoría válida con contexto y observación descriptivos',
      (tester) async {
        await _pumpView(tester, repository);

        final categoryChip = find.byKey(
          const Key('social-interaction-category-intercambio_social'),
        );

        expect(categoryChip, findsOneWidget);

        await tester.scrollUntilVisible(
          categoryChip,
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.pumpAndSettle();

        await tester.tap(categoryChip);

        await tester.pump();

        final contextField = find.byKey(
          const Key('social-interaction-context-field'),
        );

        await tester.scrollUntilVisible(
          contextField,
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.pumpAndSettle();

        await tester.enterText(
          contextField,
          'Durante una actividad cotidiana.',
        );

        final observationField = find.byKey(
          const Key('social-interaction-observation-field'),
        );

        await tester.scrollUntilVisible(
          observationField,
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.pumpAndSettle();

        await tester.enterText(
          observationField,
          'Registro ficticio descriptivo.',
        );

        final saveButton = find.byKey(
          const Key('social-interaction-save-button'),
        );

        await tester.scrollUntilVisible(
          saveButton,
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.pumpAndSettle();

        await tester.tap(saveButton);

        await tester.pumpAndSettle();

        expect(repository.savedRecords, hasLength(1));

        final record = repository.savedRecords.single;

        expect(record.category, SocialInteractionCategory.socialExchange);

        expect(record.context, 'Durante una actividad cotidiana.');

        expect(record.observation, 'Registro ficticio descriptivo.');

        expect(
          find.text('Registro de interacción social guardado correctamente.'),
          findsOneWidget,
        );

        expect(find.text('Durante una actividad cotidiana.'), findsNothing);

        expect(find.text('Registro ficticio descriptivo.'), findsNothing);
      },
    );

    testWidgets('permite guardar sin contexto ni observación', (tester) async {
      await _pumpView(tester, repository);

      final categoryChip = find.byKey(
        const Key('social-interaction-category-actividad_compartida'),
      );

      expect(categoryChip, findsOneWidget);

      await tester.scrollUntilVisible(
        categoryChip,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      await tester.tap(categoryChip);

      await tester.pump();

      final saveButton = find.byKey(
        const Key('social-interaction-save-button'),
      );

      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      await tester.tap(saveButton);

      await tester.pumpAndSettle();

      expect(repository.savedRecords, hasLength(1));

      final record = repository.savedRecords.single;

      expect(record.category, SocialInteractionCategory.sharedActivity);

      expect(record.context, isNull);

      expect(record.observation, isNull);
    });
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeSocialInteractionRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SocialInteractionFormView(
        repository: repository,
        recordFactory: const SocialInteractionRecordFactory(
          _FakeSocialInteractionRecordIdGenerator(),
        ),
        anonymousId: 'anonimo-test',
      ),
    ),
  );

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
