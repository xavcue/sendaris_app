import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/history/domain/exceptions/history_failure.dart';
import 'package:sendaris/features/history/domain/models/history_record.dart';
import 'package:sendaris/features/history/domain/models/history_record_type.dart';
import 'package:sendaris/features/history/domain/repositories/history_repository.dart';
import 'package:sendaris/features/history/presentation/viewmodels/history_view_model.dart';

void main() {
  late _FakeHistoryRepository repository;

  late HistoryViewModel viewModel;

  setUp(() {
    repository = _FakeHistoryRepository();

    viewModel = HistoryViewModel(repository, anonymousId: 'perfil-a');
  });

  test('inicia sin registros y sin error', () {
    expect(viewModel.records, isEmpty);

    expect(viewModel.filteredRecords, isEmpty);

    expect(viewModel.isLoading, isFalse);

    expect(viewModel.hasLoaded, isFalse);

    expect(viewModel.errorMessage, isNull);

    expect(viewModel.hasRecords, isFalse);

    expect(viewModel.isEmpty, isFalse);

    expect(viewModel.hasActiveFilters, isFalse);

    expect(viewModel.hasFilterErrors, isFalse);
  });

  test('initialize recupera el historial del perfil seleccionado', () async {
    repository.records = [
      _record(recordId: 'registro-1', eventDate: DateTime.utc(2026, 9, 15, 12)),
    ];

    await viewModel.initialize();

    expect(repository.requestedAnonymousIds, ['perfil-a']);

    expect(viewModel.records, hasLength(1));

    expect(viewModel.records.single.recordId, 'registro-1');

    expect(viewModel.hasLoaded, isTrue);

    expect(viewModel.hasRecords, isTrue);
  });

  test('ordena los registros del más reciente al más antiguo', () async {
    repository.records = [
      _record(
        recordId: 'registro-antiguo',
        eventDate: DateTime.utc(2026, 9, 13, 9),
      ),
      _record(
        recordId: 'registro-reciente',
        eventDate: DateTime.utc(2026, 9, 15, 16, 45),
      ),
      _record(
        recordId: 'registro-medio',
        eventDate: DateTime.utc(2026, 9, 14, 13, 30),
      ),
    ];

    await viewModel.initialize();

    expect(viewModel.records.map((record) => record.recordId).toList(), [
      'registro-reciente',
      'registro-medio',
      'registro-antiguo',
    ]);
  });

  test('expone estado vacío cuando no existen registros', () async {
    await viewModel.initialize();

    expect(viewModel.hasLoaded, isTrue);

    expect(viewModel.records, isEmpty);

    expect(viewModel.hasRecords, isFalse);

    expect(viewModel.isEmpty, isTrue);

    expect(viewModel.errorMessage, isNull);
  });

  test(
    'initialize no consulta nuevamente después de una carga completada',
    () async {
      await viewModel.initialize();
      await viewModel.initialize();

      expect(repository.requestedAnonymousIds, ['perfil-a']);
    },
  );

  test(
    'reload permite actualizar el historial después de la carga inicial',
    () async {
      repository.records = [
        _record(
          recordId: 'registro-1',
          eventDate: DateTime.utc(2026, 9, 15, 12),
        ),
      ];

      await viewModel.initialize();

      repository.records = [
        _record(
          recordId: 'registro-2',
          eventDate: DateTime.utc(2026, 9, 16, 8),
        ),
        _record(
          recordId: 'registro-1',
          eventDate: DateTime.utc(2026, 9, 15, 12),
        ),
      ];

      final success = await viewModel.reload();

      expect(success, isTrue);

      expect(repository.requestedAnonymousIds, ['perfil-a', 'perfil-a']);

      expect(viewModel.records.map((record) => record.recordId).toList(), [
        'registro-2',
        'registro-1',
      ]);
    },
  );

  test('presenta un HistoryFailure como error controlado', () async {
    repository.error = const HistoryFailure(
      'No tienes autorización para consultar este historial.',
    );

    final success = await viewModel.reload();

    expect(success, isFalse);

    expect(
      viewModel.errorMessage,
      'No tienes autorización para consultar este historial.',
    );

    expect(viewModel.hasLoaded, isTrue);

    expect(viewModel.isLoading, isFalse);

    expect(viewModel.isEmpty, isFalse);
  });

  test('un error inesperado no expone detalles internos', () async {
    repository.error = Exception('Internal implementation error');

    final success = await viewModel.reload();

    expect(success, isFalse);

    expect(
      viewModel.errorMessage,
      'No fue posible cargar el historial. '
      'Inténtalo nuevamente.',
    );

    expect(
      viewModel.errorMessage,
      isNot(contains('Internal implementation error')),
    );
  });

  test('clearError elimina el mensaje de error', () async {
    repository.error = const HistoryFailure('Error controlado.');

    await viewModel.reload();

    expect(viewModel.errorMessage, 'Error controlado.');

    viewModel.clearError();

    expect(viewModel.errorMessage, isNull);
  });

  test('conserva tipos diferentes dentro del mismo historial', () async {
    repository.records = [
      _record(
        recordId: 'conducta-1',
        type: HistoryRecordType.behavior,
        eventDate: DateTime.utc(2026, 9, 15, 10),
      ),
      _record(
        recordId: 'sueno-1',
        type: HistoryRecordType.sleep,
        eventDate: DateTime.utc(2026, 9, 15, 8),
      ),
      _record(
        recordId: 'desregulacion-1',
        type: HistoryRecordType.dysregulation,
        eventDate: DateTime.utc(2026, 9, 15, 12),
      ),
    ];

    await viewModel.initialize();

    expect(viewModel.records.map((record) => record.type).toSet(), {
      HistoryRecordType.behavior,
      HistoryRecordType.sleep,
      HistoryRecordType.dysregulation,
    });
  });

  test('seleccionar fechas pendientes no modifica los registros visibles antes de aplicar', () async {
    repository.records = _filterRecords();

    await viewModel.initialize();

    viewModel.setPendingStartDate(DateTime(2026, 9, 10));

    viewModel.setPendingEndDate(DateTime(2026, 9, 15));

    expect(viewModel.hasActiveFilters, isFalse);

    expect(viewModel.filteredRecords, hasLength(5));
  });

  test('aplica un periodo válido de forma inclusiva', () async {
    repository.records = _filterRecords();

    await viewModel.initialize();

    viewModel.setPendingStartDate(DateTime(2026, 9, 10));

    viewModel.setPendingEndDate(DateTime(2026, 9, 15));

    final success = viewModel.applyFilters();

    expect(success, isTrue);

    expect(viewModel.hasPeriodFilter, isTrue);

    expect(
      viewModel.filteredRecords.map((record) => record.recordId).toList(),
      ['desregulacion-15', 'sueno-15', 'conducta-10', 'alimentacion-10'],
    );
  });

  test('aplica un único tipo de registro', () async {
    repository.records = _filterRecords();

    await viewModel.initialize();

    viewModel.togglePendingType(HistoryRecordType.sleep);

    final success = viewModel.applyFilters();

    expect(success, isTrue);

    expect(viewModel.hasTypeFilter, isTrue);

    expect(
      viewModel.filteredRecords.map((record) => record.recordId).toList(),
      ['sueno-15'],
    );
  });

  test('permite seleccionar más de un tipo de registro', () async {
    repository.records = _filterRecords();

    await viewModel.initialize();

    viewModel.togglePendingType(HistoryRecordType.behavior);

    viewModel.togglePendingType(HistoryRecordType.sleep);

    expect(viewModel.isPendingTypeSelected(HistoryRecordType.behavior), isTrue);

    expect(viewModel.isPendingTypeSelected(HistoryRecordType.sleep), isTrue);

    final success = viewModel.applyFilters();

    expect(success, isTrue);

    expect(viewModel.filteredRecords.map((record) => record.type).toSet(), {
      HistoryRecordType.behavior,
      HistoryRecordType.sleep,
    });
  });

  test('combina periodo y tipo utilizando ambos criterios', () async {
    repository.records = _filterRecords();

    await viewModel.initialize();

    viewModel.setPendingStartDate(DateTime(2026, 9, 10));

    viewModel.setPendingEndDate(DateTime(2026, 9, 15));

    viewModel.togglePendingType(HistoryRecordType.behavior);

    viewModel.togglePendingType(HistoryRecordType.dysregulation);

    final success = viewModel.applyFilters();

    expect(success, isTrue);

    expect(
      viewModel.filteredRecords.map((record) => record.recordId).toList(),
      ['desregulacion-15', 'conducta-10'],
    );
  });

  test(
    'periodo inválido muestra error y no sustituye un filtro válido existente',
    () async {
      repository.records = _filterRecords();

      await viewModel.initialize();

      viewModel.togglePendingType(HistoryRecordType.sleep);

      expect(viewModel.applyFilters(), isTrue);

      expect(viewModel.filteredRecords.single.recordId, 'sueno-15');

      viewModel.setPendingStartDate(DateTime(2026, 9, 16));

      viewModel.setPendingEndDate(DateTime(2026, 9, 15));

      final success = viewModel.applyFilters();

      expect(success, isFalse);

      expect(
        viewModel.filterErrorFor('period'),
        'La fecha inicial no puede ser posterior a la fecha final.',
      );

      expect(viewModel.filteredRecords.single.recordId, 'sueno-15');
    },
  );

  test('cambiar una selección elimina el error de filtro anterior', () async {
    viewModel.setPendingStartDate(DateTime(2026, 9, 16));

    viewModel.setPendingEndDate(DateTime(2026, 9, 15));

    expect(viewModel.applyFilters(), isFalse);

    expect(viewModel.hasFilterErrors, isTrue);

    viewModel.setPendingStartDate(DateTime(2026, 9, 10));

    expect(viewModel.hasFilterErrors, isFalse);
  });

  test('expone estado sin coincidencias cuando los filtros no encuentran registros', () async {
    repository.records = _filterRecords();

    await viewModel.initialize();

    viewModel.togglePendingType(HistoryRecordType.socialInteraction);

    expect(viewModel.applyFilters(), isTrue);

    expect(viewModel.records, isNotEmpty);

    expect(viewModel.filteredRecords, isEmpty);

    expect(viewModel.hasNoFilterResults, isTrue);

    expect(viewModel.isEmpty, isFalse);
  });

  test('clearFilters restaura la vista completa', () async {
    repository.records = _filterRecords();

    await viewModel.initialize();

    viewModel.togglePendingType(HistoryRecordType.sleep);

    viewModel.applyFilters();

    expect(viewModel.filteredRecords, hasLength(1));

    viewModel.clearFilters();

    expect(viewModel.hasActiveFilters, isFalse);

    expect(viewModel.pendingStartDate, isNull);

    expect(viewModel.pendingEndDate, isNull);

    expect(viewModel.pendingSelectedTypes, isEmpty);

    expect(viewModel.filteredRecords, hasLength(5));
  });

  test(
    'reload conserva el filtro aplicado sobre los nuevos registros recuperados',
    () async {
      repository.records = [
        _record(
          recordId: 'sueno-1',
          type: HistoryRecordType.sleep,
          eventDate: DateTime.utc(2026, 9, 15),
        ),
        _record(
          recordId: 'conducta-1',
          type: HistoryRecordType.behavior,
          eventDate: DateTime.utc(2026, 9, 14),
        ),
      ];

      await viewModel.initialize();

      viewModel.togglePendingType(HistoryRecordType.sleep);

      viewModel.applyFilters();

      repository.records = [
        _record(
          recordId: 'sueno-2',
          type: HistoryRecordType.sleep,
          eventDate: DateTime.utc(2026, 9, 16),
        ),
        _record(
          recordId: 'conducta-2',
          type: HistoryRecordType.behavior,
          eventDate: DateTime.utc(2026, 9, 16),
        ),
        _record(
          recordId: 'sueno-1',
          type: HistoryRecordType.sleep,
          eventDate: DateTime.utc(2026, 9, 15),
        ),
      ];

      await viewModel.reload();

      expect(viewModel.hasActiveFilters, isTrue);

      expect(
        viewModel.filteredRecords.map((record) => record.recordId).toList(),
        ['sueno-2', 'sueno-1'],
      );
    },
  );
}

