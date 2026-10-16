import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine_compliance/domain/exceptions/routine_compliance_failure.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/presentation/viewmodels/routine_overview_view_model.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';

class _FakeRepository implements RoutineComplianceRepository {
  _FakeRepository({this.entries = const [], this.error});

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

    return List<RoutineComplianceEntry>.unmodifiable(entries);
  }
}

class _DeferredRepository implements RoutineComplianceRepository {
  final List<Completer<List<RoutineComplianceEntry>>> pending = [];

  @override
  Future<List<RoutineComplianceEntry>> recoverEntries({
    required String anonymousId,
  }) {
    final completer = Completer<List<RoutineComplianceEntry>>();

    pending.add(completer);

    return completer.future;
  }

  void complete(int index, List<RoutineComplianceEntry> entries) {
    pending[index].complete(entries);
  }
}

RoutineComplianceEntry _entry({
  required String id,
  required RoutineStatus status,
  String anonymousId = 'perfil-a',
  String routineId = 'rutina-a',
  int day = 15,
}) {
  return RoutineComplianceEntry(
    recordId: id,
    anonymousId: anonymousId,
    routineId: routineId,
    routineName: 'Rutina de prueba',
    date: DateTime(2026, 10, day),
    status: status,
  );
}

RoutineOverviewViewModel _createViewModel(
  RoutineComplianceRepository repository, {
  String anonymousId = 'perfil-a',
}) {
  return RoutineOverviewViewModel(
    repository,
    anonymousId: anonymousId,
    clock: () => DateTime(2026, 10, 15, 14, 30),
  );
}

