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

    testWidgets('muestra información descriptiva y fecha sin seleccionar', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      expect(find.text('Registrar desregulación'), findsOneWidget);

      expect(find.text('Registro de desregulación'), findsOneWidget);

      expect(find.text('Sin seleccionar'), findsOneWidget);

      expect(find.text('Hora (opcional)'), findsOneWidget);

      expect(find.text('Sin hora'), findsOneWidget);

      expect(find.text('Obligatorio'), findsOneWidget);

      expect(find.textContaining('no determina causas'), findsOneWidget);

      expect(find.textContaining('diagnósticos'), findsOneWidget);

      expect(find.textContaining('recomendaciones'), findsOneWidget);

      expect(find.textContaining('severidad'), findsNothing);

      expect(find.textContaining('tratamiento'), findsNothing);
    });

    testWidgets(
      'muestra las tres intensidades sin checks y permite deseleccionarlas',
      (tester) async {
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

        await tester.pump();

        expect(find.text('Baja'), findsOneWidget);

        expect(find.text('Media'), findsOneWidget);

        expect(find.text('Alta'), findsOneWidget);

        expect(find.text('Severa'), findsNothing);

        var chip = tester.widget<FilterChip>(intensityChip);

        expect(chip.selected, isFalse);

        expect(chip.showCheckmark, isFalse);

        await tester.tap(intensityChip);

        await tester.pump();

        chip = tester.widget<FilterChip>(intensityChip);

        expect(chip.selected, isTrue);

        expect(chip.showCheckmark, isFalse);

        await tester.tap(intensityChip);

        await tester.pump();

        chip = tester.widget<FilterChip>(intensityChip);

        expect(chip.selected, isFalse);
      },
    );

    testWidgets('muestra error de fecha y lo oculta después de unos segundos', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      final saveButton = find.byKey(const Key('dysregulation-save-button'));

      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pump();

      await tester.tap(saveButton);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text('Selecciona una fecha.'), findsOneWidget);

      expect(repository.savedRecords, isEmpty);

      await tester.pump(const Duration(seconds: 5));

      await tester.pump();

      expect(find.text('Selecciona una fecha.'), findsNothing);
    });

    testWidgets('muestra duración contexto y observación como opcionales', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      final scrollable = find.byType(Scrollable).first;

      final duration = find.byKey(const Key('dysregulation-duration-field'));

      await tester.scrollUntilVisible(duration, 300, scrollable: scrollable);

      await tester.pump();

      expect(find.text('Duración (opcional)'), findsOneWidget);

      expect(find.text('Intensidad descriptiva (opcional)'), findsOneWidget);

      final context = find.byKey(const Key('dysregulation-context-field'));

      await tester.scrollUntilVisible(context, 300, scrollable: scrollable);

      await tester.pump();

      expect(find.text('Contexto general (opcional)'), findsOneWidget);

      final observation = find.byKey(
        const Key('dysregulation-observation-field'),
      );

      await tester.scrollUntilVisible(observation, 300, scrollable: scrollable);

      await tester.pump();

      expect(find.text('Observación (opcional)'), findsOneWidget);
    });

    testWidgets('muestra temporalmente el error de duración inválida', (
      tester,
    ) async {
      await _pumpView(tester, repository);

      await _selectDate(tester);

      final scrollable = find.byType(Scrollable).first;

      final durationField = find.byKey(
        const Key('dysregulation-duration-field'),
      );

      await tester.scrollUntilVisible(
        durationField,
        300,
        scrollable: scrollable,
      );

      await tester.pump();

      await tester.enterText(durationField, 'doce');

      FocusManager.instance.primaryFocus?.unfocus();

      await tester.pump();

      final saveButton = find.byKey(const Key('dysregulation-save-button'));

      await tester.scrollUntilVisible(saveButton, 300, scrollable: scrollable);

      await tester.pump();

      await tester.tap(saveButton);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 450));

      expect(find.textContaining('números enteros'), findsOneWidget);

      expect(repository.savedRecords, isEmpty);

      await tester.pump(const Duration(seconds: 5));

      await tester.pump();

      expect(find.textContaining('números enteros'), findsNothing);
    });

    testWidgets('guarda correctamente y regresa a Registrar', (tester) async {
      await _pumpView(tester, repository);

      await _selectDate(tester);

      final scrollable = find.byType(Scrollable).first;

      final intensityChip = find.byKey(
        const Key('dysregulation-intensity-media'),
      );

      await tester.scrollUntilVisible(
        intensityChip,
        300,
        scrollable: scrollable,
      );

      await tester.pump();

      await tester.tap(intensityChip);

      await tester.pump();

      final selectedChip = tester.widget<FilterChip>(intensityChip);

      expect(selectedChip.selected, isTrue);

      expect(selectedChip.showCheckmark, isFalse);

      final contextField = find.byKey(const Key('dysregulation-context-field'));

      await tester.scrollUntilVisible(
        contextField,
        300,
        scrollable: scrollable,
      );

      await tester.pump();

      await tester.enterText(contextField, 'Durante una actividad cotidiana.');

      final observationField = find.byKey(
        const Key('dysregulation-observation-field'),
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

      final saveButton = find.byKey(const Key('dysregulation-save-button'));

      await tester.scrollUntilVisible(saveButton, 300, scrollable: scrollable);

      await tester.pump();

      await tester.tap(saveButton);

      await tester.pump();

      await tester.pump(const Duration(milliseconds: 500));

      expect(repository.savedRecords, hasLength(1));

      final record = repository.savedRecords.single;

      expect(record.intensity, DysregulationIntensity.medium);

      expect(record.context, 'Durante una actividad cotidiana.');

      expect(record.observation, 'Registro ficticio descriptivo.');

      expect(find.text('Destino Registrar'), findsOneWidget);

      expect(
        find.text('Episodio de desregulación guardado correctamente.'),
        findsOneWidget,
      );
    });
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeDysregulationRepository repository,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) {
          return Scaffold(
            body: Center(
              child: FilledButton(
                key: const Key('open-dysregulation-form'),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DysregulationFormView(
                        repository: repository,
                        recordFactory: const DysregulationRecordFactory(
                          _FakeDysregulationRecordIdGenerator(),
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

  await tester.tap(find.byKey(const Key('open-dysregulation-form')));

  await tester.pumpAndSettle();
}

Future<void> _selectDate(WidgetTester tester) async {
  final datePicker = find.byKey(const Key('dysregulation-date-picker'));

  await tester.scrollUntilVisible(
    datePicker,
    200,
    scrollable: find.byType(Scrollable).first,
  );

  await tester.pump();

  await tester.tap(datePicker);

  await tester.pumpAndSettle();

  await tester.tap(find.widgetWithText(TextButton, 'Seleccionar').last);

  await tester.pumpAndSettle();
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
