import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/repositories/behavior_repository.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_factory.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_id_generator.dart';
import 'package:sendaris/features/behavior/presentation/views/behavior_form_view.dart';

void main() {
  testWidgets(
    'muestra la estructura principal con lenguaje orientado al usuario',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: BehaviorFormView(
            repository: _FakeBehaviorRepository(),
            recordFactory: const BehaviorRecordFactory(
              _FakeBehaviorRecordIdGenerator(),
            ),
            anonymousId: 'anonimo-1',
          ),
        ),
      );

      final scrollable = find.byType(Scrollable).first;

      expect(find.text('Registrar conducta'), findsOneWidget);

      expect(find.text('Conducta observada'), findsOneWidget);

      expect(
        find.text('La información se guardará en el perfil activo.'),
        findsOneWidget,
      );

      expect(find.textContaining('seguimiento anónimo'), findsNothing);

      expect(find.textContaining('identificador interno'), findsNothing);

      await tester.scrollUntilVisible(
        find.text('Cuándo ocurrió'),
        250,
        scrollable: scrollable,
      );

      expect(find.text('Cuándo ocurrió'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Qué observaste *'),
        250,
        scrollable: scrollable,
      );

      expect(find.text('Qué observaste *'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Detalles del registro'),
        250,
        scrollable: scrollable,
      );

      expect(find.text('Detalles del registro'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const Key('behavior-save-button')),
        250,
        scrollable: scrollable,
      );

      expect(find.text('Guardar conducta'), findsOneWidget);
    },
  );

  testWidgets('informa que la categoría es obligatoria', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BehaviorFormView(
          repository: _FakeBehaviorRepository(),
          recordFactory: const BehaviorRecordFactory(
            _FakeBehaviorRecordIdGenerator(),
          ),
          anonymousId: 'anonimo-1',
        ),
      ),
    );

    final scrollable = find.byType(Scrollable).first;

    final saveButton = find.byKey(const Key('behavior-save-button'));

    await tester.scrollUntilVisible(saveButton, 300, scrollable: scrollable);

    await tester.tap(saveButton);

    await tester.pumpAndSettle();

    const categoryError = 'Selecciona una categoría para continuar.';

    await tester.scrollUntilVisible(
      find.text(categoryError),
      -300,
      scrollable: scrollable,
    );

    expect(find.text(categoryError), findsOneWidget);
  });
}

class _FakeBehaviorRepository implements BehaviorRepository {
  @override
  Future<void> saveBehavior(BehaviorRecord record) async {}

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    return const [];
  }
}

class _FakeBehaviorRecordIdGenerator implements BehaviorRecordIdGenerator {
  const _FakeBehaviorRecordIdGenerator();

  @override
  String generate() {
    return 'registro-widget-1';
  }
}
