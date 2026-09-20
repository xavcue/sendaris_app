import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/routine/domain/models/routine.dart';
import 'package:sendaris/features/routine/domain/repositories/routine_repository.dart';
import 'package:sendaris/features/routine_compliance/data/repositories/composite_routine_compliance_repository.dart';
import 'package:sendaris/features/routine_compliance/domain/exceptions/routine_compliance_failure.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status.dart';
import 'package:sendaris/features/routine_status/domain/models/routine_status_record.dart';
import 'package:sendaris/features/routine_status/domain/repositories/routine_status_repository.dart';

void main() {
  late _FakeRoutineRepository routineRepository;

  late _FakeRoutineStatusRepository routineStatusRepository;

  late CompositeRoutineComplianceRepository repository;

  setUp(() {
    routineRepository = _FakeRoutineRepository();

    routineStatusRepository = _FakeRoutineStatusRepository();

    repository = CompositeRoutineComplianceRepository(
      routineRepository: routineRepository,
      routineStatusRepository: routineStatusRepository,
    );
  });

  test(
    'recupera estados válidos vinculados a rutinas del perfil activo',
    () async {
      routineRepository.routines = [
        _routine(id: 'rutina-1'),
        _routine(id: 'rutina-2'),
      ];

      routineStatusRepository.records = [
        _statusRecord(
          id: 'estado-1',
          routineId: 'rutina-1',
          status: RoutineStatus.completed,
        ),
        _statusRecord(
          id: 'estado-2',
          routineId: 'rutina-2',
          status: RoutineStatus.modified,
        ),
      ];

      final entries = await repository.recoverEntries(anonymousId: 'perfil-a');

      expect(entries, hasLength(2));

      expect(entries[0].routineId, 'rutina-1');

      expect(entries[0].status, RoutineStatus.completed);

      expect(entries[1].routineId, 'rutina-2');

      expect(entries[1].status, RoutineStatus.modified);

      expect(routineRepository.requestedIds, ['perfil-a']);

      expect(routineStatusRepository.requestedIds, ['perfil-a']);
    },
  );

  test('conserva estados históricos de rutinas desactivadas', () async {
    routineRepository.routines = [
      _routine(id: 'rutina-inactiva', isActive: false),
    ];

    routineStatusRepository.records = [
      _statusRecord(
        id: 'estado-historico',
        routineId: 'rutina-inactiva',
        status: RoutineStatus.completed,
      ),
    ];

    final entries = await repository.recoverEntries(anonymousId: 'perfil-a');

    expect(entries, hasLength(1));

    expect(entries.single.routineId, 'rutina-inactiva');

    expect(entries.single.status, RoutineStatus.completed);
  });

  test(
    'descarta estados pertenecientes a otro identificador anónimo',
    () async {
      routineRepository.routines = [_routine(id: 'rutina-1')];

      routineStatusRepository.records = [
        _statusRecord(
          id: 'estado-valido',
          routineId: 'rutina-1',
          status: RoutineStatus.completed,
        ),
        _statusRecord(
          id: 'estado-otro-perfil',
          anonymousId: 'perfil-b',
          routineId: 'rutina-1',
          status: RoutineStatus.completed,
        ),
      ];

      final entries = await repository.recoverEntries(anonymousId: 'perfil-a');

      expect(entries, hasLength(1));

      expect(entries.single.recordId, 'estado-valido');
    },
  );

  test('descarta un estado cuya rutina no existe en la fuente', () async {
    routineRepository.routines = [_routine(id: 'rutina-existente')];

    routineStatusRepository.records = [
      _statusRecord(
        id: 'estado-sin-rutina',
        routineId: 'rutina-inexistente',
        status: RoutineStatus.completed,
      ),
    ];

    final entries = await repository.recoverEntries(anonymousId: 'perfil-a');

    expect(entries, isEmpty);
  });

  test(
    'descarta un estado que referencia una rutina perteneciente a otro perfil',
    () async {
      routineRepository.routines = [
        _routine(id: 'rutina-ajena', anonymousId: 'perfil-b'),
      ];

      routineStatusRepository.records = [
        _statusRecord(
          id: 'estado-referencia-ajena',
          routineId: 'rutina-ajena',
          status: RoutineStatus.completed,
        ),
      ];

      final entries = await repository.recoverEntries(anonymousId: 'perfil-a');

      expect(entries, isEmpty);
    },
  );

  test('conserva todos los estados descriptivos permitidos', () async {
    routineRepository.routines = [
      _routine(id: 'r1'),
      _routine(id: 'r2'),
      _routine(id: 'r3'),
      _routine(id: 'r4'),
    ];

    routineStatusRepository.records = [
      _statusRecord(id: 'e1', routineId: 'r1', status: RoutineStatus.completed),
      _statusRecord(id: 'e2', routineId: 'r2', status: RoutineStatus.modified),
      _statusRecord(
        id: 'e3',
        routineId: 'r3',
        status: RoutineStatus.interrupted,
      ),
      _statusRecord(
        id: 'e4',
        routineId: 'r4',
        status: RoutineStatus.notCompleted,
      ),
    ];

    final entries = await repository.recoverEntries(anonymousId: 'perfil-a');

    expect(entries.map((entry) => entry.status), [
      RoutineStatus.completed,
      RoutineStatus.modified,
      RoutineStatus.interrupted,
      RoutineStatus.notCompleted,
    ]);
  });

  test(
    'una fuente sin estados produce una colección vacía sin error',
    () async {
      routineRepository.routines = [_routine(id: 'rutina-1')];

      final entries = await repository.recoverEntries(anonymousId: 'perfil-a');

      expect(entries, isEmpty);
    },
  );

  test('cada recuperación utiliza las fuentes actuales y no conserva conteos derivados', () async {
    routineRepository.routines = [
      _routine(id: 'rutina-1'),
      _routine(id: 'rutina-2'),
    ];

    routineStatusRepository.records = [
      _statusRecord(
        id: 'estado-1',
        routineId: 'rutina-1',
        status: RoutineStatus.completed,
      ),
    ];

    final first = await repository.recoverEntries(anonymousId: 'perfil-a');

    routineStatusRepository.records = [
      _statusRecord(
        id: 'estado-1',
        routineId: 'rutina-1',
        status: RoutineStatus.completed,
      ),
      _statusRecord(
        id: 'estado-2',
        routineId: 'rutina-2',
        status: RoutineStatus.modified,
      ),
    ];

    final second = await repository.recoverEntries(anonymousId: 'perfil-a');

    expect(first, hasLength(1));

    expect(second, hasLength(2));

    expect(routineRepository.requestedIds, ['perfil-a', 'perfil-a']);

    expect(routineStatusRepository.requestedIds, ['perfil-a', 'perfil-a']);
  });

  test(
    'rechaza identificador anónimo inválido antes de consultar las fuentes',
    () async {
      await expectLater(
        repository.recoverEntries(anonymousId: 'perfil/invalido'),
        throwsA(isA<RoutineComplianceFailure>()),
      );

      expect(routineRepository.requestedIds, isEmpty);

      expect(routineStatusRepository.requestedIds, isEmpty);
    },
  );

  test(
    'convierte errores de las fuentes en un RoutineComplianceFailure seguro',
    () async {
      routineRepository.error = Exception('Internal repository details');

      await expectLater(
        repository.recoverEntries(anonymousId: 'perfil-a'),
        throwsA(
          isA<RoutineComplianceFailure>().having(
            (failure) => failure.message,
            'message',
            'No fue posible recuperar la información '
                'para calcular el cumplimiento de rutinas. '
                'Inténtalo nuevamente.',
          ),
        ),
      );
    },
  );
}

