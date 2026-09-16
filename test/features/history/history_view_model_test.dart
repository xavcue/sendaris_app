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

    expect(viewModel.isLoading, isFalse);

    expect(viewModel.hasLoaded, isFalse);

    expect(viewModel.errorMessage, isNull);

    expect(viewModel.hasRecords, isFalse);

    expect(viewModel.isEmpty, isFalse);
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
