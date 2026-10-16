import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine_compliance/domain/exceptions/routine_compliance_failure.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/presentation/views/routine_compliance_view.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

RoutineComplianceEntry _entry({
  required String id,
  required RoutineStatus status,
  String routineId = 'rutina-a',
  String routineName = 'Preparar mochila',
  String anonymousId = 'perfil-a',
}) {
  final now = DateTime.now();

  return RoutineComplianceEntry(
    recordId: id,
    anonymousId: anonymousId,
    routineId: routineId,
    routineName: routineName,
    date: DateTime(now.year, now.month, now.day),
    status: status,
  );
}

class _FakeRoutineComplianceRepository implements RoutineComplianceRepository {
  _FakeRoutineComplianceRepository({this.entries = const [], this.error});

  List<RoutineComplianceEntry> entries;
  Object? error;

  final List<String> requests = [];

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    requests.add(anonymousId);

    if (error != null) {
      throw error!;
    }

    return List<RoutineComplianceEntry>.unmodifiable(entries);
  }
}

class _DeferredRoutineComplianceRepository
    implements RoutineComplianceRepository {
  final Map<String, Completer<List<RoutineComplianceEntry>>> pending = {};

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) {
    final completer = Completer<List<RoutineComplianceEntry>>();

    pending[anonymousId] = completer;

    return completer.future;
  }

  void complete(String anonymousId, List<RoutineComplianceEntry> entries) {
    pending[anonymousId]!.complete(entries);
  }
}

