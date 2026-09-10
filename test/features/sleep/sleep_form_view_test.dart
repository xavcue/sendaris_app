import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/sleep/domain/models/sleep_record.dart';
import 'package:sendaris/features/sleep/domain/repositories/sleep_repository.dart';
import 'package:sendaris/features/sleep/domain/services/sleep_record_factory.dart';
import 'package:sendaris/features/sleep/domain/services/sleep_record_id_generator.dart';
import 'package:sendaris/features/sleep/presentation/views/sleep_form_view.dart';

void main() {
  group('SleepFormView', () {
    late _FakeSleepRepository repository;

    setUp(() {
      repository = _FakeSleepRepository();
    });

    testWidgets('muestra la información descriptiva de registro de sueño', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      expect(find.text('Registrar sueño'), findsOneWidget);

      expect(find.text('Periodo de sueño'), findsOneWidget);

      expect(find.text('Cuándo ocurrió'), findsOneWidget);

      expect(find.text('Horario'), findsOneWidget);

      expect(find.text('Duración calculada'), findsOneWidget);

      expect(find.textContaining('valoraciones clínicas'), findsOneWidget);

      expect(find.textContaining('calidad del sueño'), findsNothing);

      expect(find.textContaining('recomendación'), findsNothing);

      final observationField = find.byKey(const Key('sleep-observation-field'));

      await tester.scrollUntilVisible(
        observationField,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      expect(observationField, findsOneWidget);

      expect(find.text('Observación'), findsOneWidget);

      final saveButton = find.byKey(const Key('sleep-save-button'));

      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      expect(saveButton, findsOneWidget);

      expect(find.text('Guardar sueño'), findsOneWidget);
    });

    testWidgets('muestra duración pendiente antes de seleccionar el horario', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      final durationSummary = find.byKey(const Key('sleep-duration-summary'));

      expect(durationSummary, findsOneWidget);

      expect(
        find.descendant(of: durationSummary, matching: find.text('Pendiente')),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: durationSummary,
          matching: find.textContaining('Selecciona ambas horas'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('valida las horas obligatorias al intentar guardar', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      final saveButton = find.byKey(const Key('sleep-save-button'));

      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      await tester.tap(saveButton);

      await tester.pump();

      expect(find.text('Selecciona la hora de inicio.'), findsOneWidget);

      expect(find.text('Selecciona la hora de finalización.'), findsOneWidget);

      expect(repository.savedRecords, isEmpty);
    });

    testWidgets('la observación se presenta como información opcional', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      final observation = find.byKey(const Key('sleep-observation-field'));

      await tester.scrollUntilVisible(
        observation,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      expect(observation, findsOneWidget);

      expect(
        find.text('Añade información descriptiva solo si es necesaria.'),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeSleepRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: SleepFormView(
        repository: repository,
        recordFactory: const SleepRecordFactory(_FakeSleepRecordIdGenerator()),
        anonymousId: 'anonimo-test',
      ),
    ),
  );

  await tester.pumpAndSettle();
}

class _FakeSleepRepository implements SleepRepository {
  final List<SleepRecord> savedRecords = [];

  @override
  Future<void> saveSleep(SleepRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<List<SleepRecord>> recoverSleepRecords({
    required String anonymousId,
  }) async {
    return [];
  }
}

class _FakeSleepRecordIdGenerator implements SleepRecordIdGenerator {
  const _FakeSleepRecordIdGenerator();

  @override
  String generate() {
    return 'registro-sueno-widget';
  }
}
