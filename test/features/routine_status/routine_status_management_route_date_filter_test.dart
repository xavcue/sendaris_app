import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sendaris/app/router/app_routes.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';
import 'package:sendaris/features/routine_status/domain/repositories/routine_status_management_repository.dart';
import 'package:sendaris/features/routine_status/presentation/views/routine_status_management_view.dart';

void main() {
  group('RoutineStatusManagementView - filtro inicial desde ruta', () {
    testWidgets('date muestra solo rutinas con estados del día y conserva '
        'el filtro al entrar y volver', (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeRoutineStatusManagementRepository()
        ..records = [
          _record(
            recordId: 'mochila-hoy',
            routineId: 'rutina-mochila',
            date: DateTime(2026, 10, 12),
          ),
          _record(
            recordId: 'mochila-anterior',
            routineId: 'rutina-mochila',
            date: DateTime(2026, 10, 11),
          ),
          _record(
            recordId: 'lectura-anterior',
            routineId: 'rutina-lectura',
            date: DateTime(2026, 10, 11),
          ),
          _record(
            recordId: 'desayuno-hoy',
            routineId: 'rutina-desayuno',
            date: DateTime(2026, 10, 12),
          ),
        ];

      final routineRepository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: 'rutina-mochila',
            anonymousId: 'seguimiento-actual',
            name: 'Preparar mochila',
          ),
          Routine(
            routineId: 'rutina-lectura',
            anonymousId: 'seguimiento-actual',
            name: 'Rutina de lectura',
          ),
          Routine(
            routineId: 'rutina-desayuno',
            anonymousId: 'seguimiento-actual',
            name: 'Preparar desayuno',
          ),
        ],
      );

      final router = _createRouter(
        repository,
        routineRepository,
        initialLocation: '${AppRoutes.routineStatus}?date=2026-10-12',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRoutes.routineStatus);

      expect(router.state.uri.queryParameters['date'], '2026-10-12');

      expect(
        find.byKey(const Key('routine-status-routine-group-rutina-mochila')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-status-routine-group-rutina-desayuno')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-status-routine-group-rutina-lectura')),
        findsNothing,
      );

      expect(
        find.descendant(
          of: find.byKey(const Key('routine-status-routine-count')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );

      expect(
        find.text(
          'Se muestran únicamente las rutinas '
          'con estados registrados el 12 oct 2026.',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('routine-status-open-routine-rutina-mochila')),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('routine-status-selected-routine-list')),
        findsOneWidget,
      );

      expect(find.text('Preparar mochila'), findsOneWidget);

      expect(find.text('Filtro activo'), findsOneWidget);

      expect(
        find.descendant(
          of: find.byKey(const Key('routine-status-record-count')),
          matching: find.text('1 de 2'),
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-status-record-mochila-hoy')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-status-record-mochila-anterior')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('routine-status-filter-toggle-button')),
      );

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('routine-status-start-date-button'),
      );

      final endDateButton = find.byKey(
        const Key('routine-status-end-date-button'),
      );

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

      await tester.tap(
        find.byKey(const Key('routine-status-context-back-button')),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('routine-status-management-list')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-status-selected-routine-list')),
        findsNothing,
      );

      expect(
        find.byKey(const Key('routine-status-routine-group-rutina-mochila')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-status-routine-group-rutina-desayuno')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-status-routine-group-rutina-lectura')),
        findsNothing,
      );

      expect(
        find.text(
          'Se muestran únicamente las rutinas '
          'con estados registrados el 12 oct 2026.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('sin date conserva todas las rutinas y no aplica '
        'filtro automático', (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeRoutineStatusManagementRepository()
        ..records = [
          _record(
            recordId: 'mochila-hoy',
            routineId: 'rutina-mochila',
            date: DateTime(2026, 10, 12),
          ),
          _record(
            recordId: 'lectura-anterior',
            routineId: 'rutina-lectura',
            date: DateTime(2026, 10, 11),
          ),
        ];

      final routineRepository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: 'rutina-mochila',
            anonymousId: 'seguimiento-actual',
            name: 'Preparar mochila',
          ),
          Routine(
            routineId: 'rutina-lectura',
            anonymousId: 'seguimiento-actual',
            name: 'Rutina de lectura',
          ),
        ],
      );

      final router = _createRouter(
        repository,
        routineRepository,
        initialLocation: AppRoutes.routineStatus,
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(router.state.uri.queryParameters['date'], isNull);

      expect(
        find.byKey(const Key('routine-status-routine-group-rutina-mochila')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-status-routine-group-rutina-lectura')),
        findsOneWidget,
      );

      expect(
        find.text(
          'Cada tarjeta reúne todos los estados '
          'registrados para una misma rutina.',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('routine-status-open-routine-rutina-mochila')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);

      expect(
        find.byKey(const Key('routine-status-record-mochila-hoy')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('routine-status-filter-toggle-button')),
      );

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('routine-status-start-date-button'),
      );

      final endDateButton = find.byKey(
        const Key('routine-status-end-date-button'),
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

    testWidgets('date inválida se ignora de forma segura y conserva '
        'la navegación normal', (tester) async {
      tester.view.physicalSize = const Size(1000, 1800);

      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final repository = _FakeRoutineStatusManagementRepository()
        ..records = [
          _record(
            recordId: 'estado-1',
            routineId: 'rutina-1',
            date: DateTime(2026, 10, 12),
          ),
        ];

      final routineRepository = _FakeRoutineRepository(
        routines: const [
          Routine(
            routineId: 'rutina-1',
            anonymousId: 'seguimiento-actual',
            name: 'Rutina de prueba',
          ),
        ],
      );

      final router = _createRouter(
        repository,
        routineRepository,
        initialLocation: '${AppRoutes.routineStatus}?date=2026-02-31',
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));

      await tester.pumpAndSettle();

      expect(router.state.uri.queryParameters['date'], '2026-02-31');

      expect(
        find.byKey(const Key('routine-status-routine-group-rutina-1')),
        findsOneWidget,
      );

      expect(
        find.text(
          'Cada tarjeta reúne todos los estados '
          'registrados para una misma rutina.',
        ),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('routine-status-open-routine-rutina-1')),
      );

      await tester.pumpAndSettle();

      expect(find.text('Filtrar'), findsOneWidget);

      expect(find.text('Filtro activo'), findsNothing);

      await tester.tap(
        find.byKey(const Key('routine-status-filter-toggle-button')),
      );

      await tester.pumpAndSettle();

      final startDateButton = find.byKey(
        const Key('routine-status-start-date-button'),
      );

      final endDateButton = find.byKey(
        const Key('routine-status-end-date-button'),
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
  _FakeRoutineStatusManagementRepository repository,
  _FakeRoutineRepository routineRepository, {
  required String initialLocation,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: AppRoutes.routineStatus,
        builder: (context, state) {
          return RoutineStatusManagementView(
            repository: repository,
            routineRepository: routineRepository,
            anonymousId: 'seguimiento-actual',
          );
        },
      ),
    ],
  );
}

RoutineStatusRecord _record({
  required String recordId,
  required String routineId,
  required DateTime date,
}) {
  final timestamp = DateTime.utc(2026, 10, 12, 12);

  return RoutineStatusRecord(
    recordId: recordId,
    anonymousId: 'seguimiento-actual',
    routineId: routineId,
    date: date,
    status: RoutineStatus.completed,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

class _FakeRoutineStatusManagementRepository
    implements RoutineStatusManagementRepository {
  List<RoutineStatusRecord> records = [];

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    return List<RoutineStatusRecord>.unmodifiable(records);
  }

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {}

  @override
  Future<void> updateRoutineStatus(RoutineStatusRecord record) async {}

  @override
  Future<void> deleteRoutineStatus({
    required String anonymousId,
    required String recordId,
  }) async {
    records = records
        .where((record) => record.recordId != recordId)
        .toList(growable: false);
  }
}

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository({this.routines = const []});

  List<Routine> routines;

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    return List<Routine>.unmodifiable(routines);
  }

  @override
  Future<void> createRoutine(Routine routine) async {}

  @override
  Future<void> updateRoutine(Routine routine) async {}

  @override
  Future<void> deleteRoutine({
    required String anonymousId,
    required String routineId,
  }) async {}
}
