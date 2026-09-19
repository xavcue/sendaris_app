import '../../../behavior/domain/models/behavior_record.dart';
import '../../../behavior/domain/repositories/behavior_repository.dart';
import '../../../dysregulation/domain/models/dysregulation_record.dart';
import '../../../dysregulation/domain/repositories/dysregulation_repository.dart';
import '../../../sleep/domain/models/sleep_record.dart';
import '../../../sleep/domain/repositories/sleep_repository.dart';
import '../../../sleep/domain/services/sleep_duration_calculator.dart';
import '../../domain/exceptions/duration_failure.dart';
import '../../domain/models/duration_metric_type.dart';
import '../../domain/models/duration_observation.dart';
import '../../domain/repositories/duration_repository.dart';

class CompositeDurationRepository implements DurationRepository {
  factory CompositeDurationRepository({
    required SleepRepository sleepRepository,
    required BehaviorRepository behaviorRepository,
    required DysregulationRepository dysregulationRepository,
  }) {
    return CompositeDurationRepository._(
      sleepRepository,
      behaviorRepository,
      dysregulationRepository,
    );
  }

  CompositeDurationRepository._(
    this._sleepRepository,
    this._behaviorRepository,
    this._dysregulationRepository,
  );

  final SleepRepository _sleepRepository;

  final BehaviorRepository _behaviorRepository;

  final DysregulationRepository _dysregulationRepository;

  @override
  Future<List<DurationObservation>> recoverObservations({
    required String anonymousId,
    required DurationMetricType metricType,
  }) async {
    final normalizedAnonymousId = anonymousId.trim();

    if (normalizedAnonymousId.isEmpty || normalizedAnonymousId.contains('/')) {
      throw const DurationFailure('El perfil seleccionado no es válido.');
    }

    try {
      switch (metricType) {
        case DurationMetricType.sleep:
          final records = await _sleepRepository.recoverSleepRecords(
            anonymousId: normalizedAnonymousId,
          );

          return _mapSleepRecords(
            records: records,
            anonymousId: normalizedAnonymousId,
          );

        case DurationMetricType.behavior:
          final records = await _behaviorRepository.recoverBehaviors(
            anonymousId: normalizedAnonymousId,
          );

          return _mapBehaviorRecords(
            records: records,
            anonymousId: normalizedAnonymousId,
          );

        case DurationMetricType.dysregulation:
          final records = await _dysregulationRepository.recoverDysregulations(
            anonymousId: normalizedAnonymousId,
          );

          return _mapDysregulationRecords(
            records: records,
            anonymousId: normalizedAnonymousId,
          );
      }
    } on DurationFailure {
      rethrow;
    } catch (_) {
      throw const DurationFailure(
        'No fue posible recuperar los registros '
        'para calcular las duraciones. '
        'Inténtalo nuevamente.',
      );
    }
  }

  List<DurationObservation> _mapSleepRecords({
    required Iterable<SleepRecord> records,
    required String anonymousId,
  }) {
    return List.unmodifiable(
      records
          .where((record) => record.anonymousId == anonymousId)
          .map(
            (record) => DurationObservation(
              recordId: record.recordId,
              anonymousId: record.anonymousId,
              metricType: DurationMetricType.sleep,
              date: record.date,
              durationMinutes: _calculateSleepDuration(record),
            ),
          ),
    );
  }

  List<DurationObservation> _mapBehaviorRecords({
    required Iterable<BehaviorRecord> records,
    required String anonymousId,
  }) {
    return List.unmodifiable(
      records
          .where((record) => record.anonymousId == anonymousId)
          .map(
            (record) => DurationObservation(
              recordId: record.recordId,
              anonymousId: record.anonymousId,
              metricType: DurationMetricType.behavior,
              date: record.date,
              durationMinutes: record.durationMinutes,
            ),
          ),
    );
  }

  List<DurationObservation> _mapDysregulationRecords({
    required Iterable<DysregulationRecord> records,
    required String anonymousId,
  }) {
    return List.unmodifiable(
      records
          .where((record) => record.anonymousId == anonymousId)
          .map(
            (record) => DurationObservation(
              recordId: record.recordId,
              anonymousId: record.anonymousId,
              metricType: DurationMetricType.dysregulation,
              date: record.date,
              durationMinutes: record.durationMinutes,
            ),
          ),
    );
  }

  int? _calculateSleepDuration(SleepRecord record) {
    try {
      return SleepDurationCalculator.calculate(
        startTime: record.startTime,
        endTime: record.endTime,
      );
    } on ArgumentError {
      return null;
    }
  }
}
