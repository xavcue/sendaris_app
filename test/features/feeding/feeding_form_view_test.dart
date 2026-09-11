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

    testWidgets('muestra únicamente información descriptiva de alimentación', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      expect(find.text('Registrar alimentación'), findsOneWidget);

      expect(find.text('Registro de alimentación'), findsOneWidget);

      expect(find.text('Cuándo ocurrió'), findsOneWidget);

      expect(find.text('Tipo de alimentación'), findsOneWidget);

      expect(find.textContaining('no calcula calorías'), findsOneWidget);

      expect(find.textContaining('análisis'), findsOneWidget);

      expect(find.textContaining('peso'), findsNothing);

      expect(find.textContaining('nutrientes'), findsNothing);

      expect(find.textContaining('diagnóstico'), findsNothing);
    });

    testWidgets('muestra las cinco categorías generales definidas', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      expect(find.text('Desayuno'), findsOneWidget);

      expect(find.text('Refrigerio'), findsOneWidget);

      expect(find.text('Almuerzo'), findsOneWidget);

      expect(find.text('Merienda / cena'), findsOneWidget);

      expect(find.text('Otro'), findsOneWidget);
    });

    testWidgets('valida la categoría obligatoria antes de guardar', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      final saveButton = find.byKey(const Key('feeding-save-button'));

      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      await tester.tap(saveButton);

      await tester.pump();

      expect(
        find.text('Selecciona una categoría de alimentación.'),
        findsOneWidget,
      );

      expect(repository.savedRecords, isEmpty);
    });

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

      await tester.pumpAndSettle();

      expect(observation, findsOneWidget);

      expect(find.text('Observación'), findsOneWidget);

      expect(
        find.text(
          'Añade información descriptiva complementaria solo si es necesaria.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('guarda una categoría válida con observación descriptiva', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      final lunchChip = find.byKey(const Key('feeding-category-almuerzo'));

      expect(lunchChip, findsOneWidget);

      await tester.tap(lunchChip);

      await tester.pump();

      final observation = find.byKey(const Key('feeding-observation-field'));

      await tester.scrollUntilVisible(
        observation,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      await tester.enterText(observation, 'Registro ficticio descriptivo.');

      final saveButton = find.byKey(const Key('feeding-save-button'));

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

      expect(record.category, FeedingCategory.lunch);

      expect(record.observation, 'Registro ficticio descriptivo.');

      expect(
        find.text('Registro de alimentación guardado correctamente.'),
        findsOneWidget,
      );

      expect(find.text('Registro ficticio descriptivo.'), findsNothing);
    });

    testWidgets('permite guardar alimentación sin observación', (tester) async {
      await _pumpView(tester, repository);

      final breakfastChip = find.byKey(const Key('feeding-category-desayuno'));

      await tester.tap(breakfastChip);

      await tester.pump();

      final saveButton = find.byKey(const Key('feeding-save-button'));

      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      await tester.tap(saveButton);

      await tester.pumpAndSettle();

      expect(repository.savedRecords, hasLength(1));

      expect(repository.savedRecords.single.observation, isNull);
    });
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeFeedingRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: FeedingFormView(
        repository: repository,
        recordFactory: const FeedingRecordFactory(
          _FakeFeedingRecordIdGenerator(),
        ),
        anonymousId: 'anonimo-test',
      ),
    ),
  );

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
