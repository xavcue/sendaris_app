import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';
import 'package:sendaris/features/sleep/domain/repositories/sleep_management_repository.dart';
import 'package:sendaris/features/sleep/domain/services/sleep_record_factory.dart';
import 'package:sendaris/features/sleep/domain/services/sleep_record_id_generator.dart';
import 'package:sendaris/features/sleep/presentation/views/sleep_form_view.dart';

void main() {
  group('SleepFormView edición', () {
    testWidgets('precarga todos los datos editables del sueño', (tester) async {
      final repository = _FakeSleepManagementRepository();

      await _pumpEditView(tester, repository);

      expect(find.byKey(const Key('sleep-edit-view')), findsOneWidget);

      expect(find.text('Editar registro de sueño'), findsOneWidget);

      expect(find.text('Actualizar registro de sueño'), findsOneWidget);

      expect(find.text('20 sep 2026'), findsOneWidget);

      expect(find.text('22:00'), findsOneWidget);

      expect(find.text('06:00'), findsOneWidget);

      expect(find.text('8 h'), findsOneWidget);

      final observationFinder = find.byKey(
        const Key('sleep-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      final observationField = tester.widget<TextField>(observationFinder);

      expect(observationField.controller?.text, 'Observación inicial.');

      final saveButton = find.byKey(const Key('sleep-save-button'));

      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      expect(find.text('Guardar cambios'), findsOneWidget);

      expect(find.text('Guardar sueño'), findsNothing);
    });

    testWidgets('guardar en edición actualiza el registro y devuelve true', (
      tester,
    ) async {
      final repository = _FakeSleepManagementRepository();

      await _pumpEditView(tester, repository);

      final observationFinder = find.byKey(
        const Key('sleep-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationFinder,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      await tester.enterText(observationFinder, 'Observación actualizada.');

      final saveButton = find.byKey(const Key('sleep-save-button'));

      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      await tester.tap(saveButton);

      await tester.pumpAndSettle();

      expect(repository.savedRecords, isEmpty);

      expect(repository.updatedRecords, hasLength(1));

      final updated = repository.updatedRecords.single;

      expect(updated.recordId, 'sueno-existente');

      expect(updated.anonymousId, 'seguimiento-1');

      expect(updated.createdAt, DateTime.utc(2026, 9, 21, 8));

      expect(updated.startTime, '22:00');

      expect(updated.endTime, '06:00');

      expect(updated.durationMinutes, 480);

      expect(updated.observation, 'Observación actualizada.');

      expect(find.text('resultado:true'), findsOneWidget);
    });
  });
}

Future<void> _pumpEditView(
  WidgetTester tester,
  _FakeSleepManagementRepository repository,
) async {
  final record = SleepRecord(
    recordId: 'sueno-existente',
    anonymousId: 'seguimiento-1',
    date: DateTime(2026, 9, 20),
    startTime: '22:00',
    endTime: '06:00',
    durationMinutes: 480,
    observation: 'Observación inicial.',
    createdAt: DateTime.utc(2026, 9, 21, 8),
    updatedAt: DateTime.utc(2026, 9, 21, 8),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: _EditLauncher(repository: repository, record: record),
    ),
  );

  await tester.tap(find.byKey(const Key('open-sleep-edit')));

  await tester.pumpAndSettle();
}

class _EditLauncher extends StatefulWidget {
  const _EditLauncher({required this.repository, required this.record});

  final _FakeSleepManagementRepository repository;

  final SleepRecord record;

  @override
  State<_EditLauncher> createState() => _EditLauncherState();
}

class _EditLauncherState extends State<_EditLauncher> {
  bool? _result;

  Future<void> _openEdit() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => SleepFormView(
          repository: widget.repository,
          recordFactory: const SleepRecordFactory(
            _FakeSleepRecordIdGenerator(),
          ),
          anonymousId: 'seguimiento-1',
          initialRecord: widget.record,
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
              key: const Key('open-sleep-edit'),
              onPressed: _openEdit,
              child: const Text('Abrir edición'),
            ),
            if (_result != null) Text('resultado:$_result'),
          ],
        ),
      ),
    );
  }
}

class _FakeSleepManagementRepository implements SleepManagementRepository {
  final List<SleepRecord> savedRecords = [];

  final List<SleepRecord> updatedRecords = [];

  @override
  Future<void> saveSleep(SleepRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<List<SleepRecord>> recoverSleepRecords({
    required String anonymousId,
  }) async {
    return const [];
  }

  @override
  Future<void> updateSleep(SleepRecord record) async {
    updatedRecords.add(record);
  }

  @override
  Future<void> deleteSleep({
    required String anonymousId,
    required String recordId,
  }) async {}
}

class _FakeSleepRecordIdGenerator implements SleepRecordIdGenerator {
  const _FakeSleepRecordIdGenerator();

  @override
  String generate() {
    return 'id-no-utilizado-en-edicion';
  }
}
