import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine_compliance/data/repositories/composite_routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/domain/exceptions/routine_compliance_failure.dart';
import 'package:sendaris/features/routine_compliance/domain/models/routine_compliance_entry.dart';
import 'package:sendaris/features/routine_compliance/domain/repositories/routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/domain/services/routine_overview_service.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';
import 'package:sendaris/features/routine_status/domain/repositories/routine_status_repository.dart';

RoutineComplianceEntry _entry({
  required String id,
  required String routineId,
  required RoutineStatus status,
  String anonymousId = 'perfil-a',
  String? routineName,
  int day = 15,
}) {
  return RoutineComplianceEntry(
    recordId: id,
    anonymousId: anonymousId,
    routineId: routineId,
    routineName: routineName,
    date: DateTime(2026, 10, day),
    status: status,
  );
}

class _FakeComplianceRepository implements RoutineComplianceRepository {
  _FakeComplianceRepository({this.entries = const [], this.error});

  final List<RoutineComplianceEntry> entries;

  final Object? error;

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

class _FakeRoutineRepository implements RoutineRepository {
  _FakeRoutineRepository(this.routines);

  final List<Routine> routines;

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

class _FakeRoutineStatusRepository implements RoutineStatusRepository {
  _FakeRoutineStatusRepository(this.records);