Routine _routine({
  required String id,
  String anonymousId = 'perfil-a',
  bool isActive = true,
}) {
  return Routine(
    routineId: id,
    anonymousId: anonymousId,
    name: 'Rutina $id',
    isActive: isActive,
  );
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
    date: DateTime(2026, 9, 10),
    status: status,
    createdAt: DateTime.utc(2026, 9, 10, 12),
    updatedAt: DateTime.utc(2026, 9, 10, 12),
  );
}

class _FakeRoutineRepository implements RoutineRepository {
  List<Routine> routines = [];

  Object? error;

  final List<String> requestedIds = [];

  @override
  Future<List<Routine>> recoverRoutines({required String anonymousId}) async {
    requestedIds.add(anonymousId);

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(routines);
  }

  @override
  Future<void> createRoutine(Routine routine) async {}

  @override
  Future<void> updateRoutine(Routine routine) async {}

  @override
  Future<void> deactivateRoutine({
    required String anonymousId,
    required String routineId,
  }) async {}
}

class _FakeRoutineStatusRepository implements RoutineStatusRepository {
  List<RoutineStatusRecord> records = [];

  Object? error;

  final List<String> requestedIds = [];

  @override
  Future<List<RoutineStatusRecord>> recoverRoutineStatuses({
    required String anonymousId,
  }) async {
    requestedIds.add(anonymousId);

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(records);
  }

  @override
  Future<void> saveRoutineStatus(RoutineStatusRecord record) async {}
}
