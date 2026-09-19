import 'package:flutter_test/flutter_test.dart';
import 'package:sendaris/features/duration/domain/exceptions/duration_failure.dart';
import 'package:sendaris/features/duration/domain/models/duration_metric_type.dart';
import 'package:sendaris/features/duration/domain/models/duration_observation.dart';
import 'package:sendaris/features/duration/domain/repositories/duration_repository.dart';
import 'package:sendaris/features/duration/presentation/viewmodels/duration_view_model.dart';

void main() {
  late _FakeDurationRepository repository;

  late DurationViewModel viewModel;

  setUp(() {
    repository = _FakeDurationRepository();

    viewModel = DurationViewModel(repository, anonymousId: 'perfil-a');
  });

  test('inicia sin criterios seleccionados ni resultado', () {
    expect(viewModel.selectedMetricType, isNull);

    expect(viewModel.startDate, isNull);

    expect(viewModel.endDate, isNull);

    expect(viewModel.hasResult, isFalse);

    expect(viewModel.averageMinutes, isNull);

    expect(viewModel.validRecordCount, 0);

    expect(viewModel.validObservations, isEmpty);

    expect(viewModel.isCalculating, isFalse);

    expect(viewModel.errorMessage, isNull);

    expect(viewModel.hasFieldErrors, isFalse);
  });

  test('selecciona únicamente un tipo de duración aplicable', () {
    viewModel.setMetricType(DurationMetricType.sleep);

    expect(viewModel.selectedMetricType, DurationMetricType.sleep);

    expect(viewModel.hasResult, isFalse);
  });

  test('normaliza las fechas seleccionadas eliminando la hora', () {
    viewModel.setStartDate(DateTime(2026, 9, 1, 18, 30));

    viewModel.setEndDate(DateTime(2026, 9, 15, 23, 59));

    expect(viewModel.startDate, DateTime(2026, 9, 1));

    expect(viewModel.endDate, DateTime(2026, 9, 15));
  });

  test('calculate exige seleccionar un tipo de duración', () async {
    final success = await viewModel.calculate();

    expect(success, isFalse);

    expect(viewModel.errorFor('metricType'), 'Selecciona un tipo de duración.');

    expect(repository.requests, isEmpty);
  });

  test(
    'calculate exige un periodo completo antes de consultar la fuente',
    () async {
      viewModel.setMetricType(DurationMetricType.sleep);

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
    'un periodo invertido se rechaza antes de consultar la fuente',
    () async {
      viewModel.setMetricType(DurationMetricType.behavior);

      viewModel.setStartDate(DateTime(2026, 9, 20));

      viewModel.setEndDate(DateTime(2026, 9, 10));

      final success = await viewModel.calculate();

      expect(success, isFalse);

      expect(
        viewModel.errorFor('period'),
        'La fecha inicial no puede ser posterior a la fecha final.',
      );

      expect(repository.requests, isEmpty);
    },
  );

  test('calcula el promedio exacto de sueño y conserva las duraciones individuales', () async {
    repository.observations = [
      _observation(
        id: 'sueno-1',
        metricType: DurationMetricType.sleep,
        date: DateTime(2026, 9, 5),
        durationMinutes: 420,
      ),
      _observation(
        id: 'sueno-2',
        metricType: DurationMetricType.sleep,
        date: DateTime(2026, 9, 6),
        durationMinutes: 480,
      ),
      _observation(
        id: 'sueno-3',
        metricType: DurationMetricType.sleep,
        date: DateTime(2026, 9, 7),
        durationMinutes: 450,
      ),
    ];

    _selectValidPeriod(viewModel, DurationMetricType.sleep);

    final success = await viewModel.calculate();

    expect(success, isTrue);

    expect(viewModel.hasResult, isTrue);

    expect(viewModel.hasSufficientData, isTrue);

    expect(viewModel.hasInsufficientData, isFalse);

    expect(viewModel.validRecordCount, 3);

    expect(viewModel.averageMinutes, 450);

    expect(
      viewModel.validObservations
          .map((observation) => observation.durationMinutes)
          .toList(),
      [420, 480, 450],
    );
  });

  test('conducta excluye duraciones incompletas del promedio', () async {
    repository.observations = [
      _observation(
        id: 'conducta-1',
        metricType: DurationMetricType.behavior,
        date: DateTime(2026, 9, 5),
        durationMinutes: 10,
      ),
      _observation(
        id: 'conducta-2',
        metricType: DurationMetricType.behavior,
        date: DateTime(2026, 9, 6),
        durationMinutes: null,
      ),
      _observation(
        id: 'conducta-3',
        metricType: DurationMetricType.behavior,
        date: DateTime(2026, 9, 7),
        durationMinutes: 30,
      ),
    ];

    _selectValidPeriod(viewModel, DurationMetricType.behavior);

    expect(await viewModel.calculate(), isTrue);

    expect(viewModel.validRecordCount, 2);

    expect(viewModel.averageMinutes, 20);
  });

  test('conducta excluye duraciones cero o negativas', () async {
    repository.observations = [
      _observation(
        id: 'conducta-cero',
        metricType: DurationMetricType.behavior,
        date: DateTime(2026, 9, 5),
        durationMinutes: 0,
      ),
      _observation(
        id: 'conducta-negativa',
        metricType: DurationMetricType.behavior,
        date: DateTime(2026, 9, 6),
        durationMinutes: -5,
      ),
    ];

    _selectValidPeriod(viewModel, DurationMetricType.behavior);

    expect(await viewModel.calculate(), isTrue);

    expect(viewModel.validRecordCount, 0);

    expect(viewModel.averageMinutes, isNull);

    expect(viewModel.hasInsufficientData, isTrue);
  });

  test(
    'desregulación respeta la duración cero permitida por el contrato vigente',
    () async {
      repository.observations = [
        _observation(
          id: 'desregulacion-1',
          metricType: DurationMetricType.dysregulation,
          date: DateTime(2026, 9, 5),
          durationMinutes: 0,
        ),
        _observation(
          id: 'desregulacion-2',
          metricType: DurationMetricType.dysregulation,
          date: DateTime(2026, 9, 6),
          durationMinutes: 10,
        ),
      ];

      _selectValidPeriod(viewModel, DurationMetricType.dysregulation);

      expect(await viewModel.calculate(), isTrue);

      expect(viewModel.validRecordCount, 2);

      expect(viewModel.averageMinutes, 5);
    },
  );

  test(
    'sin datos temporales suficientes conserva resultado sin inventar promedio',
    () async {
      repository.observations = [
        _observation(
          id: 'conducta-sin-duracion',
          metricType: DurationMetricType.behavior,
          date: DateTime(2026, 9, 5),
          durationMinutes: null,
        ),
      ];

      _selectValidPeriod(viewModel, DurationMetricType.behavior);

      final success = await viewModel.calculate();

      expect(success, isTrue);

      expect(viewModel.hasResult, isTrue);

      expect(viewModel.hasSufficientData, isFalse);

      expect(viewModel.hasInsufficientData, isTrue);

      expect(viewModel.averageMinutes, isNull);

      expect(viewModel.validObservations, isEmpty);
    },
  );

  test(
    'solo conserva registros válidos del perfil y periodo seleccionado',
    () async {
      repository.observations = [
        _observation(
          id: 'valido',
          metricType: DurationMetricType.sleep,
          date: DateTime(2026, 9, 5),
          durationMinutes: 420,
        ),
        _observation(
          id: 'otro-perfil',
          anonymousId: 'perfil-b',
          metricType: DurationMetricType.sleep,
          date: DateTime(2026, 9, 5),
          durationMinutes: 600,
        ),
        _observation(
          id: 'fuera-periodo',
          metricType: DurationMetricType.sleep,
          date: DateTime(2026, 9, 20),
          durationMinutes: 500,
        ),
      ];

      _selectValidPeriod(viewModel, DurationMetricType.sleep);

      expect(await viewModel.calculate(), isTrue);

      expect(viewModel.validRecordCount, 1);

      expect(viewModel.validObservations.single.recordId, 'valido');

      expect(viewModel.averageMinutes, 420);
    },
  );

  test('un identificador anónimo inválido se presenta como error controlado sin consultar la fuente', () async {
    final invalidViewModel = DurationViewModel(
      repository,
      anonymousId: 'perfil/invalido',
    );

    _selectValidPeriod(invalidViewModel, DurationMetricType.sleep);

    final success = await invalidViewModel.calculate();

    expect(success, isFalse);

    expect(invalidViewModel.errorMessage, 'El perfil activo no es válido.');

    expect(repository.requests, isEmpty);

    invalidViewModel.dispose();
  });

  test('un DurationFailure se presenta como error seguro', () async {
    repository.error = const DurationFailure(
      'No fue posible recuperar los registros '
      'para calcular las duraciones. '
      'Inténtalo nuevamente.',
    );

    _selectValidPeriod(viewModel, DurationMetricType.sleep);

    final success = await viewModel.calculate();

    expect(success, isFalse);

    expect(
      viewModel.errorMessage,
      'No fue posible recuperar los registros '
      'para calcular las duraciones. '
      'Inténtalo nuevamente.',
    );

    expect(viewModel.hasResult, isFalse);
  });

  test('un error inesperado no expone detalles internos', () async {
    repository.error = Exception('Internal calculation details');

    _selectValidPeriod(viewModel, DurationMetricType.sleep);

    final success = await viewModel.calculate();

    expect(success, isFalse);

    expect(
      viewModel.errorMessage,
      'No fue posible calcular las duraciones. '
      'Inténtalo nuevamente.',
    );

    expect(
      viewModel.errorMessage,
      isNot(contains('Internal calculation details')),
    );
  });

  test(
    'cada cálculo vuelve a recuperar los registros fuente actuales',
    () async {
      _selectValidPeriod(viewModel, DurationMetricType.behavior);

      repository.observations = [
        _observation(
          id: 'conducta-1',
          metricType: DurationMetricType.behavior,
          date: DateTime(2026, 9, 5),
          durationMinutes: 10,
        ),
      ];

      expect(await viewModel.calculate(), isTrue);

      expect(viewModel.averageMinutes, 10);

      repository.observations = [
        _observation(
          id: 'conducta-1',
          metricType: DurationMetricType.behavior,
          date: DateTime(2026, 9, 5),
          durationMinutes: 10,
        ),
        _observation(
          id: 'conducta-2',
          metricType: DurationMetricType.behavior,
          date: DateTime(2026, 9, 6),
          durationMinutes: 30,
        ),
      ];

      expect(await viewModel.calculate(), isTrue);

      expect(viewModel.averageMinutes, 20);

      expect(repository.requests, hasLength(2));
    },
  );

  test('cambiar criterios invalida un resultado anterior', () async {
    repository.observations = [
      _observation(
        id: 'sueno-1',
        metricType: DurationMetricType.sleep,
        date: DateTime(2026, 9, 5),
        durationMinutes: 420,
      ),
    ];

    _selectValidPeriod(viewModel, DurationMetricType.sleep);

    await viewModel.calculate();

    expect(viewModel.hasResult, isTrue);

    viewModel.setEndDate(DateTime(2026, 9, 10));

    expect(viewModel.hasResult, isFalse);

    expect(viewModel.averageMinutes, isNull);

    expect(viewModel.validObservations, isEmpty);
  });
}

void _selectValidPeriod(
  DurationViewModel viewModel,
  DurationMetricType metricType,
) {
  viewModel.setMetricType(metricType);

  viewModel.setStartDate(DateTime(2026, 9, 1));

  viewModel.setEndDate(DateTime(2026, 9, 15));
}

DurationObservation _observation({
  required String id,
  required DurationMetricType metricType,
  required DateTime date,
  required int? durationMinutes,
  String anonymousId = 'perfil-a',
}) {
  return DurationObservation(
    recordId: id,
    anonymousId: anonymousId,
    metricType: metricType,
    date: date,
    durationMinutes: durationMinutes,
  );
}

class _FakeDurationRepository implements DurationRepository {
  List<DurationObservation> observations = [];

  Object? error;

  final List<_DurationRequest> requests = [];

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    requests.add(
      _DurationRequest(anonymousId: anonymousId, metricType: metricType),
    );

    final currentError = error;

    if (currentError != null) {
      throw currentError;
    }

    return List.unmodifiable(observations);
  }
}

class _DurationRequest {
  const _DurationRequest({required this.anonymousId, required this.metricType});

  final String anonymousId;

  final DurationMetricType metricType;
}
