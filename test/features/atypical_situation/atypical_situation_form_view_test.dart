import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_category.dart';
import 'package:sendaris/features/atypical_situation/domain/models/atypical_situation_record.dart';
import 'package:sendaris/features/atypical_situation/domain/repositories/atypical_situation_repository.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_factory.dart';
import 'package:sendaris/features/atypical_situation/domain/services/atypical_situation_record_id_generator.dart';
import 'package:sendaris/features/atypical_situation/presentation/views/atypical_situation_form_view.dart';

void main() {
  testWidgets('muestra un formulario con lenguaje claro para el usuario', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());

    expect(find.text('Registrar situación'), findsOneWidget);

    expect(find.text('¿Qué ocurrió? *'), findsOneWidget);

    expect(
      find.text('La información se guardará en el perfil seleccionado.'),
      findsOneWidget,
    );

    expect(find.textContaining('identificador anónimo'), findsNothing);

    expect(find.textContaining('seguimiento anónimo'), findsNothing);

    expect(find.textContaining('UID'), findsNothing);

    final descriptionTitle = find.text('Descripción *');

    await tester.scrollUntilVisible(
      descriptionTitle,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(descriptionTitle, findsOneWidget);

    final saveButton = find.byKey(const Key('atypical-situation-save-button'));

    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Guardar situación'), findsOneWidget);
  });

  testWidgets('muestra las siete categorías funcionales', (tester) async {
    await tester.pumpWidget(_buildTestApp());

    for (final category in AtypicalSituationCategory.values) {
      expect(find.text(category.label), findsOneWidget);
    }
  });

  testWidgets('muestra errores si intenta guardar sin datos obligatorios', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());

    final saveButton = find.byKey(const Key('atypical-situation-save-button'));

    await tester.scrollUntilVisible(
      saveButton,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(saveButton);

    await tester.pumpAndSettle();

    final categoryError = find.text('Selecciona una categoría para continuar.');

    expect(categoryError, findsOneWidget);

    final observationError = find.text('Describe brevemente lo ocurrido.');

    await tester.scrollUntilVisible(
      observationError,
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(observationError, findsOneWidget);
  });
}

Widget _buildTestApp() {
  final repository = _FakeAtypicalSituationRepository();

  const factory = AtypicalSituationRecordFactory(_FakeRecordIdGenerator());

  return MaterialApp(
    home: AtypicalSituationFormView(
      repository: repository,
      recordFactory: factory,
      anonymousId: 'anonimo-test',
    ),
  );
}

class _FakeAtypicalSituationRepository implements AtypicalSituationRepository {
  @override
  Future<void> saveAtypicalSituation(AtypicalSituationRecord record) async {}

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
    return 'situacion-widget-test';
  }
}
