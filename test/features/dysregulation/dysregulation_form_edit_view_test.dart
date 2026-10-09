import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_intensity.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';
import 'package:sendaris/features/dysregulation/domain/repositories/dysregulation_management_repository.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_factory.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_id_generator.dart';
import 'package:sendaris/features/dysregulation/presentation/views/dysregulation_form_view.dart';

void main() {
  group('DysregulationFormView edición', () {
    testWidgets('muestra títulos de edición y todos los datos precargados', (
      tester,
    ) async {
      final repository = _FakeDysregulationManagementRepository();

      await _pumpEditView(tester, repository);

      expect(find.text('Editar registro de desregulación'), findsOneWidget);

      expect(find.text('Actualizar registro de desregulación'), findsOneWidget);

      expect(find.text('15 sep 2026'), findsOneWidget);

      expect(find.text('14:30'), findsOneWidget);

      final scrollable = find.byType(Scrollable).first;

      final durationFinder = find.byKey(
        const Key('dysregulation-duration-field'),
      );

      await tester.scrollUntilVisible(
        durationFinder,
        300,
        scrollable: scrollable,
      );

      await tester.pump();

      final durationField = tester.widget<TextField>(durationFinder);

      expect(durationField.controller?.text, '12');

      final mediumChipFinder = find.byKey(
        const Key('dysregulation-intensity-media'),
      );

      await tester.scrollUntilVisible(
        mediumChipFinder,
        300,
        scrollable: scrollable,
      );

      await tester.pump();

      final mediumChip = tester.widget<FilterChip>(mediumChipFinder);

      expect(mediumChip.selected, isTrue);

      expect(mediumChip.showCheckmark, isFalse);

      final contextFinder = find.byKey(
        const Key('dysregulation-context-field'),
      );

      await tester.scrollUntilVisible(
        contextFinder,
        300,
        scrollable: scrollable,
      );

      await tester.pump();

      final contextField = tester.widget<TextField>(contextFinder);

      expect(contextField.controller?.text, 'Actividad cotidiana');

      final observationFinder = find.byKey(
        const Key('dysregulation-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationFinder,
        300,
        scrollable: scrollable,
      );

      await tester.pump();

      final observationField = tester.widget<TextField>(observationFinder);

      expect(observationField.controller?.text, 'Registro inicial.');

      final saveButton = find.byKey(const Key('dysregulation-save-button'));

      await tester.scrollUntilVisible(saveButton, 300, scrollable: scrollable);

      await tester.pump();

      expect(find.text('Guardar cambios'), findsOneWidget);
    });

    testWidgets(
      'actualiza duración intensidad contexto y observación y regresa true',
      (tester) async {
        final repository = _FakeDysregulationManagementRepository();

        await _pumpEditView(tester, repository);

        final scrollable = find.byType(Scrollable).first;

        final durationField = find.byKey(
          const Key('dysregulation-duration-field'),
        );

        await tester.scrollUntilVisible(
          durationField,
          300,
          scrollable: scrollable,
        );

        await tester.enterText(durationField, '25');

        final highChip = find.byKey(const Key('dysregulation-intensity-alta'));

        await tester.scrollUntilVisible(highChip, 300, scrollable: scrollable);

        await tester.tap(highChip);

        await tester.pump();

        final contextField = find.byKey(
          const Key('dysregulation-context-field'),
        );

        await tester.scrollUntilVisible(
          contextField,
          300,
          scrollable: scrollable,
        );

        await tester.enterText(contextField, 'Cambio de actividad');

        final observationField = find.byKey(
          const Key('dysregulation-observation-field'),
        );

        await tester.scrollUntilVisible(
          observationField,
          300,
          scrollable: scrollable,
        );

        await tester.enterText(observationField, 'Registro actualizado.');

        final saveButton = find.byKey(const Key('dysregulation-save-button'));

        await tester.scrollUntilVisible(
          saveButton,
          300,
          scrollable: scrollable,
        );

        await tester.tap(saveButton);

        await tester.pump();

        await tester.pump(const Duration(milliseconds: 500));

        expect(repository.updatedRecords, hasLength(1));

        final updated = repository.updatedRecords.single;

        expect(updated.recordId, 'desregulacion-1');

        expect(updated.time, '14:30');

        expect(updated.durationMinutes, 25);

        expect(updated.intensity, DysregulationIntensity.high);

        expect(updated.context, 'Cambio de actividad');

        expect(updated.observation, 'Registro actualizado.');

        expect(find.text('Destino Eventos'), findsOneWidget);

        expect(find.text('Resultado: true'), findsOneWidget);

        expect(
          find.text('Registro de desregulación actualizado correctamente.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('permite retirar todos los datos opcionales', (tester) async {
      final repository = _FakeDysregulationManagementRepository();

      await _pumpEditView(tester, repository);

      final scrollable = find.byType(Scrollable).first;

      final clearTime = find.byKey(
        const Key('dysregulation-clear-time-button'),
      );

      await tester.scrollUntilVisible(clearTime, 250, scrollable: scrollable);

      await tester.tap(clearTime);

      await tester.pump();

      final durationField = find.byKey(
        const Key('dysregulation-duration-field'),
      );

      await tester.scrollUntilVisible(
        durationField,
        300,
        scrollable: scrollable,
      );

      await tester.enterText(durationField, '');

      final mediumChip = find.byKey(const Key('dysregulation-intensity-media'));

      await tester.scrollUntilVisible(mediumChip, 300, scrollable: scrollable);

      await tester.tap(mediumChip);

      await tester.pump();

      final contextField = find.byKey(const Key('dysregulation-context-field'));

      await tester.scrollUntilVisible(
        contextField,
        300,
        scrollable: scrollable,
      );

      await tester.enterText(contextField, '');

      final observationField = find.byKey(
        const Key('dysregulation-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationField,
        300,
        scrollable: scrollable,
      );

      await tester.enterText(observationField, '');

      final saveButton = find.byKey(const Key('dysregulation-save-button'));

      await tester.scrollUntilVisible(saveButton, 300, scrollable: scrollable);

      await tester.tap(saveButton);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 500));

      final updated = repository.updatedRecords.single;

      expect(updated.time, isNull);

      expect(updated.durationMinutes, isNull);

      expect(updated.intensity, isNull);

      expect(updated.context, isNull);

      expect(updated.observation, isNull);
    });
  });
}

Future<void> _pumpEditView(
  WidgetTester tester,
  _FakeDysregulationManagementRepository repository,
) async {
  await tester.pumpWidget(MaterialApp(home: _EditHost(repository: repository)));

  await tester.tap(find.byKey(const Key('open-dysregulation-edit')));

  await tester.pumpAndSettle();
}

class _EditHost extends StatefulWidget {
  const _EditHost({required this.repository});

  final _FakeDysregulationManagementRepository repository;

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
              key: const Key('open-dysregulation-edit'),
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => DysregulationFormView(
                      repository: widget.repository,
                      recordFactory: const DysregulationRecordFactory(
                        _FakeDysregulationRecordIdGenerator(),
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
              child: const Text('Abrir edición'),
            ),
          ],
        ),
      ),
    );
  }
}

DysregulationRecord _record() {
  return DysregulationRecord(
    recordId: 'desregulacion-1',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 15),
    time: '14:30',
    durationMinutes: 12,
    intensity: DysregulationIntensity.medium,
    context: 'Actividad cotidiana',
    observation: 'Registro inicial.',
    createdAt: DateTime.utc(2026, 9, 15, 20),
    updatedAt: DateTime.utc(2026, 9, 15, 20),
  );
}

class _FakeDysregulationManagementRepository
    implements DysregulationManagementRepository {
  final List<DysregulationRecord> savedRecords = [];

  final List<DysregulationRecord> updatedRecords = [];

  @override
  Future<void> saveDysregulation(DysregulationRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<List<DysregulationRecord>> recoverDysregulations({
    required String anonymousId,
  }) async {
    return const [];
  }

  @override
  Future<void> updateDysregulation(DysregulationRecord record) async {
    updatedRecords.add(record);
  }

  @override
  Future<void> deleteDysregulation({
    required String anonymousId,
    required String recordId,
  }) async {}
}

class _FakeDysregulationRecordIdGenerator
    implements DysregulationRecordIdGenerator {
  const _FakeDysregulationRecordIdGenerator();

  @override
  String generate() {
    return 'nuevo-registro';
  }
}
