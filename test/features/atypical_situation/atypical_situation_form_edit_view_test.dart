import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';
import 'package:sendaris/features/atypical_situation/domain/repositories/atypical_situation_management_repository.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_id_generator.dart';
import 'package:sendaris/features/atypical_situation/presentation/views/atypical_situation_form_view.dart';

void main() {
  group('AtypicalSituationFormView edición', () {
    testWidgets(
      'muestra nomenclatura de edición y precarga los datos existentes',
      (tester) async {
        final repository = _FakeAtypicalSituationManagementRepository();

        await _pumpEditView(tester, repository);

        expect(find.text('Editar registro de otra situación'), findsOneWidget);

        expect(
          find.text('Actualizar registro de otra situación'),
          findsOneWidget,
        );

        expect(
          find.text(
            'Actualiza la fecha, la categoría y '
            'la descripción del registro.',
          ),
          findsOneWidget,
        );

        expect(find.text('22 sep 2026'), findsOneWidget);

        final categoryFinder = find.byKey(
          const Key('atypical-situation-category-evento_inesperado'),
        );

        await tester.scrollUntilVisible(
          categoryFinder,
          250,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.pumpAndSettle();

        final categoryChip = tester.widget<ChoiceChip>(categoryFinder);

        expect(categoryChip.selected, isTrue);

        expect(categoryChip.showCheckmark, isFalse);

        final observationFinder = find.byKey(
          const Key('atypical-situation-observation-field'),
        );

        await tester.scrollUntilVisible(
          observationFinder,
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.pumpAndSettle();

        final observationField = tester.widget<TextField>(observationFinder);

        expect(
          observationField.controller?.text,
          'Se suspendió una actividad programada.',
        );

        final saveButton = find.byKey(
          const Key('atypical-situation-save-button'),
        );

        await tester.scrollUntilVisible(
          saveButton,
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.pumpAndSettle();

        expect(find.text('Guardar cambios'), findsOneWidget);
      },
    );

    testWidgets('permite modificar categoría y descripción y regresa true', (
      tester,
    ) async {
      final repository = _FakeAtypicalSituationManagementRepository();

      await _pumpEditView(tester, repository);

      final scrollable = find.byType(Scrollable).first;

      final categoryFinder = find.byKey(
        const Key('atypical-situation-category-cambio_horario'),
      );

      await tester.scrollUntilVisible(
        categoryFinder,
        250,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      await tester.tap(categoryFinder);

      await tester.pump();

      final observationFinder = find.byKey(
        const Key('atypical-situation-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationFinder,
        300,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        observationFinder,
        'Se modificó el horario previsto.',
      );

      final saveButton = find.byKey(
        const Key('atypical-situation-save-button'),
      );

      await tester.scrollUntilVisible(saveButton, 300, scrollable: scrollable);

      await tester.pumpAndSettle();

      await tester.tap(saveButton);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 500));

      expect(repository.updatedRecords, hasLength(1));

      final updated = repository.updatedRecords.single;

      expect(updated.recordId, 'situacion-existente');

      expect(updated.category, AtypicalSituationCategory.scheduleChange);

      expect(updated.observation, 'Se modificó el horario previsto.');

      expect(find.text('Resultado edición: true'), findsOneWidget);

      expect(
        find.text(
          'Registro de otra situación '
          'actualizado correctamente.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no actualiza si la descripción obligatoria queda vacía', (
      tester,
    ) async {
      final repository = _FakeAtypicalSituationManagementRepository();

      await _pumpEditView(tester, repository);

      final scrollable = find.byType(Scrollable).first;

      final observationFinder = find.byKey(
        const Key('atypical-situation-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationFinder,
        300,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      await tester.enterText(observationFinder, '');

      final saveButton = find.byKey(
        const Key('atypical-situation-save-button'),
      );

      await tester.scrollUntilVisible(saveButton, 300, scrollable: scrollable);

      await tester.pumpAndSettle();

      await tester.tap(saveButton);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 750));

      expect(repository.updatedRecords, isEmpty);

      expect(find.text('Describe brevemente lo ocurrido.'), findsOneWidget);

      expect(find.text('Resultado edición: true'), findsNothing);
    });
  });
}

Future<void> _pumpEditView(
  WidgetTester tester,
  _FakeAtypicalSituationManagementRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(900, 1800));

  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(MaterialApp(home: _EditHost(repository: repository)));

  await tester.tap(find.byKey(const Key('open-atypical-situation-edit')));

  await tester.pumpAndSettle();
}

class _EditHost extends StatefulWidget {
  const _EditHost({required this.repository});

  final _FakeAtypicalSituationManagementRepository repository;

  @override
  State<_EditHost> createState() => _EditHostState();
}

class _EditHostState extends State<_EditHost> {
  bool? _result;

  Future<void> _openEdit() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => AtypicalSituationFormView(
          repository: widget.repository,
          recordFactory: const AtypicalSituationRecordFactory(
            _FakeRecordIdGenerator(),
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
              key: const Key('open-atypical-situation-edit'),
              onPressed: _openEdit,
              child: const Text('Abrir edición'),
            ),
            if (_result != null) Text('Resultado edición: $_result'),
          ],
        ),
      ),
    );
  }
}

AtypicalSituationRecord _record() {
  return AtypicalSituationRecord(
    recordId: 'situacion-existente',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 22),
    category: AtypicalSituationCategory.unexpectedEvent,
    observation: 'Se suspendió una actividad programada.',
    createdAt: DateTime.utc(2026, 9, 22, 12),
    updatedAt: DateTime.utc(2026, 9, 22, 12),
  );
}

class _FakeAtypicalSituationManagementRepository
    implements AtypicalSituationManagementRepository {
  final List<AtypicalSituationRecord> savedRecords = [];
  final List<AtypicalSituationRecord> updatedRecords = [];

  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<void> updateAtypicalSituation(AtypicalSituationRecord record) async {
    updatedRecords.add(record);
  }

  @override
  Future<void> deleteAtypicalSituation({
    required String anonymousId,
    required String recordId,
  }) async {}

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
    return 'situacion-widget-edit-test';
  }
}