List<HistoryRecord> _filterRecords() {
  return [
    _record(
      recordId: 'registro-antiguo',
      type: HistoryRecordType.behavior,
      eventDate: DateTime.utc(2026, 9, 5, 12),
    ),
    _record(
      recordId: 'alimentacion-10',
      type: HistoryRecordType.feeding,
      eventDate: DateTime.utc(2026, 9, 10, 8),
    ),
    _record(
      recordId: 'conducta-10',
      type: HistoryRecordType.behavior,
      eventDate: DateTime.utc(2026, 9, 10, 18),
    ),
    _record(
      recordId: 'sueno-15',
      type: HistoryRecordType.sleep,
      eventDate: DateTime.utc(2026, 9, 15, 7),
    ),
    _record(
      recordId: 'desregulacion-15',
      type: HistoryRecordType.dysregulation,
      eventDate: DateTime.utc(2026, 9, 15, 19),
    ),
  ];
}

HistoryRecord _record({
  required String recordId,
  required DateTime eventDate,
  HistoryRecordType type = HistoryRecordType.behavior,
}) {
  return HistoryRecord(
    recordId: recordId,
    anonymousId: 'perfil-a',
    type: type,
    eventDate: eventDate,
  );
}

class _FakeHistoryRepository implements HistoryRepository {
  List<HistoryRecord> records = [];

  final List<String> requestedAnonymousIds = [];

  Object? error;

  @override
  Future<List<HistoryRecord>> recoverHistory({
    required String anonymousId,
  }) async {
    requestedAnonymousIds.add(anonymousId);

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(records);
  }
}