void main() {
  group('RoutineOverviewViewModel', () {
    test('inicia con el mes actual sin consultar automáticamente', () {
      final repository = _FakeRepository();
      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      expect(viewModel.selectedPeriod, RoutineOverviewPeriod.thisMonth);

      expect(viewModel.startDate, DateTime(2026, 10, 1));
      expect(viewModel.endDate, DateTime(2026, 10, 15));

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.overview, isNull);
      expect(viewModel.errorMessage, isNull);

      expect(repository.requests, isEmpty);
    });

    test('calcula el cumplimiento y conserva los cuatro estados', () async {
      final repository = _FakeRepository(
        entries: [
          _entry(id: 'c1', status: RoutineStatus.completed),
          _entry(id: 'm1', status: RoutineStatus.modified),
          _entry(id: 'i1', status: RoutineStatus.interrupted),
          _entry(id: 'n1', status: RoutineStatus.notCompleted),
        ],
      );

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(repository.requests, ['perfil-a']);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);
      expect(viewModel.hasRecords, isTrue);

      expect(viewModel.totalRecords, 4);
      expect(viewModel.completedCount, 1);
      expect(viewModel.compliancePercentage, 25);

      final overview = viewModel.overview!;

      for (final status in RoutineStatus.values) {
        expect(overview.countForStatus(status), 1);
      }

      expect(overview.routines, hasLength(1));
    });

    test('sin estados registrados no inventa un porcentaje', () async {
      final viewModel = _createViewModel(_FakeRepository());

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.overview, isNotNull);
      expect(viewModel.hasRecords, isFalse);
      expect(viewModel.totalRecords, 0);
      expect(viewModel.completedCount, 0);
      expect(viewModel.compliancePercentage, isNull);
    });

    test('con estados pero sin completadas devuelve 0 %', () async {
      final viewModel = _createViewModel(
        _FakeRepository(
          entries: [
            _entry(id: 'm1', status: RoutineStatus.modified),
            _entry(id: 'n1', status: RoutineStatus.notCompleted),
          ],
        ),
      );

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.hasRecords, isTrue);
      expect(viewModel.totalRecords, 2);
      expect(viewModel.compliancePercentage, 0);
    });

    test('los periodos rápidos se calculan correctamente', () async {
      final repository = _FakeRepository();
      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.selectPeriod(RoutineOverviewPeriod.sevenDays);

      expect(viewModel.startDate, DateTime(2026, 10, 9));
      expect(viewModel.endDate, DateTime(2026, 10, 15));

      await viewModel.selectPeriod(RoutineOverviewPeriod.thirtyDays);

      expect(viewModel.startDate, DateTime(2026, 9, 16));
      expect(viewModel.endDate, DateTime(2026, 10, 15));

      await viewModel.selectPeriod(RoutineOverviewPeriod.thisMonth);

      expect(viewModel.startDate, DateTime(2026, 10, 1));

      expect(repository.requests, hasLength(3));
    });

    test('el periodo personalizado normaliza y ajusta las fechas', () async {
      final repository = _FakeRepository();
      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.selectPeriod(RoutineOverviewPeriod.custom);

      expect(repository.requests, isEmpty);

      await viewModel.setDate(
        isStartDate: true,
        date: DateTime(2026, 11, 3, 20),
      );

      expect(viewModel.startDate, DateTime(2026, 11, 3));
      expect(viewModel.endDate, DateTime(2026, 11, 3));

      await viewModel.setDate(
        isStartDate: false,
        date: DateTime(2026, 11, 7, 9),
      );

      expect(viewModel.endDate, DateTime(2026, 11, 7));

      expect(viewModel.selectedPeriod, RoutineOverviewPeriod.custom);

      expect(repository.requests, hasLength(2));
    });

    test('muestra un error controlado y permite reintentar', () async {
      const message = 'No fue posible recuperar las rutinas.';

      final repository = _FakeRepository(
        error: const RoutineComplianceFailure(message),
      );

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.errorMessage, message);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.overview, isNull);

      repository.error = null;

      await viewModel.load();

      expect(viewModel.errorMessage, isNull);
      expect(viewModel.overview, isNotNull);

      expect(repository.requests, hasLength(2));
    });

    test('descarta una consulta anterior al cambiar de periodo', () async {
      final repository = _DeferredRepository();
      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      final firstRequest = viewModel.load();

      expect(viewModel.isLoading, isTrue);

      final secondRequest = viewModel.selectPeriod(
        RoutineOverviewPeriod.sevenDays,
      );

      expect(repository.pending, hasLength(2));

      repository.complete(1, [
        _entry(id: 'nuevo', status: RoutineStatus.completed),
      ]);

      await secondRequest;

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.compliancePercentage, 100);
      expect(viewModel.totalRecords, 1);

      repository.complete(0, [
        _entry(id: 'antiguo-1', status: RoutineStatus.modified),
        _entry(id: 'antiguo-2', status: RoutineStatus.interrupted),
      ]);

      await firstRequest;

      expect(viewModel.selectedPeriod, RoutineOverviewPeriod.sevenDays);

      expect(viewModel.compliancePercentage, 100);
      expect(viewModel.totalRecords, 1);
    });

    test('ignora respuestas que llegan después de dispose', () async {
      final repository = _DeferredRepository();
      final viewModel = _createViewModel(repository);

      final request = viewModel.load();

      expect(viewModel.isLoading, isTrue);

      viewModel.dispose();

      expect(viewModel.isDisposed, isTrue);

      repository.complete(0, [
        _entry(id: 'tardio', status: RoutineStatus.completed),
      ]);

      await request;

      expect(viewModel.overview, isNull);
    });

    test('no mezcla registros de seguimientos diferentes', () async {
      final repository = _FakeRepository(
        entries: [
          _entry(
            id: 'perfil-a',
            anonymousId: 'perfil-a',
            status: RoutineStatus.completed,
          ),
          _entry(
            id: 'perfil-b',
            anonymousId: 'perfil-b',
            status: RoutineStatus.notCompleted,
          ),
        ],
      );

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.totalRecords, 1);
      expect(viewModel.completedCount, 1);
      expect(viewModel.compliancePercentage, 100);

      expect(viewModel.overview!.anonymousId, 'perfil-a');
    });
  });
}
