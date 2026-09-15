import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_intensity.dart';
import 'package:sendaris/features/dysregulation/domain/models/dysregulation_record.dart';
import 'package:sendaris/features/dysregulation/domain/repositories/dysregulation_repository.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_factory.dart';
import 'package:sendaris/features/dysregulation/domain/services/dysregulation_record_id_generator.dart';
import 'package:sendaris/features/dysregulation/presentation/views/dysregulation_form_view.dart';

void main() {
  group('DysregulationFormView', () {
    late _FakeDysregulationRepository repository;

    setUp(() {
      repository = _FakeDysregulationRepository();
    });

    testWidgets('muestra únicamente información descriptiva del episodio', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      expect(find.text('Registrar desregulación'), findsOneWidget);

      expect(find.text('Registro de desregulación'), findsOneWidget);

      expect(find.textContaining('no determina causas'), findsOneWidget);

      expect(find.textContaining('diagnósticos'), findsOneWidget);

      expect(find.textContaining('recomendaciones'), findsOneWidget);

      expect(find.textContaining('únicamente descriptiva'), findsOneWidget);

      expect(find.textContaining('severidad'), findsNothing);

      expect(find.textContaining('tratamiento'), findsNothing);

      expect(find.textContaining('puntuación'), findsNothing);
    });

    testWidgets('muestra fecha obligatoria y hora opcional', (tester) async {
      await _pumpView(tester, repository);

      expect(find.text('Cuándo ocurrió'), findsOneWidget);

      expect(find.text('Obligatorio'), findsOneWidget);

      expect(
        find.byKey(const Key('dysregulation-date-picker')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('dysregulation-time-picker')),
        findsOneWidget,
      );

      expect(find.text('Opcional'), findsOneWidget);
    });

    testWidgets(
      'muestra únicamente las tres intensidades descriptivas definidas',
      (tester) async {
        await _pumpView(tester, repository);

        final intensity = find.byKey(
          const Key('dysregulation-intensity-media'),
        );

        await tester.scrollUntilVisible(
          intensity,
          300,
          scrollable: find.byType(Scrollable).first,
        );

        await tester.pumpAndSettle();

        expect(find.text('Baja'), findsOneWidget);

        expect(find.text('Media'), findsOneWidget);

        expect(find.text('Alta'), findsOneWidget);

        expect(find.text('Severa'), findsNothing);
      },
    );

    testWidgets(
      'al rechazar duración no numérica vuelve al campo y muestra el error',
      (tester) async {
        await _pumpView(tester, repository);

        final scrollable = find.byType(Scrollable).first;

        final durationField = find.byKey(
          const Key('dysregulation-duration-field'),
        );

        await tester.scrollUntilVisible(
          durationField,
          300,
          scrollable: scrollable,
        );

        await tester.pumpAndSettle();

        await tester.enterText(durationField, 'doce');

        final saveButton = await _moveFromDurationToSave(tester);

        await tester.tap(saveButton);

        await tester.pumpAndSettle();

        expect(find.textContaining('números enteros'), findsOneWidget);

        final textField = tester.widget<TextField>(durationField);

        expect(textField.focusNode?.hasFocus, isTrue);

        expect(repository.savedRecords, isEmpty);
      },
    );

    testWidgets(
      'al rechazar duración negativa vuelve al campo y elimina el error al corregirlo',
      (tester) async {
        await _pumpView(tester, repository);

        final scrollable = find.byType(Scrollable).first;

        final durationField = find.byKey(
          const Key('dysregulation-duration-field'),
        );

        await tester.scrollUntilVisible(
          durationField,
          300,
          scrollable: scrollable,
        );

        await tester.pumpAndSettle();

        await tester.enterText(durationField, '-1');

        final saveButton = await _moveFromDurationToSave(tester);

        await tester.tap(saveButton);

        await tester.pumpAndSettle();

        expect(find.text('La duración no puede ser negativa.'), findsOneWidget);

        var textField = tester.widget<TextField>(durationField);

        expect(textField.focusNode?.hasFocus, isTrue);

        await tester.enterText(durationField, '12');

        await tester.pump();

        expect(find.text('La duración no puede ser negativa.'), findsNothing);

        textField = tester.widget<TextField>(durationField);

        expect(textField.controller?.text, '12');

        expect(repository.savedRecords, isEmpty);
      },
    );

    testWidgets('guarda duración cero como valor válido', (tester) async {
      await _pumpView(tester, repository);

      final scrollable = find.byType(Scrollable).first;

      final durationField = find.byKey(
        const Key('dysregulation-duration-field'),
      );

      await tester.scrollUntilVisible(
        durationField,
        300,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      await tester.enterText(durationField, '0');

      final saveButton = await _moveFromDurationToSave(tester);

      await tester.tap(saveButton);

      await tester.pumpAndSettle();

      expect(repository.savedRecords, hasLength(1));

      expect(repository.savedRecords.single.durationMinutes, 0);
    });

    testWidgets('guarda intensidad contexto y observación descriptivos', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      final scrollable = find.byType(Scrollable).first;

      final intensityChip = find.byKey(
        const Key('dysregulation-intensity-media'),
      );

      await tester.scrollUntilVisible(
        intensityChip,
        300,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      await tester.tap(intensityChip);

      await tester.pump();

      final contextField = find.byKey(const Key('dysregulation-context-field'));

      await tester.scrollUntilVisible(
        contextField,
        300,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      await tester.enterText(contextField, 'Durante una actividad cotidiana.');

      final observationField = find.byKey(
        const Key('dysregulation-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationField,
        300,
        scrollable: scrollable,
      );

      await tester.pumpAndSettle();

      await tester.enterText(
        observationField,
        'Registro ficticio descriptivo.',
      );

      final saveButton = find.byKey(const Key('dysregulation-save-button'));

      await tester.scrollUntilVisible(saveButton, 300, scrollable: scrollable);

      await tester.pumpAndSettle();

      await tester.tap(saveButton);

      await tester.pumpAndSettle();

      expect(repository.savedRecords, hasLength(1));

      final record = repository.savedRecords.single;

      expect(record.intensity, DysregulationIntensity.medium);

      expect(record.context, 'Durante una actividad cotidiana.');

      expect(record.observation, 'Registro ficticio descriptivo.');

      expect(
        find.text('Episodio de desregulación guardado correctamente.'),
        findsOneWidget,
      );

      expect(find.text('Durante una actividad cotidiana.'), findsNothing);

      expect(find.text('Registro ficticio descriptivo.'), findsNothing);
    });

    testWidgets('permite guardar solo con la fecha y omitir los demás datos', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      final saveButton = find.byKey(const Key('dysregulation-save-button'));

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

      expect(record.time, isNull);

      expect(record.durationMinutes, isNull);

      expect(record.intensity, isNull);

      expect(record.context, isNull);

      expect(record.observation, isNull);
    });
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeDysregulationRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: DysregulationFormView(
        repository: repository,
        recordFactory: const DysregulationRecordFactory(
          _FakeDysregulationRecordIdGenerator(),
        ),
        anonymousId: 'anonimo-test',
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<Finder> _moveFromDurationToSave(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();

  await tester.pumpAndSettle();

  final scrollable = find.byType(Scrollable).first;

  final contextField = find.byKey(const Key('dysregulation-context-field'));

  await tester.scrollUntilVisible(contextField, 250, scrollable: scrollable);

  await tester.pumpAndSettle();

  final observationField = find.byKey(
    const Key('dysregulation-observation-field'),
  );

  await tester.scrollUntilVisible(
    observationField,
    250,
    scrollable: scrollable,
  );

  await tester.pumpAndSettle();

  final saveButton = find.byKey(const Key('dysregulation-save-button'));

  await tester.scrollUntilVisible(saveButton, 250, scrollable: scrollable);

  await tester.pumpAndSettle();

  expect(saveButton, findsOneWidget);

  return saveButton;
}

class _FakeDysregulationRepository implements DysregulationRepository {
  final List<DysregulationRecord> savedRecords = [];

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
}

class _FakeDysregulationRecordIdGenerator
    implements DysregulationRecordIdGenerator {
  const _FakeDysregulationRecordIdGenerator();

  @override
  String generate() {
    return 'registro-desregulacion-widget';
  }
}
