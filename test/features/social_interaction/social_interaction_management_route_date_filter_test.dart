import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_category.dart';
import 'package:sendaris/features/social_interaction/domain/models/social_interaction_record.dart';
import 'package:sendaris/features/social_interaction/domain/repositories/social_interaction_management_repository.dart';
import 'package:sendaris/features/social_interaction/presentation/views/social_interaction_management_view.dart';

void main() {
  group('SocialInteractionManagementView - filtro inicial desde ruta', () {
    testWidgets('date filtra automáticamente el listado al día solicitado', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeSocialInteractionManagementRepository()
        ..records = [
          _record(recordId: 'interaccion-hoy-1', date: DateTime(2026, 10, 12)),
          _record(recordId: 'interaccion-hoy-2', date: DateTime(2026, 10, 12)),
          _record(
            recordId: 'interaccion-anterior',
            date: DateTime(2026, 10, 11),
          ),
        ];

      final router = _createRouter(
        repository,
        initialLocation: '${AppRoutes.socialInteraction}?date=2026-10-12',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.socialInteraction);

      expect(router.state.uri.queryParameters['date'], '2026-10-12');

      expect(find.text('Filtro activo'), findsOneWidget);

      expect(
        find.descendant(
          of: find.byKey(const Key('social-interaction-record-count')),
          matching: find.text('2 de 3'),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('social-interaction-record-interaccion-hoy-1')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('social-interaction-record-interaccion-hoy-2')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('social-interaction-record-interaccion-anterior')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('social-interaction-filter-toggle')),
      );

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('social-interaction-start-date-button'),
      );

      final endDateButton = find.byKey(
        const Key('social-interaction-end-date-button'),
      );

      expect(startDateButton, findsOneWidget);

      expect(endDateButton, findsOneWidget);

      expect(
        find.descendant(
          of: startDateButton,
          matching: find.text('12 oct 2026'),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(of: endDateButton, matching: find.text('12 oct 2026')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('social-interaction-clear-date-filter')),
        findsOneWidget,
      );
    });

    testWidgets('sin date conserva el listado normal sin filtro automático', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeSocialInteractionManagementRepository()
        ..records = [
          _record(recordId: 'interaccion-hoy', date: DateTime(2026, 10, 12)),
          _record(
            recordId: 'interaccion-anterior',
            date: DateTime(2026, 10, 11),
          ),
        ];

      final router = _createRouter(
        repository,
        initialLocation: AppRoutes.socialInteraction,
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);

      expect(
        find.byKey(const Key('social-interaction-record-interaccion-hoy')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('social-interaction-record-interaccion-anterior')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('social-interaction-filter-toggle')),
      );

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('social-interaction-start-date-button'),
      );

      final endDateButton = find.byKey(
        const Key('social-interaction-end-date-button'),
      );

      expect(
        find.descendant(
          of: startDateButton,
          matching: find.text('Sin seleccionar'),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: endDateButton,
          matching: find.text('Sin seleccionar'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('date inválida se ignora de forma segura', (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeSocialInteractionManagementRepository()
        ..records = [
          _record(recordId: 'interaccion-1', date: DateTime(2026, 10, 12)),
        ];

      final router = _createRouter(
        repository,
        initialLocation: '${AppRoutes.socialInteraction}?date=2026-02-31',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);

      expect(
        find.byKey(const Key('social-interaction-record-interaccion-1')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('social-interaction-filter-toggle')),
      );

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('social-interaction-start-date-button'),
      );

      final endDateButton = find.byKey(
        const Key('social-interaction-end-date-button'),
      );

      expect(
        find.descendant(
          of: startDateButton,
          matching: find.text('Sin seleccionar'),
        ),
        findsOneWidget,
      );

      expect(
        find.descendant(
          of: endDateButton,
          matching: find.text('Sin seleccionar'),
        ),
        findsOneWidget,
      );
    });
  });
}

GoRouter _createRouter(
  _FakeSocialInteractionManagementRepository repository, {
  required String initialLocation,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.socialInteraction,
        builder: (context, state) {
          return SocialInteractionManagementView(
            repository: repository,
            anonymousId: 'seguimiento-actual',
          );
        },
      ),
    ],
  );
}

SocialInteractionRecord _record({
  required String recordId,
  required DateTime date,
}) {
  final timestamp = DateTime.utc(2026, 10, 12, 12);

  return SocialInteractionRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    date: date,
    category: SocialInteractionCategory.interactionInitiation,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _FakeSocialInteractionManagementRepository
    implements SocialInteractionManagementRepository {
  List<SocialInteractionRecord> records = [];

  @override
  Future<List<SocialInteractionRecord>> recoverSocialInteractions({
    required String anonymousId,
  }) async {
    return List<SocialInteractionRecord>.unmodifiable(records);
  }

  @override
  Future<void> saveSocialInteraction(SocialInteractionRecord record) async {}

  @override
  Future<void> updateSocialInteraction(SocialInteractionRecord record) async {}

  @override
  Future<void> deleteSocialInteraction({
    required String anonymousId,
    required String recordId,
  }) async {
    records = records
        .where((record) => record.recordId != recordId)
        .toList(growable: false);
  }
}