  final List<RoutineStatusRecord> records;

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    return List<RoutineStatusRecord>.unmodifiable(records);
  }

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {}
}

RoutineStatusRecord _statusRecord({
  required String id,
  required String routineId,
  required RoutineStatus status,
  String anonymousId = 'perfil-a',
}) {
  return RoutineStatusRecord(
    recordId: id,
    anonymousId: anonymousId,
    routineId: routineId,
    date: DateTime(2026, 10, 15),
    status: status,
    createdAt: DateTime.utc(2026, 10, 15, 10),
    updatedAt: DateTime.utc(2026, 10, 15, 10),
  );
}

Future<RoutineOverview> _load(
  RoutineComplianceRepository repository, {
  String anonymousId = 'perfil-a',
  DateTime? startDate,
  DateTime? endDate,
}) {
  return RoutineOverviewService(repository).load(
    anonymousId: anonymousId,
    startDate: startDate ?? DateTime(2026, 10, 1),
    endDate: endDate ?? DateTime(2026, 10, 31),
  );
}

void main() {
  group('RoutineOverviewService', () {
    test('preserva IND-09 y cuenta los cuatro estados', () async {
      final repository = _FakeComplianceRepository(
        entries: [
          _entry(
            id: 'e1',
            routineId: 'r1',
            routineName: 'Desayuno',
            status: RoutineStatus.completed,
          ),
          _entry(
            id: 'e2',
            routineId: 'r1',
            routineName: 'Desayuno',
            status: RoutineStatus.completed,
          ),
          _entry(
            id: 'e3',
            routineId: 'r1',
            routineName: 'Desayuno',
            status: RoutineStatus.modified,
          ),
          _entry(
            id: 'e4',
            routineId: 'r2',
            routineName: 'Aseo personal',
            status: RoutineStatus.interrupted,
          ),
          _entry(
            id: 'e5',
            routineId: 'r2',
            routineName: 'Aseo personal',
            status: RoutineStatus.notCompleted,
          ),
        ],
      );

      final overview = await _load(repository);

      expect(repository.requests, ['perfil-a']);

      expect(overview.totalRecords, 5);
      expect(overview.completedCount, 2);
      expect(overview.compliancePercentage, 40);

      expect(overview.countForStatus(RoutineStatus.completed), 2);

      expect(overview.countForStatus(RoutineStatus.modified), 1);

      expect(overview.countForStatus(RoutineStatus.interrupted), 1);

      expect(overview.countForStatus(RoutineStatus.notCompleted), 1);

      expect(overview.routines, hasLength(2));

      expect(overview.result.query.anonymousId, 'perfil-a');
    });

    test('calcula porcentajes independientes por rutina', () async {
      final repository = _FakeComplianceRepository(
        entries: [
          _entry(
            id: 'a1',
            routineId: 'rutina-a',
            routineName: 'Alimentación',
            status: RoutineStatus.completed,
          ),
          _entry(
            id: 'a2',
            routineId: 'rutina-a',
            routineName: 'Alimentación',
            status: RoutineStatus.modified,
          ),
          _entry(
            id: 'b1',
            routineId: 'rutina-b',
            routineName: 'Dormir',
            status: RoutineStatus.completed,
          ),
        ],
      );

      final overview = await _load(repository);

      expect(overview.totalRecords, 3);

      expect(overview.compliancePercentage, closeTo(66.6666667, 0.0001));

      final alimentacion = overview.routines.firstWhere(
        (routine) => routine.routineName == 'Alimentación',
      );

      final dormir = overview.routines.firstWhere(
        (routine) => routine.routineName == 'Dormir',
      );

      expect(alimentacion.totalRecords, 2);
      expect(alimentacion.completedCount, 1);
      expect(alimentacion.compliancePercentage, 50);

      expect(dormir.totalRecords, 1);
      expect(dormir.completedCount, 1);
      expect(dormir.compliancePercentage, 100);
    });

    test('sin estados registrados no inventa un porcentaje', () async {
      final overview = await _load(_FakeComplianceRepository());

      expect(overview.hasRecords, isFalse);
      expect(overview.totalRecords, 0);
      expect(overview.completedCount, 0);
      expect(overview.compliancePercentage, isNull);

      expect(overview.routines, isEmpty);

      for (final status in RoutineStatus.values) {
        expect(overview.countForStatus(status), 0);
      }
    });

    test('estados registrados sin completadas representan 0 %', () async {
      final overview = await _load(
        _FakeComplianceRepository(
          entries: [
            _entry(id: 'm1', routineId: 'r1', status: RoutineStatus.modified),
            _entry(
              id: 'i1',
              routineId: 'r1',
              status: RoutineStatus.interrupted,
            ),
            _entry(
              id: 'n1',
              routineId: 'r1',
              status: RoutineStatus.notCompleted,
            ),
          ],
        ),
      );

      expect(overview.hasRecords, isTrue);
      expect(overview.totalRecords, 3);
      expect(overview.completedCount, 0);
      expect(overview.compliancePercentage, 0);
    });

    test('respeta fechas inclusivas y aislamiento por seguimiento', () async {
      final repository = _FakeComplianceRepository(
        entries: [
          _entry(
            id: 'inicio',
            routineId: 'r1',
            status: RoutineStatus.completed,
            day: 10,
          ),
          _entry(
            id: 'final',
            routineId: 'r1',
            status: RoutineStatus.modified,
            day: 20,
          ),
          _entry(
            id: 'fuera',
            routineId: 'r1',
            status: RoutineStatus.completed,
            day: 21,
          ),
          _entry(
            id: 'otro-perfil',
            routineId: 'r2',
            anonymousId: 'perfil-b',
            status: RoutineStatus.completed,
            day: 15,
          ),
        ],
      );

      final overview = await _load(
        repository,
        startDate: DateTime(2026, 10, 10),
        endDate: DateTime(2026, 10, 20),
      );

      expect(overview.totalRecords, 2);
      expect(overview.completedCount, 1);
      expect(overview.compliancePercentage, 50);
      expect(overview.routines, hasLength(1));
    });

    test('recupera nombres reales mediante el repositorio compuesto', () async {
      final routineRepository = _FakeRoutineRepository([
        const Routine(
          routineId: 'r1',
          anonymousId: 'perfil-a',
          name: 'Preparar mochila',
        ),
        const Routine(
          routineId: 'r2',
          anonymousId: 'perfil-b',
          name: 'Rutina de otro seguimiento',
        ),
      ]);

      final statusRepository = _FakeRoutineStatusRepository([
        _statusRecord(
          id: 'e1',
          routineId: 'r1',
          status: RoutineStatus.completed,
        ),
        _statusRecord(
          id: 'e2',
          routineId: 'r2',
          status: RoutineStatus.completed,
        ),
      ]);

      final repository = CompositeRoutineComplianceRepository(
        routineRepository: routineRepository,
        routineStatusRepository: statusRepository,
      );

      final overview = await _load(repository);

      expect(overview.routines, hasLength(1));

      expect(overview.routines.single.routineName, 'Preparar mochila');

      expect(overview.routines.single.totalRecords, 1);

      expect(overview.totalRecords, 1);
    });

    test('preserva las fallas controladas del repositorio', () async {
      final repository = _FakeComplianceRepository(
        error: const RoutineComplianceFailure(
          'No fue posible recuperar los registros.',
        ),
      );

      await expectLater(
        _load(repository),
        throwsA(isA<RoutineComplianceFailure>()),
      );
    });

    test('los resúmenes no exponen colecciones mutables', () async {
      final overview = await _load(
        _FakeComplianceRepository(
          entries: [
            _entry(
              id: 'e1',
              routineId: 'r1',
              routineName: 'Aseo',
              status: RoutineStatus.completed,
            ),
          ],
        ),
      );

      expect(() => overview.statusCounts.clear(), throwsUnsupportedError);

      expect(() => overview.routines.clear(), throwsUnsupportedError);

      expect(
        () => overview.routines.single.statusCounts.clear(),
        throwsUnsupportedError,
      );
    });
  });
}