Future<void> _pumpView(
  WidgetTester tester,
  RoutineComplianceRepository repository, {
  String anonymousId = 'perfil-a',
}) async {
  tester.view.physicalSize = const Size(1000, 1800);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await tester.pumpWidget(
    MaterialApp(
      home: RoutineComplianceView(
        repository: repository,
        anonymousId: anonymousId,
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  group('RoutineComplianceView - Resumen de rutinas', () {
    testWidgets('carga automáticamente el resumen sin botón de cálculo', (
      tester,
    ) async {
      final repository = _FakeRoutineComplianceRepository();

      await _pumpView(tester, repository);

      expect(
        find.byKey(const Key('routine-compliance-screen')),
        findsOneWidget,
      );

      expect(find.text('Resumen de rutinas'), findsNWidgets(2));

      expect(find.text('Periodo de consulta'), findsOneWidget);

      expect(
        find.byKey(const Key('routine-overview-this-month')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-overview-percentage-card')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-overview-status-grid')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-compliance-calculate-button')),
        findsNothing,
      );

      expect(repository.requests, ['perfil-a']);
    });

    testWidgets('presenta el porcentaje y los cuatro estados', (tester) async {
      final repository = _FakeRoutineComplianceRepository(
        entries: [
          _entry(id: 'c1', status: RoutineStatus.completed),
          _entry(id: 'm1', status: RoutineStatus.modified),
          _entry(id: 'i1', status: RoutineStatus.interrupted),
          _entry(id: 'n1', status: RoutineStatus.notCompleted),
        ],
      );

      await _pumpView(tester, repository);

      expect(
        find.byKey(const Key('routine-overview-percentage-value')),
        findsOneWidget,
      );

      expect(find.text('25 %'), findsOneWidget);

      expect(
        find.text('1 completadas de 4 estados registrados'),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-overview-progress')),
        findsOneWidget,
      );

      for (final status in RoutineStatus.values) {
        final statusCard = find.byKey(
          Key('routine-overview-status-${status.name}'),
        );

        expect(statusCard, findsOneWidget);

        expect(
          find.descendant(of: statusCard, matching: find.text('1')),
          findsOneWidget,
        );

        expect(
          find.descendant(of: statusCard, matching: find.text(status.label)),
          findsOneWidget,
        );
      }
    });

    testWidgets('sin estados muestra Sin datos y no inventa 0 %', (
      tester,
    ) async {
      await _pumpView(tester, _FakeRoutineComplianceRepository());

      expect(find.text('Sin datos'), findsOneWidget);

      expect(
        find.byKey(const Key('routine-compliance-no-percentage-message')),
        findsOneWidget,
      );

      expect(find.byKey(const Key('routine-overview-progress')), findsNothing);

      expect(
        find.text('0 completadas de 0 estados registrados'),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-overview-no-routines')),
        findsOneWidget,
      );

      expect(find.text('0 %'), findsNothing);
    });

    testWidgets('con estados sin completadas muestra 0 % real', (tester) async {
      final repository = _FakeRoutineComplianceRepository(
        entries: [
          _entry(id: 'm1', status: RoutineStatus.modified),
          _entry(id: 'n1', status: RoutineStatus.notCompleted),
        ],
      );

      await _pumpView(tester, repository);

      expect(find.text('0 %'), findsOneWidget);

      expect(
        find.text('0 completadas de 2 estados registrados'),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-overview-progress')),
        findsOneWidget,
      );
    });

    testWidgets('el porcentaje conserva los decimales', (tester) async {
      final repository = _FakeRoutineComplianceRepository(
        entries: [
          _entry(id: 'c1', status: RoutineStatus.completed),
          _entry(id: 'm1', status: RoutineStatus.modified),
          _entry(id: 'i1', status: RoutineStatus.interrupted),
        ],
      );

      await _pumpView(tester, repository);

      expect(find.text('33.3 %'), findsOneWidget);
    });

    testWidgets('permite desplegar cada rutina por su nombre', (tester) async {
      final repository = _FakeRoutineComplianceRepository(
        entries: [
          _entry(id: 'c1', status: RoutineStatus.completed),
          _entry(id: 'm1', status: RoutineStatus.modified),
        ],
      );

      await _pumpView(tester, repository);

      final card = find.byKey(const Key('routine-overview-item-0'));

      await tester.ensureVisible(card);
      await tester.pumpAndSettle();

      expect(find.text('Preparar mochila'), findsOneWidget);

      await tester.tap(
        find.descendant(of: card, matching: find.byType(ExpansionTile)),
      );

      await tester.pumpAndSettle();

      expect(
        find.descendant(of: card, matching: find.text('50 %')),
        findsOneWidget,
      );

      expect(
        find.descendant(of: card, matching: find.text('Completada')),
        findsOneWidget,
      );

      expect(
        find.descendant(of: card, matching: find.text('Modificada')),
        findsOneWidget,
      );

      expect(find.textContaining('rutina-a'), findsNothing);
      expect(find.textContaining('perfil-a'), findsNothing);
    });

    testWidgets('un filtro rápido actualiza la consulta', (tester) async {
      final repository = _FakeRoutineComplianceRepository();

      await _pumpView(tester, repository);

      expect(repository.requests, hasLength(1));

      await tester.tap(find.byKey(const Key('routine-overview-seven-days')));

      await tester.pumpAndSettle();

      expect(repository.requests, hasLength(2));

      expect(
        find.byKey(const Key('routine-overview-selected-period')),
        findsOneWidget,
      );
    });

    testWidgets('el periodo personalizado abre el selector de fechas', (
      tester,
    ) async {
      await _pumpView(tester, _FakeRoutineComplianceRepository());

      await tester.tap(find.byKey(const Key('routine-overview-custom')));

      await tester.pumpAndSettle();

      final button = find.byKey(
        const Key('routine-compliance-start-date-button'),
      );

      expect(button, findsOneWidget);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
    });

    testWidgets('los errores se muestran sin resultados parciales', (
      tester,
    ) async {
      const message = 'No fue posible recuperar los estados.';

      final repository = _FakeRoutineComplianceRepository(
        error: const RoutineComplianceFailure(message),
      );

      await _pumpView(tester, repository);

      expect(
        find.byKey(const Key('routine-compliance-general-error')),
        findsOneWidget,
      );

      expect(find.text(message), findsOneWidget);

      expect(
        find.byKey(const Key('routine-overview-percentage-card')),
        findsNothing,
      );
    });

    testWidgets('no muestra resultados atrasados de otro seguimiento', (
      tester,
    ) async {
      final repository = _DeferredRoutineComplianceRepository();

      tester.view.physicalSize = const Size(1000, 1800);
      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: RoutineComplianceView(
            repository: repository,
            anonymousId: 'perfil-a',
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: RoutineComplianceView(
            repository: repository,
            anonymousId: 'perfil-b',
          ),
        ),
      );

      repository.complete('perfil-b', [
        _entry(
          id: 'registro-b',
          anonymousId: 'perfil-b',
          status: RoutineStatus.completed,
        ),
      ]);

      await tester.pumpAndSettle();

      expect(find.text('100 %'), findsOneWidget);

      repository.complete('perfil-a', [
        _entry(
          id: 'registro-a',
          anonymousId: 'perfil-a',
          status: RoutineStatus.notCompleted,
        ),
      ]);

      await tester.pumpAndSettle();

      expect(find.text('100 %'), findsOneWidget);
      expect(find.text('0 %'), findsNothing);
    });
  });
}
