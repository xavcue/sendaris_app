import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sendaris/features/routine_compliance/domain/exceptions/routine_compliance_failure.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/presentation/viewmodels/routine_compliance_view_model.dart';
import 'package:sendaris/features/routine_compliance/presentation/views/routine_compliance_view.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

void main() {
  group('RoutineComplianceView', () {
    testWidgets(
      'muestra la pantalla inicial con lenguaje descriptivo y sencillo',
      (tester) async {
        final repository = _FakeRoutineComplianceRepository();

        await _pumpView(tester, repository);

        expect(find.text('Cumplimiento de rutinas'), findsOneWidget);

        expect(
          find.text('Consulta el cumplimiento registrado'),
          findsOneWidget,
        );

        expect(find.text('Periodo de consulta'), findsOneWidget);

        expect(
          find.byKey(const Key('routine-compliance-calculate-button')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'calcular sin periodo muestra validación y no consulta la fuente',
      (tester) async {
        final repository = _FakeRoutineComplianceRepository();

        await _pumpView(tester, repository);

        await tester.tap(
          find.byKey(const Key('routine-compliance-calculate-button')),
        );

        await tester.pump();

        expect(
          find.byKey(const Key('routine-compliance-period-error')),
          findsOneWidget,
        );

        expect(
          find.text('Selecciona una fecha inicial y una fecha final.'),
          findsOneWidget,
        );

        expect(repository.requests, isEmpty);
      },
    );

    testWidgets('el selector de fecha abre el calendario', (tester) async {
      final repository = _FakeRoutineComplianceRepository();

      await _pumpView(tester, repository);

      await tester.tap(
        find.byKey(const Key('routine-compliance-start-date-button')),
      );

      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('Cancelar'));

      await tester.pumpAndSettle();
    });

    testWidgets('presenta registros completados y porcentaje exacto', (
      tester,
    ) async {
      final repository = _FakeRoutineComplianceRepository(
        entries: [
          _entry(id: 'e1', routineId: 'r1', status: RoutineStatus.completed),
          _entry(id: 'e2', routineId: 'r2', status: RoutineStatus.completed),
          _entry(id: 'e3', routineId: 'r3', status: RoutineStatus.modified),
          _entry(id: 'e4', routineId: 'r4', status: RoutineStatus.notCompleted),
        ],
      );

      await _pumpView(tester, repository);

      final viewModel = _readViewModel(tester);

      _selectValidPeriod(viewModel);

      await tester.pump();

      await tester.tap(
        find.byKey(const Key('routine-compliance-calculate-button')),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('routine-compliance-result-card')),
        findsOneWidget,
      );

      expect(find.text('Cumplimiento descriptivo'), findsOneWidget);

      expect(find.text('50 %'), findsOneWidget);

      expect(
        find.byKey(const Key('routine-compliance-programmed-count')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-compliance-completed-count')),
        findsOneWidget,
      );

      expect(find.text('Registros de rutina'), findsOneWidget);

      expect(find.text('Completados'), findsOneWidget);

      expect(find.text('4'), findsOneWidget);

      expect(find.text('2'), findsOneWidget);

      expect(
        find.text(
          'En este periodo hay 4 registros de rutina '
          'y 2 están marcados como completados.',
        ),
        findsOneWidget,
      );

      expect(
        find.text(
          'Cada registro corresponde al estado de '
          'una rutina en una fecha.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'estados distintos de completada no incrementan el conteo completado',
      (tester) async {
        final repository = _FakeRoutineComplianceRepository(
          entries: [
            _entry(id: 'e1', routineId: 'r1', status: RoutineStatus.completed),
            _entry(id: 'e2', routineId: 'r2', status: RoutineStatus.modified),
            _entry(
              id: 'e3',
              routineId: 'r3',
              status: RoutineStatus.interrupted,
            ),
            _entry(
              id: 'e4',
              routineId: 'r4',
              status: RoutineStatus.notCompleted,
            ),
          ],
        );

        await _pumpView(tester, repository);

        final viewModel = _readViewModel(tester);

        _selectValidPeriod(viewModel);

        await tester.pump();

        await tester.tap(
          find.byKey(const Key('routine-compliance-calculate-button')),
        );

        await tester.pumpAndSettle();

        expect(find.text('25 %'), findsOneWidget);

        expect(viewModel.programmedCount, 4);

        expect(viewModel.completedCount, 1);
      },
    );

    testWidgets('sin registros de rutina no muestra un porcentaje artificial', (
      tester,
    ) async {
      final repository = _FakeRoutineComplianceRepository();

      await _pumpView(tester, repository);

      final viewModel = _readViewModel(tester);

      _selectValidPeriod(viewModel);

      await tester.pump();

      await tester.tap(
        find.byKey(const Key('routine-compliance-calculate-button')),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('routine-compliance-no-programmed-card')),
        findsOneWidget,
      );

      expect(
        find.text('No hay registros de rutina en el periodo'),
        findsOneWidget,
      );

      expect(
        find.text(
          'No se encontraron estados de rutina registrados '
          'entre las fechas seleccionadas.',
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-compliance-percentage-value')),
        findsNothing,
      );

      expect(find.text('0 %'), findsNothing);

      expect(
        find.byKey(const Key('routine-compliance-no-percentage-message')),
        findsOneWidget,
      );

      expect(
        find.text(
          'El porcentaje no se calcula porque '
          'todavía no hay registros de rutina '
          'en este periodo.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('registros sin completados muestran cero por ciento real', (
      tester,
    ) async {
      final repository = _FakeRoutineComplianceRepository(
        entries: [
          _entry(id: 'e1', routineId: 'r1', status: RoutineStatus.modified),
          _entry(id: 'e2', routineId: 'r2', status: RoutineStatus.interrupted),
        ],
      );

      await _pumpView(tester, repository);

      final viewModel = _readViewModel(tester);

      _selectValidPeriod(viewModel);

      await tester.pump();

      await tester.tap(
        find.byKey(const Key('routine-compliance-calculate-button')),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('routine-compliance-result-card')),
        findsOneWidget,
      );

      expect(find.text('0 %'), findsOneWidget);

      expect(viewModel.programmedCount, 2);

      expect(viewModel.completedCount, 0);

      expect(
        find.text(
          'En este periodo hay 2 registros de rutina '
          'y 0 están marcados como completados.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('presenta porcentaje decimal cuando corresponde', (
      tester,
    ) async {
      final repository = _FakeRoutineComplianceRepository(
        entries: [
          _entry(id: 'e1', routineId: 'r1', status: RoutineStatus.completed),
          _entry(id: 'e2', routineId: 'r2', status: RoutineStatus.modified),
          _entry(id: 'e3', routineId: 'r3', status: RoutineStatus.notCompleted),
        ],
      );

      await _pumpView(tester, repository);

      final viewModel = _readViewModel(tester);

      _selectValidPeriod(viewModel);

      await tester.pump();

      await tester.tap(
        find.byKey(const Key('routine-compliance-calculate-button')),
      );

      await tester.pumpAndSettle();

      expect(find.text('33.3 %'), findsOneWidget);
    });

    testWidgets('muestra un fallo controlado sin exponer detalles internos', (
      tester,
    ) async {
      final repository = _FakeRoutineComplianceRepository(
        error: const RoutineComplianceFailure(
          'No fue posible recuperar la información '
          'para calcular el cumplimiento de rutinas. '
          'Inténtalo nuevamente.',
        ),
      );

      await _pumpView(tester, repository);

      final viewModel = _readViewModel(tester);

      _selectValidPeriod(viewModel);

      await tester.pump();

      await tester.tap(
        find.byKey(const Key('routine-compliance-calculate-button')),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('routine-compliance-general-error')),
        findsOneWidget,
      );

      expect(
        find.text(
          'No fue posible recuperar la información '
          'para calcular el cumplimiento de rutinas. '
          'Inténtalo nuevamente.',
        ),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-compliance-result-card')),
        findsNothing,
      );
    });

    testWidgets('la interfaz mantiene presentación descriptiva y neutral', (
      tester,
    ) async {
      final repository = _FakeRoutineComplianceRepository(
        entries: [
          _entry(id: 'e1', routineId: 'r1', status: RoutineStatus.completed),
        ],
      );

      await _pumpView(tester, repository);

      final viewModel = _readViewModel(tester);

      _selectValidPeriod(viewModel);

      await tester.pump();

      await tester.tap(
        find.byKey(const Key('routine-compliance-calculate-button')),
      );

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('routine-compliance-descriptive-message')),
        findsOneWidget,
      );

      expect(
        find.byKey(const Key('routine-compliance-record-explanation')),
        findsOneWidget,
      );

      expect(find.textContaining('adaptación'), findsNothing);

      expect(find.textContaining('bienestar'), findsNothing);

      expect(find.textContaining('adherencia'), findsNothing);

      expect(find.textContaining('calidad del cuidado'), findsNothing);

      expect(find.textContaining('evaluación clínica'), findsNothing);
    });

    testWidgets('después de calcular desplaza la pantalla hacia el resultado', (
      tester,
    ) async {
      final repository = _FakeRoutineComplianceRepository(
        entries: [
          _entry(id: 'e1', routineId: 'r1', status: RoutineStatus.completed),
        ],
      );

      await _pumpView(tester, repository, size: const Size(500, 700));

      final viewModel = _readViewModel(tester);

      _selectValidPeriod(viewModel);

      await tester.pump();

      final calculateButton = find.byKey(
        const Key('routine-compliance-calculate-button'),
      );

      await tester.ensureVisible(calculateButton);

      await tester.pumpAndSettle();

      expect(calculateButton.hitTestable(), findsOneWidget);

      await tester.tap(calculateButton);

      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('routine-compliance-result-card')).hitTestable(),
        findsOneWidget,
      );

      expect(find.text('100 %'), findsOneWidget);
    });
  });
}

Future<void> _pumpView(
  WidgetTester tester,
  _FakeRoutineComplianceRepository repository, {
  Size size = const Size(1000, 1800),
}) async {
  tester.view.physicalSize = size;

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

  await tester.pump();
}

RoutineComplianceViewModel _readViewModel(WidgetTester tester) {
  final context = tester.element(
    find.byKey(const Key('routine-compliance-screen')),
  );

  return Provider.of<RoutineComplianceViewModel>(context, listen: false);
}

void _selectValidPeriod(RoutineComplianceViewModel viewModel) {
  viewModel.setStartDate(DateTime(2026, 9, 1));

  viewModel.setEndDate(DateTime(2026, 9, 15));
}

RoutineComplianceEntry _entry({
  required String id,
  required String routineId,
  required RoutineStatus status,
  String anonymousId = 'perfil-a',
  DateTime? date,
}) {
  return RoutineComplianceEntry(
    recordId: id,
    anonymousId: anonymousId,
    routineId: routineId,
    date: date ?? DateTime(2026, 9, 5),
    status: status,
  );
}

class _FakeRoutineComplianceRepository implements RoutineComplianceRepository {
  _FakeRoutineComplianceRepository({
    List<RoutineComplianceEntry> entries = const [],
    this.error,
  }) : entries = List<RoutineComplianceEntry>.from(entries);

  List<RoutineComplianceEntry> entries;

  Object? error;

  final List<String> requests = [];

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) async {
    requests.add(anonymousId);

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(entries);
  }
}
