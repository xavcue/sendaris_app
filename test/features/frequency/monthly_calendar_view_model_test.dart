import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/frequency/data/repositories/composite_monthly_calendar_repository.dart';
import 'package:sendaris/features/frequency/domain/models/monthly_calendar_record.dart';
import 'package:sendaris/features/frequency/presentation/viewmodels/monthly_calendar_view_model.dart';

class _FakeCalendarRepository implements MonthlyCalendarRepository {
  _FakeCalendarRepository({
    this.records = const [],
    this.error,
    this.returnedAnonymousId,
  });

  List<MonthlyCalendarRecord> records;
  Object? error;
  String? returnedAnonymousId;

  final List<String> requests = [];

  @override
  Future<MonthlyCalendarIndex> recover({required String anonymousId}) async {
    requests.add(anonymousId);

    if (error != null) {
      throw error!;
    }

    return MonthlyCalendarIndex(
      anonymousId: returnedAnonymousId ?? anonymousId,
      records: records,
    );
  }
}

class _DeferredCalendarRepository implements MonthlyCalendarRepository {
  final List<Completer<MonthlyCalendarIndex>> pending = [];

  @override
  Future<MonthlyCalendarIndex> recover({required String anonymousId}) {
    final completer = Completer<MonthlyCalendarIndex>();

    pending.add(completer);

    return completer.future;
  }

  void complete(
    int request, {
    required String anonymousId,
    required List<MonthlyCalendarRecord> records,
  }) {
    pending[request].complete(
      MonthlyCalendarIndex(anonymousId: anonymousId, records: records),
    );
  }
}

MonthlyCalendarRecord _record({
  required String id,
  required int day,
  required CalendarRecordType type,
  String anonymousId = 'perfil-a',
  int month = 10,
}) {
  return MonthlyCalendarRecord(
    id: id,
    anonymousId: anonymousId,
    date: DateTime(2026, month, day),
    type: type,
    description: type.label,
  );
}

MonthlyCalendarViewModel _createViewModel(
  MonthlyCalendarRepository repository, {
  String anonymousId = 'perfil-a',
}) {
  return MonthlyCalendarViewModel(
    repository,
    anonymousId: anonymousId,
    clock: () => DateTime(2026, 10, 15, 14, 30),
  );
}

