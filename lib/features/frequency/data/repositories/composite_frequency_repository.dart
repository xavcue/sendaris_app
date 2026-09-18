import '../../../atypical_situation/domain/models/atypical_situation_record.dart';
import '../../../atypical_situation/domain/repositories/atypical_situation_repository.dart';
import '../../../behavior/domain/models/behavior_record.dart';
import '../../../behavior/domain/repositories/behavior_repository.dart';
import '../../../dysregulation/domain/models/dysregulation_record.dart';
import '../../../dysregulation/domain/repositories/dysregulation_repository.dart';
import '../../../feeding/domain/models/feeding_record.dart';
import '../../../feeding/domain/repositories/feeding_repository.dart';
import '../../../social_interaction/domain/models/social_interaction_record.dart';
import '../../../social_interaction/domain/repositories/social_interaction_repository.dart';
import '../../domain/exceptions/frequency_failure.dart';
import '../../domain/models/frequency_event.dart';
import '../../domain/models/frequency_metric_type.dart';
import '../../domain/repositories/frequency_repository.dart';

class CompositeFrequencyRepository implements FrequencyRepository {
  factory CompositeFrequencyRepository({
    required BehaviorRepository behaviorRepository,
    required DysregulationRepository dysregulationRepository,
    required SocialInteractionRepository socialInteractionRepository,
    required FeedingRepository feedingRepository,
    required AtypicalSituationRepository atypicalSituationRepository,
  }) {
    return CompositeFrequencyRepository._(
      behaviorRepository,
      dysregulationRepository,
      socialInteractionRepository,
      feedingRepository,
      atypicalSituationRepository,
    );
  }

  CompositeFrequencyRepository._(
    this._behaviorRepository,
    this._dysregulationRepository,
    this._socialInteractionRepository,
    this._feedingRepository,
    this._atypicalSituationRepository,
  );

  final BehaviorRepository _behaviorRepository;

  final DysregulationRepository _dysregulationRepository;

  final SocialInteractionRepository _socialInteractionRepository;

  final FeedingRepository _feedingRepository;

  final AtypicalSituationRepository _atypicalSituationRepository;

  @override
  Future<List<FrequencyEvent>> recoverEvents({
    required String anonymousId,
    required FrequencyMetricType metricType,
  }) async {
    final normalizedAnonymousId = anonymousId.trim();

    if (normalizedAnonymousId.isEmpty || normalizedAnonymousId.contains('/')) {
      throw const FrequencyFailure('El perfil seleccionado no es válido.');
    }

    try {
      switch (metricType) {
        case FrequencyMetricType.behavior:
          final records = await _behaviorRepository.recoverBehaviors(
            anonymousId: normalizedAnonymousId,
          );

          return _mapBehaviors(
            records: records,
            anonymousId: normalizedAnonymousId,
          );

        case FrequencyMetricType.dysregulation:
          final records = await _dysregulationRepository.recoverDysregulations(
            anonymousId: normalizedAnonymousId,
          );

          return _mapDysregulations(
            records: records,
            anonymousId: normalizedAnonymousId,
          );

        case FrequencyMetricType.socialInteraction:
          final records = await _socialInteractionRepository
              .recoverSocialInteractions(anonymousId: normalizedAnonymousId);

          return _mapSocialInteractions(
            records: records,
            anonymousId: normalizedAnonymousId,
          );

        case FrequencyMetricType.feeding:
          final records = await _feedingRepository.recoverFeedingRecords(
            anonymousId: normalizedAnonymousId,
          );

          return _mapFeedingRecords(
            records: records,
            anonymousId: normalizedAnonymousId,
          );

        case FrequencyMetricType.atypicalSituation:
          final records = await _atypicalSituationRepository
              .recoverAtypicalSituations(anonymousId: normalizedAnonymousId);

          return _mapAtypicalSituations(
            records: records,
            anonymousId: normalizedAnonymousId,
          );
      }
    } on FrequencyFailure {
      rethrow;
    } catch (_) {
      throw const FrequencyFailure(
        'No fue posible recuperar los registros '
        'para calcular la frecuencia. '
        'Inténtalo nuevamente.',
      );
    }
  }

  List<FrequencyEvent> _mapBehaviors({
    required Iterable<BehaviorRecord> records,
    required String anonymousId,
  }) {
    return List.unmodifiable(
      records
          .where((record) => record.anonymousId == anonymousId)
          .map(
            (record) => FrequencyEvent(
              recordId: record.recordId,
              anonymousId: record.anonymousId,
              metricType: FrequencyMetricType.behavior,
              date: record.date,
              categoryCode: record.category.code,
            ),
          ),
    );
  }

  List<FrequencyEvent> _mapDysregulations({
    required Iterable<DysregulationRecord> records,
    required String anonymousId,
  }) {
    return List.unmodifiable(
      records
          .where((record) => record.anonymousId == anonymousId)
          .map(
            (record) => FrequencyEvent(
              recordId: record.recordId,
              anonymousId: record.anonymousId,
              metricType: FrequencyMetricType.dysregulation,
              date: record.date,
            ),
          ),
    );
  }

  List<FrequencyEvent> _mapSocialInteractions({
    required Iterable<SocialInteractionRecord> records,
    required String anonymousId,
  }) {
    return List.unmodifiable(
      records
          .where((record) => record.anonymousId == anonymousId)
          .map(
            (record) => FrequencyEvent(
              recordId: record.recordId,
              anonymousId: record.anonymousId,
              metricType: FrequencyMetricType.socialInteraction,
              date: record.date,
              categoryCode: record.category.code,
            ),
          ),
    );
  }

  List<FrequencyEvent> _mapFeedingRecords({
    required Iterable<FeedingRecord> records,
    required String anonymousId,
  }) {
    return List.unmodifiable(
      records
          .where((record) => record.anonymousId == anonymousId)
          .map(
            (record) => FrequencyEvent(
              recordId: record.recordId,
              anonymousId: record.anonymousId,
              metricType: FrequencyMetricType.feeding,
              date: record.date,
              categoryCode: record.category.code,
            ),
          ),
    );
  }

  List<FrequencyEvent> _mapAtypicalSituations({
    required Iterable<AtypicalSituationRecord> records,
    required String anonymousId,
  }) {
    return List.unmodifiable(
      records
          .where((record) => record.anonymousId == anonymousId)
          .map(
            (record) => FrequencyEvent(
              recordId: record.recordId,
              anonymousId: record.anonymousId,
              metricType: FrequencyMetricType.atypicalSituation,
              date: record.date,
              categoryCode: record.category.code,
            ),
          ),
    );
  }
}
