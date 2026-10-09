import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_intensity.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/repositories/behavior_management_repository.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_factory.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_id_generator.dart';
import 'package:sendaris/features/behavior/presentation/views/behavior_form_view.dart';

void main() {
  testWidgets(
    'modo edición precarga todos los datos y usa textos de actualización',
    (tester) async {
      final repository = _FakeBehaviorManagementRepository();

      final record = _record();

      await tester.pumpWidget(
        MaterialApp(
          home: BehaviorFormView(
            repository: repository,
            recordFactory: const BehaviorRecordFactory(
              _FakeBehaviorRecordIdGenerator(),
            ),
            anonymousId: 'seguimiento-actual',
            initialRecord: record,
          ),
        ),
      );

      await tester.pumpAndSettle();

      final scrollable = find.byType(Scrollable).first;

      expect(find.text('Editar registro de conducta'), findsOneWidget);

      expect(find.byKey(const Key('behavior-edit-view')), findsOneWidget);

      expect(find.text('Actualizar registro de conducta'), findsOneWidget);

      expect(find.text('20 sep 2026'), findsOneWidget);

      expect(find.text('08:30'), findsOneWidget);

      final categoryFinder = find.byKey(
        const Key('behavior-category-evitacion_miedo'),
      );

      await tester.scrollUntilVisible(
        categoryFinder,
        250,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      expect(categoryFinder, findsOneWidget);

      final category = tester.widget<ChoiceChip>(categoryFinder);

      expect(category.selected, isTrue);

      expect(category.showCheckmark, isFalse);

      final intensityFinder = find.byKey(const Key('behavior-intensity-baja'));

      await tester.scrollUntilVisible(
        intensityFinder,
        250,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      expect(intensityFinder, findsOneWidget);

      final intensity = tester.widget<FilterChip>(intensityFinder);

      expect(intensity.selected, isTrue);

      expect(intensity.showCheckmark, isFalse);

      final durationFinder = find.byKey(const Key('behavior-duration-field'));

      await tester.scrollUntilVisible(
        durationFinder,
        200,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      final duration = tester.widget<TextField>(durationFinder);

      expect(duration.controller?.text, '15');

      final optionalDetailsFinder = find.byKey(
        const Key('behavior-optional-details'),
      );

      await tester.scrollUntilVisible(
        optionalDetailsFinder,
        300,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      await tester.tap(optionalDetailsFinder);

      await tester.pumpAndSettle();

      final contextFinder = find.byKey(const Key('behavior-context-field'));

      await tester.scrollUntilVisible(
        contextFinder,
        250,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      final contextField = tester.widget<TextField>(contextFinder);

      expect(contextField.controller?.text, 'Antes de una transición');

      final observationFinder = find.byKey(
        const Key('behavior-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationFinder,
        250,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      final observationField = tester.widget<TextField>(observationFinder);

      expect(observationField.controller?.text, 'Registro inicial.');

      final saveButton = find.byKey(const Key('behavior-save-button'));

      await tester.scrollUntilVisible(saveButton, 300, scrollable: scrollable);

      await tester.pumpAndSettle();

      expect(find.text('Guardar cambios'), findsOneWidget);

      expect(find.text('Guardar conducta'), findsNothing);
    },
  );

  testWidgets('guardar en edición actualiza el registro y devuelve true', (
    tester,
  ) async {
    final repository = _FakeBehaviorManagementRepository();

    await tester.pumpWidget(
      MaterialApp(home: _EditHost(repository: repository)),
    );

    await tester.tap(find.byKey(const Key('open-behavior-edit')));

    await tester.pumpAndSettle();

    final scrollable = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(
      find.byKey(const Key('behavior-save-button')),
      350,
      scrollable: scrollable,
    );

    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('behavior-save-button')));

    await tester.pumpAndSettle();

    expect(repository.savedRecords, isEmpty);

    expect(repository.updatedRecords.length, 1);

    final updated = repository.updatedRecords.single;

    expect(updated.recordId, 'conducta-existente');

    expect(updated.anonymousId, 'seguimiento-actual');

    expect(updated.createdAt, DateTime.utc(2026, 9, 20, 13, 30));

    expect(find.text('resultado:true'), findsOneWidget);
  });
}

class _EditHost extends StatefulWidget {
  const _EditHost({required this.repository});

  final _FakeBehaviorManagementRepository repository;

  @override
  State<_EditHost> createState() => _EditHostState();
}

class _EditHostState extends State<_EditHost> {
  bool? _result;

  Future<void> _openEdit() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BehaviorFormView(
          repository: widget.repository,
          recordFactory: const BehaviorRecordFactory(
            _FakeBehaviorRecordIdGenerator(),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              key: const Key('open-behavior-edit'),
              onPressed: _openEdit,
              child: const Text('Abrir edición'),
            ),
            Text('resultado:${_result ?? 'pendiente'}'),
          ],
        ),
      ),
    );
  }
}

BehaviorRecord _record() {
  return BehaviorRecord(
    recordId: 'conducta-existente',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 20),
    time: '08:30',
    category: BehaviorCategory.avoidanceFear,
    durationMinutes: 15,
    intensity: BehaviorIntensity.low,
    context: 'Antes de una transición',
    observation: 'Registro inicial.',
    createdAt: DateTime.utc(2026, 9, 20, 13, 30),
    updatedAt: DateTime.utc(2026, 9, 20, 13, 30),
  );
}

class _FakeBehaviorManagementRepository
    implements BehaviorManagementRepository {
  final List<BehaviorRecord> savedRecords = [];

  final List<BehaviorRecord> updatedRecords = [];

  @override
  Future<void> saveBehavior(BehaviorRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    return const [];
  }

  @override
  Future<void> updateBehavior(BehaviorRecord record) async {
    updatedRecords.add(record);
  }

  @override
  Future<void> deleteBehavior({
    required String anonymousId,
    required String recordId,
  }) async {}
}

class _FakeBehaviorRecordIdGenerator implements BehaviorRecordIdGenerator {
  const _FakeBehaviorRecordIdGenerator();

  @override
  String generate() {
    return 'registro-nuevo';
  }
}