void main() {
  group('MonthlyCalendarViewModel', () {
    test('inicializa el mes actual con los siete tipos activos', () {
      final repository = _FakeCalendarRepository();

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      expect(viewModel.visibleMonth, DateTime(2026, 10));

      expect(viewModel.selectedDate, DateTime(2026, 10, 15));

      expect(viewModel.selectedTypes, containsAll(CalendarRecordType.values));

      expect(viewModel.filtersExpanded, isFalse);
      expect(viewModel.hasDateFilter, isFalse);

      expect(viewModel.index, isNull);
      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);

      expect(repository.requests, isEmpty);

      expect(() => viewModel.selectedTypes.clear(), throwsUnsupportedError);
    });

    test('recupera los siete tipos y mantiene el aislamiento', () async {
      final repository = _FakeCalendarRepository(
        records: [
          for (var i = 0; i < CalendarRecordType.values.length; i++)
            _record(
              id: 'registro-$i',
              day: 15,
              type: CalendarRecordType.values[i],
            ),
          _record(id: 'registro-0', day: 15, type: CalendarRecordType.behavior),
          _record(
            id: 'otro-perfil',
            day: 15,
            type: CalendarRecordType.sleep,
            anonymousId: 'perfil-b',
          ),
        ],
      );

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(repository.requests, ['perfil-a']);

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.errorMessage, isNull);

      expect(viewModel.monthCount, 7);

      expect(viewModel.selectedDayRecords, hasLength(7));

      expect(
        viewModel.selectedDayRecords.map((item) => item.type).toSet(),
        CalendarRecordType.values.toSet(),
      );
    });

    test('cambia de mes sin volver a consultar el repositorio', () async {
      final repository = _FakeCalendarRepository(
        records: [
          _record(id: 'octubre', day: 15, type: CalendarRecordType.behavior),
          _record(
            id: 'septiembre',
            day: 10,
            month: 9,
            type: CalendarRecordType.sleep,
          ),
        ],
      );

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.monthCount, 1);

      viewModel.changeMonth(-1);

      expect(viewModel.visibleMonth, DateTime(2026, 9));

      expect(viewModel.selectedDate, DateTime(2026, 9, 1));

      expect(viewModel.monthCount, 1);

      viewModel.changeMonth(1);

      expect(viewModel.visibleMonth, DateTime(2026, 10));

      expect(viewModel.monthCount, 1);

      expect(repository.requests, hasLength(1));
    });

    test('selecciona una fecha y muestra sus registros', () async {
      final repository = _FakeCalendarRepository(
        records: [
          _record(id: 'conducta', day: 14, type: CalendarRecordType.behavior),
          _record(id: 'sueno', day: 15, type: CalendarRecordType.sleep),
        ],
      );

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.selectedDayRecords, hasLength(1));

      expect(
        viewModel.selectedDayRecords.single.type,
        CalendarRecordType.sleep,
      );

      viewModel.selectDate(DateTime(2026, 10, 14, 20));

      expect(viewModel.selectedDate, DateTime(2026, 10, 14));

      expect(
        viewModel.selectedDayRecords.single.type,
        CalendarRecordType.behavior,
      );

      expect(repository.requests, hasLength(1));
    });

    test('filtra por tipos sin alterar los registros', () async {
      final repository = _FakeCalendarRepository(
        records: [
          _record(id: 'conducta', day: 15, type: CalendarRecordType.behavior),
          _record(id: 'sueno', day: 15, type: CalendarRecordType.sleep),
          _record(
            id: 'rutina',
            day: 15,
            type: CalendarRecordType.routineStatus,
          ),
        ],
      );

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.monthCount, 3);

      viewModel.setTypeSelected(CalendarRecordType.behavior, selected: false);

      expect(viewModel.monthCount, 2);

      viewModel.setTypeSelected(CalendarRecordType.sleep, selected: false);

      expect(viewModel.monthCount, 1);

      expect(
        viewModel.selectedDayRecords.single.type,
        CalendarRecordType.routineStatus,
      );

      viewModel.selectAllTypes();

      expect(viewModel.monthCount, 3);
      expect(repository.requests, hasLength(1));
    });

    test('el filtro de fechas incluye los extremos', () async {
      final repository = _FakeCalendarRepository(
        records: [
          _record(id: 'uno', day: 1, type: CalendarRecordType.behavior),
          _record(id: 'doce', day: 12, type: CalendarRecordType.sleep),
          _record(id: 'quince', day: 15, type: CalendarRecordType.feeding),
          _record(id: 'veinte', day: 20, type: CalendarRecordType.behavior),
        ],
      );

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.monthCount, 4);

      viewModel.selectStartDate(DateTime(2026, 10, 12));

      expect(viewModel.monthCount, 3);

      viewModel.selectEndDate(DateTime(2026, 10, 15));

      expect(viewModel.monthCount, 2);

      expect(viewModel.countForDay(DateTime(2026, 10, 12)), 1);

      expect(viewModel.countForDay(DateTime(2026, 10, 15)), 1);

      expect(viewModel.countForDay(DateTime(2026, 10, 20)), 0);

      viewModel.clearDateFilters();

      expect(viewModel.hasDateFilter, isFalse);
      expect(viewModel.monthCount, 4);

      expect(repository.requests, hasLength(1));
    });

    test('mantiene un intervalo válido al cambiar fechas', () {
      final repository = _FakeCalendarRepository();

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      viewModel.selectEndDate(DateTime(2026, 10, 10));

      viewModel.selectStartDate(DateTime(2026, 10, 15));

      expect(viewModel.startDate, DateTime(2026, 10, 15));

      expect(viewModel.endDate, DateTime(2026, 10, 15));

      viewModel.selectEndDate(DateTime(2026, 10, 12));

      expect(viewModel.startDate, DateTime(2026, 10, 12));

      expect(viewModel.endDate, DateTime(2026, 10, 12));
    });

    test('expande y contrae los filtros', () {
      final repository = _FakeCalendarRepository();

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      expect(viewModel.filtersExpanded, isFalse);

      viewModel.toggleFilters();

      expect(viewModel.filtersExpanded, isTrue);

      viewModel.toggleFilters();

      expect(viewModel.filtersExpanded, isFalse);
    });

    test('muestra un error controlado y permite reintentar', () async {
      final repository = _FakeCalendarRepository(
        error: StateError('Error de red'),
      );

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.index, isNull);
      expect(viewModel.errorMessage, isNotNull);

      repository.error = null;

      repository.records = [
        _record(id: 'recuperado', day: 15, type: CalendarRecordType.behavior),
      ];

      await viewModel.load();

      expect(viewModel.errorMessage, isNull);
      expect(viewModel.monthCount, 1);

      expect(repository.requests, hasLength(2));
    });

    test('rechaza resultados de otro seguimiento', () async {
      final repository = _FakeCalendarRepository(
        returnedAnonymousId: 'perfil-b',
      );

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      await viewModel.load();

      expect(viewModel.index, isNull);
      expect(viewModel.monthCount, 0);
      expect(viewModel.errorMessage, isNotNull);
    });

    test('descarta una respuesta anterior tras actualizar', () async {
      final repository = _DeferredCalendarRepository();

      final viewModel = _createViewModel(repository);

      addTearDown(viewModel.dispose);

      final firstRequest = viewModel.load();

      expect(viewModel.isLoading, isTrue);

      final secondRequest = viewModel.load();

      expect(repository.pending, hasLength(2));

      repository.complete(
        1,
        anonymousId: 'perfil-a',
        records: [
          _record(id: 'nuevo', day: 15, type: CalendarRecordType.sleep),
        ],
      );

      await secondRequest;

      expect(viewModel.isLoading, isFalse);
      expect(viewModel.monthCount, 1);

      repository.complete(
        0,
        anonymousId: 'perfil-a',
        records: [
          for (var i = 0; i < 5; i++)
            _record(
              id: 'antiguo-$i',
              day: 15,
              type: CalendarRecordType.behavior,
            ),
        ],
      );

      await firstRequest;

      expect(viewModel.monthCount, 1);

      expect(viewModel.selectedDayRecords.single.id, 'nuevo');
    });

    test('ignora una respuesta posterior a dispose', () async {
      final repository = _DeferredCalendarRepository();

      final viewModel = _createViewModel(repository);

      final request = viewModel.load();

      expect(viewModel.isLoading, isTrue);

      viewModel.dispose();

      expect(viewModel.isDisposed, isTrue);

      repository.complete(
        0,
        anonymousId: 'perfil-a',
        records: [
          _record(id: 'tardio', day: 15, type: CalendarRecordType.sleep),
        ],
      );

      await request;

      expect(viewModel.index, isNull);
      expect(viewModel.monthCount, 0);
    });
  });
}
