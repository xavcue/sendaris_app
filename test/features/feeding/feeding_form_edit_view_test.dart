import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_category.dart';
import 'package:sendaris/features/feeding/domain/models/feeding_record.dart';
import 'package:sendaris/features/feeding/domain/repositories/feeding_management_repository.dart';
import 'package:sendaris/features/feeding/domain/services/feeding_record_factory.dart';
import 'package:sendaris/features/feeding/domain/services/feeding_record_id_generator.dart';
import 'package:sendaris/features/feeding/presentation/views/feeding_form_view.dart';

void main() {
  group('FeedingFormView edición', () {
    testWidgets('precarga el registro y muestra el lenguaje de edición', (
      tester,
    ) async {
      final repository = _FakeFeedingManagementRepository();

      await _pumpView(tester, repository);

      expect(find.text('Editar registro de alimentación'), findsOneWidget);

      expect(find.text('Actualizar registro de alimentación'), findsOneWidget);

      expect(find.text('22 sep 2026'), findsOneWidget);

      final lunchChip = find.byKey(const Key('feeding-category-almuerzo'));

      await tester.scrollUntilVisible(
        lunchChip,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      expect(lunchChip, findsOneWidget);

      final lunchWidget = tester.widget<ChoiceChip>(lunchChip);

      expect(lunchWidget.selected, isTrue);

      expect(lunchWidget.showCheckmark, isFalse);

      final observationField = find.byKey(
        const Key('feeding-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationField,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      expect(observationField, findsOneWidget);

      final textField = tester.widget<TextField>(observationField);

      expect(textField.controller?.text, 'Registro ficticio.');

      final saveButton = find.byKey(const Key('feeding-save-button'));

      await tester.scrollUntilVisible(
        saveButton,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      expect(find.text('Guardar cambios'), findsOneWidget);

      expect(find.text('Guardar alimentación'), findsNothing);
    });

    testWidgets('guarda los cambios sobre el mismo registro y devuelve true', (
      tester,
    ) async {
      final repository = _FakeFeedingManagementRepository();

      await _pumpView(tester, repository);

      final breakfastChip = find.byKey(const Key('feeding-category-desayuno'));

      await tester.scrollUntilVisible(
        breakfastChip,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      expect(breakfastChip, findsOneWidget);

      await tester.tap(breakfastChip);

      await tester.pump();

      final breakfastWidget = tester.widget<ChoiceChip>(breakfastChip);

      expect(breakfastWidget.selected, isTrue);

      final observationField = find.byKey(
        const Key('feeding-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationField,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      await tester.enterText(observationField, 'Observación actualizada.');

      final saveButton = find.byKey(const Key('feeding-save-button'));

      await tester.scrollUntilVisible(
        saveButton,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      await tester.tap(saveButton);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 400));

      expect(repository.updatedRecords, hasLength(1));

      final updated = repository.updatedRecords.single;

      expect(updated.recordId, 'alimentacion-1');

      expect(updated.anonymousId, 'seguimiento-actual');

      expect(updated.createdAt, DateTime.utc(2026, 9, 22, 18));

      expect(updated.category, FeedingCategory.breakfast);

      expect(updated.observation, 'Observación actualizada.');

      expect(find.text('Destino Eventos'), findsOneWidget);

      expect(find.text('Resultado: true'), findsOneWidget);
    });

    testWidgets('permite retirar la observación opcional al editar', (
      tester,
    ) async {
      final repository = _FakeFeedingManagementRepository();

      await _pumpView(tester, repository);

      final observationField = find.byKey(
        const Key('feeding-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationField,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      expect(observationField, findsOneWidget);

      await tester.enterText(observationField, '');

      final saveButton = find.byKey(const Key('feeding-save-button'));

      await tester.scrollUntilVisible(
        saveButton,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      await tester.tap(saveButton);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 400));

      expect(repository.updatedRecords, hasLength(1));

      expect(repository.updatedRecords.single.observation, isNull);
    });
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeFeedingManagementRepository repository,
) async {
  await tester.pumpWidget(MaterialApp(home: _EditHost(repository: repository)));

  await tester.tap(find.byKey(const Key('open-feeding-edit')));

  await tester.pumpAndSettle();
}

class _EditHost extends StatefulWidget {
  const _EditHost({required this.repository});

  final _FakeFeedingManagementRepository repository;

  @override
  State<_EditHost> createState() => _EditHostState();
}

class _EditHostState extends State<_EditHost> {
  bool? _result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Destino Eventos'),
            Text('Resultado: $_result'),
            FilledButton(
              key: const Key('open-feeding-edit'),
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => FeedingFormView(
                      repository: widget.repository,
                      recordFactory: const FeedingRecordFactory(
                        _FakeFeedingRecordIdGenerator(),
                      ),
                      anonymousId: 'seguimiento-actual',
                      initialRecord: _record(),
                    ),
                  ),
                );

                if (!mounted) {
                  return;
                }

                setState(() {
                  _result = result;
                });
              },
              child: const Text('Editar'),
            ),
          ],
        ),
      ),
    );
  }
}

FeedingRecord _record() {
  return FeedingRecord(
    recordId: 'alimentacion-1',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 22),
    category: FeedingCategory.lunch,
    observation: 'Registro ficticio.',
    createdAt: DateTime.utc(2026, 9, 22, 18),
    updatedAt: DateTime.utc(2026, 9, 22, 18),
  );
}

class _FakeFeedingManagementRepository implements FeedingManagementRepository {
  final List<FeedingRecord> savedRecords = [];

  final List<FeedingRecord> updatedRecords = [];

  @override
  Future<void> saveFeeding(FeedingRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<void> updateFeeding(FeedingRecord record) async {
    updatedRecords.add(record);
  }

  @override
  Future<List<FeedingRecord>> recoverFeedingRecords({
    required String anonymousId,
  }) async {
    return [];
  }

  @override
  Future<void> deleteFeeding({
    required String anonymousId,
    required String recordId,
  }) async {}
}

class _FakeFeedingRecordIdGenerator implements FeedingRecordIdGenerator {
  const _FakeFeedingRecordIdGenerator();

  @override
  String generate() {
    return 'id-no-utilizado-en-edicion';
  }
}
