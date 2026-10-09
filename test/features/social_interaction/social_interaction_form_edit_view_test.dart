import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_record.dart';
import 'package:sendaris/features/social_interaction/domain/repositories/social_interaction_management_repository.dart';
import 'package:sendaris/features/social_interaction/domain/services/social_interaction_record_factory.dart';
import 'package:sendaris/features/social_interaction/domain/services/social_interaction_record_id_generator.dart';
import 'package:sendaris/features/social_interaction/presentation/views/social_interaction_form_view.dart';

void main() {
  group('SocialInteractionFormView edición', () {
    testWidgets('precarga el registro y muestra el lenguaje de edición', (
      tester,
    ) async {
      final repository = _FakeSocialInteractionManagementRepository();

      await _pumpView(tester, repository);

      expect(
        find.text('Editar registro de interacción social'),
        findsOneWidget,
      );

      expect(
        find.text('Actualizar registro de interacción social'),
        findsOneWidget,
      );

      expect(find.text('22 sep 2026'), findsOneWidget);

      final categoryChip = find.byKey(
        const Key('social-interaction-category-intercambio_social'),
      );

      await tester.scrollUntilVisible(
        categoryChip,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      final categoryWidget = tester.widget<ChoiceChip>(categoryChip);

      expect(categoryWidget.selected, isTrue);

      expect(categoryWidget.showCheckmark, isFalse);

      final contextField = find.byKey(
        const Key('social-interaction-context-field'),
      );

      await tester.scrollUntilVisible(
        contextField,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      final contextTextField = tester.widget<TextField>(contextField);

      expect(contextTextField.controller?.text, 'Actividad recreativa');

      final observationField = find.byKey(
        const Key('social-interaction-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationField,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      final observationTextField = tester.widget<TextField>(observationField);

      expect(observationTextField.controller?.text, 'Registro ficticio.');

      final saveButton = find.byKey(
        const Key('social-interaction-save-button'),
      );

      await tester.scrollUntilVisible(
        saveButton,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      expect(find.text('Guardar cambios'), findsOneWidget);

      expect(find.text('Guardar interacción social'), findsNothing);
    });

    testWidgets('guarda los cambios sobre el mismo registro y devuelve true', (
      tester,
    ) async {
      final repository = _FakeSocialInteractionManagementRepository();

      await _pumpView(tester, repository);

      final sharedActivityChip = find.byKey(
        const Key('social-interaction-category-actividad_compartida'),
      );

      await tester.scrollUntilVisible(
        sharedActivityChip,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.pumpAndSettle();

      await tester.tap(sharedActivityChip);

      await tester.pump();

      final contextField = find.byKey(
        const Key('social-interaction-context-field'),
      );

      await tester.scrollUntilVisible(
        contextField,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.enterText(contextField, 'Actividad grupal.');

      final observationField = find.byKey(
        const Key('social-interaction-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationField,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.enterText(observationField, 'Observación actualizada.');

      final saveButton = find.byKey(
        const Key('social-interaction-save-button'),
      );

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

      expect(updated.recordId, 'interaccion-1');

      expect(updated.anonymousId, 'seguimiento-actual');

      expect(updated.createdAt, DateTime.utc(2026, 9, 22, 18));

      expect(updated.category, SocialInteractionCategory.sharedActivity);

      expect(updated.context, 'Actividad grupal.');

      expect(updated.observation, 'Observación actualizada.');

      expect(find.text('Destino Eventos'), findsOneWidget);

      expect(find.text('Resultado: true'), findsOneWidget);
    });

    testWidgets('permite retirar contexto y observación opcionales al editar', (
      tester,
    ) async {
      final repository = _FakeSocialInteractionManagementRepository();

      await _pumpView(tester, repository);

      final contextField = find.byKey(
        const Key('social-interaction-context-field'),
      );

      await tester.scrollUntilVisible(
        contextField,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.enterText(contextField, '');

      final observationField = find.byKey(
        const Key('social-interaction-observation-field'),
      );

      await tester.scrollUntilVisible(
        observationField,
        250,
        scrollable: find.byType(Scrollable).first,
      );

      await tester.enterText(observationField, '');

      final saveButton = find.byKey(
        const Key('social-interaction-save-button'),
      );

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

      expect(repository.updatedRecords.single.context, isNull);

      expect(repository.updatedRecords.single.observation, isNull);
    });
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeSocialInteractionManagementRepository repository,
) async {
  await tester.pumpWidget(MaterialApp(home: _EditHost(repository: repository)));

  await tester.tap(find.byKey(const Key('open-social-interaction-edit')));

  await tester.pumpAndSettle();
}

class _EditHost extends StatefulWidget {
  const _EditHost({required this.repository});

  final _FakeSocialInteractionManagementRepository repository;

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
              key: const Key('open-social-interaction-edit'),
              onPressed: () async {
                final result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute<bool>(
                    builder: (_) => SocialInteractionFormView(
                      repository: widget.repository,
                      recordFactory: const SocialInteractionRecordFactory(
                        _FakeSocialInteractionRecordIdGenerator(),
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

SocialInteractionRecord _record() {
  return SocialInteractionRecord(
    recordId: 'interaccion-1',
    anonymousId: 'seguimiento-actual',
    date: DateTime(2026, 9, 22),
    category: SocialInteractionCategory.socialExchange,
    context: 'Actividad recreativa',
    observation: 'Registro ficticio.',
    createdAt: DateTime.utc(2026, 9, 22, 18),
    updatedAt: DateTime.utc(2026, 9, 22, 18),
  );
}

class _FakeSocialInteractionManagementRepository
    implements SocialInteractionManagementRepository {
  final List<SocialInteractionRecord> savedRecords = [];

  final List<SocialInteractionRecord> updatedRecords = [];

  @override
  Future<void> saveSocialInteraction(SocialInteractionRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<List<SocialInteractionRecord>> recoverSocialInteractions({
    required String anonymousId,
  }) async {
    return [];
  }

  @override
  Future<void> updateSocialInteraction(SocialInteractionRecord record) async {
    updatedRecords.add(record);
  }

  @override
  Future<void> deleteSocialInteraction({
    required String anonymousId,
    required String recordId,
  }) async {}
}

class _FakeSocialInteractionRecordIdGenerator
    implements SocialInteractionRecordIdGenerator {
  const _FakeSocialInteractionRecordIdGenerator();

  @override
  String generate() {
    return 'id-no-utilizado-en-edicion';
  }
}
