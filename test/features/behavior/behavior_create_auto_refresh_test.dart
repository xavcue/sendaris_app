import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_category.dart';
import 'package:sendaris/features/behavior/domain/models/behavior_record.dart';
import 'package:sendaris/features/behavior/domain/repositories/behavior_management_repository.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_factory.dart';
import 'package:sendaris/features/behavior/domain/services/behavior_record_id_generator.dart';
import 'package:sendaris/features/behavior/presentation/viewmodels/behavior_form_view_model.dart';
import 'package:sendaris/features/behavior/presentation/views/behavior_form_view.dart';
import 'package:sendaris/features/behavior/presentation/views/behavior_management_view.dart';

void main() {
  testWidgets(
    'al crear una conducta vuelve al listado y muestra el nuevo registro',
    (tester) async {
      final repository = _FakeBehaviorRepository();
      final router = _createRouter(repository);

      addTearDown(router.dispose);

      await _configureScreen(tester);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(repository.recoveryCount, 1);
      expect(repository.savedRecords, isEmpty);

      expect(find.byKey(const Key('behavior-empty-state')), findsOneWidget);

      await tester.tap(find.byKey(const Key('behavior-new-button')));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.behaviorNew);

      expect(find.byKey(const Key('behavior-create-view')), findsOneWidget);

      final saveButton = find.byKey(const Key('behavior-save-button'));

      await tester.scrollUntilVisible(
        saveButton,
        300,
        scrollable: find.byType(Scrollable).first,
      );

      final formContext = tester.element(saveButton);

      final formViewModel = Provider.of<BehaviorFormViewModel>(
        formContext,
        listen: false,
      );

      formViewModel.setDate(DateTime(2026, 10, 15));

      formViewModel.setCategory(BehaviorCategory.repetitiveBehavior);

      await tester.pumpAndSettle();

      await tester.tap(saveButton);

      await tester.pumpAndSettle();

      expect(repository.savedRecords, hasLength(1));

      expect(repository.savedRecords.single.anonymousId, 'seguimiento-prueba');

      expect(router.state.uri.path, AppRoutes.behavior);

      expect(
        repository.recoveryCount,
        2,
        reason:
            'La lista debe consultar nuevamente los registros '
            'después de crear una conducta.',
      );

      expect(
        find.byKey(const Key('behavior-record-conducta-nueva')),
        findsOneWidget,
        reason:
            'La nueva conducta debe aparecer automáticamente '
            'sin actualizar manualmente.',
      );

      expect(find.byKey(const Key('behavior-empty-state')), findsNothing);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cancelar la creación no guarda ni recarga innecesariamente', (
    tester,
  ) async {
    final repository = _FakeBehaviorRepository();
    final router = _createRouter(repository);

    addTearDown(router.dispose);

    await _configureScreen(tester);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    await tester.pumpAndSettle();

    expect(repository.recoveryCount, 1);

    await tester.tap(find.byKey(const Key('behavior-new-button')));

    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.behaviorNew);

    router.pop();

    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRoutes.behavior);

    expect(repository.savedRecords, isEmpty);

    expect(repository.recoveryCount, 1);

    expect(find.byKey(const Key('behavior-empty-state')), findsOneWidget);
  });
}

GoRouter _createRouter(_FakeBehaviorRepository repository) {
  return GoRouter(
    initialLocation: AppRoutes.behavior,
    routes: [
      GoRoute(
        path: AppRoutes.behavior,
        builder: (context, state) {
          return BehaviorManagementView(
            repository: repository,
            anonymousId: 'seguimiento-prueba',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.behaviorNew,
        builder: (context, state) {
          return BehaviorFormView(
            repository: repository,
            recordFactory: const BehaviorRecordFactory(
              _FakeBehaviorRecordIdGenerator(),
            ),
            anonymousId: 'seguimiento-prueba',
          );
        },
      ),
    ],
  );
}

Future<void> _configureScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1100, 2200);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

class _FakeBehaviorRepository implements BehaviorManagementRepository {
  final List<BehaviorRecord> savedRecords = [];

  int recoveryCount = 0;

  @override
  Future<List<BehaviorRecord>> recoverBehaviors({
    required String anonymousId,
  }) async {
    recoveryCount++;

    return List<BehaviorRecord>.unmodifiable(
      savedRecords.where((record) => record.anonymousId == anonymousId),
    );
  }

  @override
  Future<void> saveBehavior(BehaviorRecord record) async {
    savedRecords.add(record);
  }

  @override
  Future<void> updateBehavior(BehaviorRecord record) async {
    final index = savedRecords.indexWhere(
      (existing) => existing.recordId == record.recordId,
    );

    if (index < 0) {
      throw StateError('Registro no encontrado.');
    }

    savedRecords[index] = record;
  }

  @override
  Future<void> deleteBehavior({
    required String anonymousId,
    required String recordId,
  }) async {
    savedRecords.removeWhere(
      (record) =>
          record.anonymousId == anonymousId && record.recordId == recordId,
    );
  }
}

class _FakeBehaviorRecordIdGenerator implements BehaviorRecordIdGenerator {
  const _FakeBehaviorRecordIdGenerator();

  @override
  String generate() {
    return 'conducta-nueva';
  }
}
