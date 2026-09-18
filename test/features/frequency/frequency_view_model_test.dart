import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/frequency/domain/exceptions/frequency_failure.dart';
import 'package:sendaris/features/frequency/domain/models/frequency_event.dart';
import 'package:sendaris/features/frequency/domain/models/frequency_metric_type.dart';
import 'package:sendaris/features/frequency/domain/repositories/frequency_repository.dart';
import 'package:sendaris/features/frequency/presentation/viewmodels/frequency_view_model.dart';

void main() {
  late _FakeFrequencyRepository repository;

  late FrequencyViewModel viewModel;

  setUp(() {
    repository = _FakeFrequencyRepository();

    viewModel = FrequencyViewModel(repository, anonymousId: 'perfil-a');
  });

  test('inicia sin criterios seleccionados ni resultado', () {
    expect(viewModel.selectedMetricType, isNull);

    expect(viewModel.startDate, isNull);

    expect(viewModel.endDate, isNull);

    expect(viewModel.selectedCategoryCode, isNull);

    expect(viewModel.hasResult, isFalse);

    expect(viewModel.isCalculating, isFalse);

    expect(viewModel.errorMessage, isNull);

    expect(viewModel.hasFieldErrors, isFalse);
  });

  test('seleccionar una métrica expone sus categorías aplicables', () {
    viewModel.setMetricType(FrequencyMetricType.behavior);

    expect(viewModel.selectedMetricType, FrequencyMetricType.behavior);

    expect(viewModel.metricSupportsCategories, isTrue);

    expect(viewModel.metricRequiresCategory, isTrue);

    expect(viewModel.availableCategories, hasLength(4));

    expect(
      viewModel.availableCategories.map((option) => option.code),
      contains('conducta_repetitiva'),
    );
  });

  test('normaliza las fechas seleccionadas eliminando la hora', () {
    viewModel.setStartDate(DateTime(2026, 9, 1, 18, 30));

    viewModel.setEndDate(DateTime(2026, 9, 15, 23, 59));

    expect(viewModel.startDate, DateTime(2026, 9, 1));

    expect(viewModel.endDate, DateTime(2026, 9, 15));
  });

  test('seleccionar categoría conserva código y etiqueta', () {
    viewModel.setMetricType(FrequencyMetricType.feeding);

    viewModel.setCategoryCode('almuerzo');

    expect(viewModel.selectedCategoryCode, 'almuerzo');

    expect(viewModel.selectedCategoryLabel, 'Almuerzo');
  });

  test('calculate exige seleccionar un tipo de frecuencia', () async {
    final success = await viewModel.calculate();

    expect(success, isFalse);

    expect(
      viewModel.errorFor('metricType'),
      'Selecciona un tipo de frecuencia.',
    );

    expect(repository.requests, isEmpty);
  });

  test(
    'calculate exige un periodo completo antes de consultar la fuente',
    () async {
      viewModel.setMetricType(FrequencyMetricType.dysregulation);

      final success = await viewModel.calculate();

      expect(success, isFalse);

      expect(
        viewModel.errorFor('period'),
        'Selecciona una fecha inicial y una fecha final.',
      );

      expect(repository.requests, isEmpty);
    },
  );

  test('calculate exige categoría cuando la métrica la requiere', () async {
    viewModel.setMetricType(FrequencyMetricType.behavior);

    viewModel.setStartDate(DateTime(2026, 9, 1));

    viewModel.setEndDate(DateTime(2026, 9, 15));

    final success = await viewModel.calculate();

    expect(success, isFalse);

    expect(
      viewModel.errorFor('category'),
      'Selecciona una categoría aplicable.',
    );

    expect(repository.requests, isEmpty);
  });

  test(
    'calcula exactamente la frecuencia de conducta para periodo y categoría',
    () async {
      repository.events = [
        _event(
          id: 'conducta-1',
          metricType: FrequencyMetricType.behavior,
          date: DateTime(2026, 9, 5),
          categoryCode: 'conducta_repetitiva',
        ),
        _event(
          id: 'conducta-2',
          metricType: FrequencyMetricType.behavior,
          date: DateTime(2026, 9, 10),
          categoryCode: 'conducta_repetitiva',
        ),
        _event(
          id: 'otra-categoria',
          metricType: FrequencyMetricType.behavior,
          date: DateTime(2026, 9, 10),
          categoryCode: 'iniciativa_social',
        ),
        _event(
          id: 'fuera-periodo',
          metricType: FrequencyMetricType.behavior,
          date: DateTime(2026, 9, 20),
          categoryCode: 'conducta_repetitiva',
        ),
      ];

      viewModel.setMetricType(FrequencyMetricType.behavior);

      viewModel.setStartDate(DateTime(2026, 9, 1));

      viewModel.setEndDate(DateTime(2026, 9, 15));

      viewModel.setCategoryCode('conducta_repetitiva');

      final success = await viewModel.calculate();

      expect(success, isTrue);

      expect(viewModel.hasResult, isTrue);

      expect(viewModel.resultCount, 2);

      expect(repository.requests, [
        _FrequencyRequest(
          anonymousId: 'perfil-a',
          metricType: FrequencyMetricType.behavior,
        ),
      ]);
    },
  );

  test(
    'un periodo sin coincidencias produce frecuencia cero sin error',
    () async {
      viewModel.setMetricType(FrequencyMetricType.dysregulation);

      viewModel.setStartDate(DateTime(2026, 9, 1));

      viewModel.setEndDate(DateTime(2026, 9, 15));

      final success = await viewModel.calculate();

      expect(success, isTrue);

      expect(viewModel.resultCount, 0);

      expect(viewModel.isZeroResult, isTrue);

      expect(viewModel.errorMessage, isNull);
    },
  );

  test('desregulación se calcula sin categoría', () async {
    repository.events = [
      _event(
        id: 'd1',
        metricType: FrequencyMetricType.dysregulation,
        date: DateTime(2026, 9, 4),
      ),
      _event(
        id: 'd2',
        metricType: FrequencyMetricType.dysregulation,
        date: DateTime(2026, 9, 7),
      ),
    ];

    viewModel.setMetricType(FrequencyMetricType.dysregulation);

    viewModel.setStartDate(DateTime(2026, 9, 1));

    viewModel.setEndDate(DateTime(2026, 9, 15));

    final success = await viewModel.calculate();

    expect(success, isTrue);

    expect(viewModel.resultCount, 2);

    expect(viewModel.metricSupportsCategories, isFalse);
  });

  test(
    'situaciones atípicas pueden calcularse sin categoría específica',
    () async {
      repository.events = [
        _event(
          id: 'a1',
          metricType: FrequencyMetricType.atypicalSituation,
          date: DateTime(2026, 9, 4),
          categoryCode: 'cambio_entorno',
        ),
        _event(
          id: 'a2',
          metricType: FrequencyMetricType.atypicalSituation,
          date: DateTime(2026, 9, 5),
          categoryCode: 'evento_inesperado',
        ),
      ];

      viewModel.setMetricType(FrequencyMetricType.atypicalSituation);

      viewModel.setStartDate(DateTime(2026, 9, 1));

      viewModel.setEndDate(DateTime(2026, 9, 15));

      final success = await viewModel.calculate();

      expect(success, isTrue);

      expect(viewModel.resultCount, 2);

      expect(viewModel.metricRequiresCategory, isFalse);
    },
  );

  test('un FrequencyFailure se presenta como error controlado', () async {
    repository.error = const FrequencyFailure(
      'No fue posible recuperar los registros '
      'para calcular la frecuencia. '
      'Inténtalo nuevamente.',
    );

    viewModel.setMetricType(FrequencyMetricType.dysregulation);

    viewModel.setStartDate(DateTime(2026, 9, 1));

    viewModel.setEndDate(DateTime(2026, 9, 15));

    final success = await viewModel.calculate();

    expect(success, isFalse);

    expect(
      viewModel.errorMessage,
      'No fue posible recuperar los registros '
      'para calcular la frecuencia. '
      'Inténtalo nuevamente.',
    );

    expect(viewModel.hasResult, isFalse);
  });

  test('un error inesperado no expone detalles internos', () async {
    repository.error = Exception('Internal calculation details');

    viewModel.setMetricType(FrequencyMetricType.dysregulation);

    viewModel.setStartDate(DateTime(2026, 9, 1));

    viewModel.setEndDate(DateTime(2026, 9, 15));

    final success = await viewModel.calculate();

    expect(success, isFalse);

    expect(
      viewModel.errorMessage,
      'No fue posible calcular la frecuencia. '
      'Inténtalo nuevamente.',
    );

    expect(
      viewModel.errorMessage,
      isNot(contains('Internal calculation details')),
    );
  });

  test(
    'cada cálculo recupera nuevamente los registros fuente actuales',
    () async {
      viewModel.setMetricType(FrequencyMetricType.dysregulation);

      viewModel.setStartDate(DateTime(2026, 9, 1));

      viewModel.setEndDate(DateTime(2026, 9, 15));

      repository.events = [
        _event(
          id: 'd1',
          metricType: FrequencyMetricType.dysregulation,
          date: DateTime(2026, 9, 5),
        ),
      ];

      expect(await viewModel.calculate(), isTrue);

      expect(viewModel.resultCount, 1);

      repository.events = [
        _event(
          id: 'd1',
          metricType: FrequencyMetricType.dysregulation,
          date: DateTime(2026, 9, 5),
        ),
        _event(
          id: 'd2',
          metricType: FrequencyMetricType.dysregulation,
          date: DateTime(2026, 9, 6),
        ),
      ];

      expect(await viewModel.calculate(), isTrue);

      expect(viewModel.resultCount, 2);

      expect(repository.requests, hasLength(2));
    },
  );

  test('cambiar criterios invalida un resultado anterior', () async {
    repository.events = [
      _event(
        id: 'd1',
        metricType: FrequencyMetricType.dysregulation,
        date: DateTime(2026, 9, 5),
      ),
    ];

    viewModel.setMetricType(FrequencyMetricType.dysregulation);

    viewModel.setStartDate(DateTime(2026, 9, 1));

    viewModel.setEndDate(DateTime(2026, 9, 15));

    await viewModel.calculate();

    expect(viewModel.hasResult, isTrue);

    viewModel.setEndDate(DateTime(2026, 9, 10));

    expect(viewModel.hasResult, isFalse);

    expect(viewModel.resultCount, isNull);
  });

  test('cambiar el tipo de frecuencia limpia una categoría anterior', () {
    viewModel.setMetricType(FrequencyMetricType.behavior);

    viewModel.setCategoryCode('conducta_repetitiva');

    expect(viewModel.selectedCategoryCode, 'conducta_repetitiva');

    viewModel.setMetricType(FrequencyMetricType.dysregulation);

    expect(viewModel.selectedCategoryCode, isNull);

    expect(viewModel.availableCategories, isEmpty);
  });
}

FrequencyEvent _event({
  required String id,
  required FrequencyMetricType metricType,
  required DateTime date,
  String anonymousId = 'perfil-a',
  String? categoryCode,
}) {
  return FrequencyEvent(
    recordId: id,
    anonymousId: anonymousId,
    metricType: metricType,
    date: date,
    categoryCode: categoryCode,
  );
}

class _FakeFrequencyRepository implements FrequencyRepository {
  List<FrequencyEvent> events = [];

  Object? error;

  final List<_FrequencyRequest> requests = [];

  @override
  Future<List<FrequencyEvent>> recoverEvents({
    required String anonymousId,
    required FrequencyMetricType metricType,
  }) async {
    requests.add(
      _FrequencyRequest(anonymousId: anonymousId, metricType: metricType),
    );

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(events);
  }
}

class _FrequencyRequest {
  const _FrequencyRequest({
    required this.anonymousId,
    required this.metricType,
  });

  final String anonymousId;

  final FrequencyMetricType metricType;

  @override
  bool operator ==(Object other) {
    return other is _FrequencyRequest &&
        other.anonymousId == anonymousId &&
        other.metricType == metricType;
  }

  @override
  int get hashCode => Object.hash(anonymousId, metricType);
}
