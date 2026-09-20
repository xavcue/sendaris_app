import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine_compliance/domain/exceptions/routine_compliance_failure.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/presentation/viewmodels/routine_compliance_view_model.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

void main() {
  late _FakeRoutineComplianceRepository repository;

  late RoutineComplianceViewModel viewModel;

  setUp(() {
    repository = _FakeRoutineComplianceRepository();

    viewModel = RoutineComplianceViewModel(repository, anonymousId: 'perfil-a');
  });

  test('inicia sin periodo ni resultado', () {
    expect(viewModel.startDate, isNull);

    expect(viewModel.endDate, isNull);

    expect(viewModel.hasResult, isFalse);

    expect(viewModel.programmedCount, 0);

    expect(viewModel.completedCount, 0);

    expect(viewModel.compliancePercentage, isNull);

    expect(viewModel.entries, isEmpty);

    expect(viewModel.isCalculating, isFalse);

    expect(viewModel.errorMessage, isNull);

    expect(viewModel.hasFieldErrors, isFalse);
  });

  test('normaliza las fechas seleccionadas eliminando la hora', () {
    viewModel.setStartDate(DateTime(2026, 9, 1, 18, 30));

    viewModel.setEndDate(DateTime(2026, 9, 15, 23, 59));

    expect(viewModel.startDate, DateTime(2026, 9, 1));

    expect(viewModel.endDate, DateTime(2026, 9, 15));
  });

  test(
    'calculate exige un periodo completo antes de consultar las fuentes',
    () async {
      final success = await viewModel.calculate();

      expect(success, isFalse);

      expect(
        viewModel.errorFor('period'),
        'Selecciona una fecha inicial y una fecha final.',
      );

      expect(repository.requests, isEmpty);
    },
  );

  test(
    'un periodo invertido se rechaza antes de consultar las fuentes',
    () async {
      viewModel.setStartDate(DateTime(2026, 9, 20));

      viewModel.setEndDate(DateTime(2026, 9, 10));

      final success = await viewModel.calculate();

      expect(success, isFalse);

      expect(
        viewModel.errorFor('period'),
        'La fecha inicial no puede ser posterior '
        'a la fecha final.',
      );

      expect(repository.requests, isEmpty);
    },
  );

  test('calcula correctamente programadas completadas y porcentaje', () async {
    repository.entries = [
      _entry(
        id: 'estado-1',
        routineId: 'rutina-1',
        date: DateTime(2026, 9, 5),
        status: RoutineStatus.completed,
      ),
      _entry(
        id: 'estado-2',
        routineId: 'rutina-2',
        date: DateTime(2026, 9, 6),
        status: RoutineStatus.completed,
      ),
      _entry(
        id: 'estado-3',
        routineId: 'rutina-3',
        date: DateTime(2026, 9, 7),
        status: RoutineStatus.modified,
      ),
      _entry(
        id: 'estado-4',
        routineId: 'rutina-4',
        date: DateTime(2026, 9, 8),
        status: RoutineStatus.notCompleted,
      ),
    ];

    _selectValidPeriod(viewModel);

    final success = await viewModel.calculate();

    expect(success, isTrue);

    expect(viewModel.hasResult, isTrue);

    expect(viewModel.hasProgrammedRoutines, isTrue);

    expect(viewModel.hasPercentage, isTrue);

    expect(viewModel.programmedCount, 4);

    expect(viewModel.completedCount, 2);

    expect(viewModel.compliancePercentage, 50);
  });

  test(
    'modificada interrumpida y no realizada no cuentan como completadas',
    () async {
      repository.entries = [
        _entry(
          id: 'completada',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 5),
          status: RoutineStatus.completed,
        ),
        _entry(
          id: 'modificada',
          routineId: 'rutina-2',
          date: DateTime(2026, 9, 6),
          status: RoutineStatus.modified,
        ),
        _entry(
          id: 'interrumpida',
          routineId: 'rutina-3',
          date: DateTime(2026, 9, 7),
          status: RoutineStatus.interrupted,
        ),
        _entry(
          id: 'no-realizada',
          routineId: 'rutina-4',
          date: DateTime(2026, 9, 8),
          status: RoutineStatus.notCompleted,
        ),
      ];

      _selectValidPeriod(viewModel);

      expect(await viewModel.calculate(), isTrue);

      expect(viewModel.programmedCount, 4);

      expect(viewModel.completedCount, 1);

      expect(viewModel.compliancePercentage, 25);
    },
  );

  test(
    'sin rutinas programadas conserva resultado sin fabricar porcentaje',
    () async {
      _selectValidPeriod(viewModel);

      final success = await viewModel.calculate();

      expect(success, isTrue);

      expect(viewModel.hasResult, isTrue);

      expect(viewModel.hasProgrammedRoutines, isFalse);

      expect(viewModel.hasNoProgrammedRoutines, isTrue);

      expect(viewModel.hasPercentage, isFalse);

      expect(viewModel.programmedCount, 0);

      expect(viewModel.completedCount, 0);

      expect(viewModel.compliancePercentage, isNull);
    },
  );

  test(
    'rutinas programadas sin completadas producen cero por ciento real',
    () async {
      repository.entries = [
        _entry(
          id: 'estado-1',
          routineId: 'rutina-1',
          date: DateTime(2026, 9, 5),
          status: RoutineStatus.modified,
        ),
        _entry(
          id: 'estado-2',
          routineId: 'rutina-2',
          date: DateTime(2026, 9, 6),
          status: RoutineStatus.interrupted,
        ),
      ];

      _selectValidPeriod(viewModel);

      expect(await viewModel.calculate(), isTrue);

      expect(viewModel.hasProgrammedRoutines, isTrue);

      expect(viewModel.hasNoProgrammedRoutines, isFalse);

      expect(viewModel.hasPercentage, isTrue);

      expect(viewModel.programmedCount, 2);

      expect(viewModel.completedCount, 0);

      expect(viewModel.compliancePercentage, 0);
    },
  );

  test('solo utiliza registros del perfil y periodo seleccionados', () async {
    repository.entries = [
      _entry(
        id: 'valido',
        routineId: 'rutina-1',
        date: DateTime(2026, 9, 5),
        status: RoutineStatus.completed,
      ),
      _entry(
        id: 'otro-perfil',
        anonymousId: 'perfil-b',
        routineId: 'rutina-2',
        date: DateTime(2026, 9, 6),
        status: RoutineStatus.completed,
      ),
      _entry(
        id: 'fuera-periodo',
        routineId: 'rutina-3',
        date: DateTime(2026, 9, 20),
        status: RoutineStatus.completed,
      ),
    ];

    _selectValidPeriod(viewModel);

    expect(await viewModel.calculate(), isTrue);

    expect(viewModel.programmedCount, 1);

    expect(viewModel.completedCount, 1);

    expect(viewModel.compliancePercentage, 100);

    expect(viewModel.entries.single.recordId, 'valido');
  });

  test('cada cálculo vuelve a recuperar las fuentes actuales', () async {
    _selectValidPeriod(viewModel);

    repository.entries = [
      _entry(
        id: 'estado-1',
        routineId: 'rutina-1',
        date: DateTime(2026, 9, 5),
        status: RoutineStatus.completed,
      ),
    ];

    expect(await viewModel.calculate(), isTrue);

    expect(viewModel.programmedCount, 1);

    expect(viewModel.completedCount, 1);

    expect(viewModel.compliancePercentage, 100);

    repository.entries = [
      _entry(
        id: 'estado-1',
        routineId: 'rutina-1',
        date: DateTime(2026, 9, 5),
        status: RoutineStatus.completed,
      ),
      _entry(
        id: 'estado-2',
        routineId: 'rutina-2',
        date: DateTime(2026, 9, 6),
        status: RoutineStatus.modified,
      ),
    ];

    expect(await viewModel.calculate(), isTrue);

    expect(viewModel.programmedCount, 2);

    expect(viewModel.completedCount, 1);

    expect(viewModel.compliancePercentage, 50);

    expect(repository.requests, ['perfil-a', 'perfil-a']);
  });

  test('cambiar el periodo invalida el resultado anterior', () async {
    repository.entries = [
      _entry(
        id: 'estado-1',
        routineId: 'rutina-1',
        date: DateTime(2026, 9, 5),
        status: RoutineStatus.completed,
      ),
    ];

    _selectValidPeriod(viewModel);

    await viewModel.calculate();

    expect(viewModel.hasResult, isTrue);

    viewModel.setEndDate(DateTime(2026, 9, 10));

    expect(viewModel.hasResult, isFalse);

    expect(viewModel.programmedCount, 0);

    expect(viewModel.completedCount, 0);

    expect(viewModel.compliancePercentage, isNull);
  });

  test('un identificador anónimo inválido se presenta como error controlado sin consultar fuentes', () async {
    final invalidViewModel = RoutineComplianceViewModel(
      repository,
      anonymousId: 'perfil/invalido',
    );

    _selectValidPeriod(invalidViewModel);

    final success = await invalidViewModel.calculate();

    expect(success, isFalse);

    expect(invalidViewModel.errorMessage, 'El perfil activo no es válido.');

    expect(repository.requests, isEmpty);

    invalidViewModel.dispose();
  });

  test('un RoutineComplianceFailure se presenta como error seguro', () async {
    repository.error = const RoutineComplianceFailure(
      'No fue posible recuperar la información '
      'para calcular el cumplimiento de rutinas. '
      'Inténtalo nuevamente.',
    );

    _selectValidPeriod(viewModel);

    final success = await viewModel.calculate();

    expect(success, isFalse);

    expect(
      viewModel.errorMessage,
      'No fue posible recuperar la información '
      'para calcular el cumplimiento de rutinas. '
      'Inténtalo nuevamente.',
    );

    expect(viewModel.hasResult, isFalse);
  });

  test('un error inesperado no expone detalles internos', () async {
    repository.error = Exception('Internal calculation details');

    _selectValidPeriod(viewModel);

    final success = await viewModel.calculate();

    expect(success, isFalse);

    expect(
      viewModel.errorMessage,
      'No fue posible calcular el cumplimiento '
      'de rutinas. Inténtalo nuevamente.',
    );

    expect(
      viewModel.errorMessage,
      isNot(contains('Internal calculation details')),
    );
  });

  test('clearError elimina un error general previo', () async {
    repository.error = const RoutineComplianceFailure('Error controlado.');

    _selectValidPeriod(viewModel);

    await viewModel.calculate();

    expect(viewModel.errorMessage, 'Error controlado.');

    viewModel.clearError();

    expect(viewModel.errorMessage, isNull);
  });
}

void _selectValidPeriod(RoutineComplianceViewModel viewModel) {
  viewModel.setStartDate(DateTime(2026, 9, 1));

  viewModel.setEndDate(DateTime(2026, 9, 15));
}

RoutineComplianceEntry _entry({
  required String id,
  required String routineId,
  required DateTime date,
  required RoutineStatus status,
  String anonymousId = 'perfil-a',
}) {
  return RoutineComplianceEntry(
    recordId: id,
    anonymousId: anonymousId,
    routineId: routineId,
    date: date,
    status: status,
  );
}

class _FakeRoutineComplianceRepository implements RoutineComplianceRepository {
  List<RoutineComplianceEntry> entries = [];

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
