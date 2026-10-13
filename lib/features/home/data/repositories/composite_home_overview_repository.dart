import '../../../atypical_situation/domain/models/atypical_situation_record.dart';
import '../../../atypical_situation/domain/repositories/atypical_situation_repository.dart';
import '../../../behavior/domain/models/behavior_record.dart';
import '../../../behavior/domain/repositories/behavior_repository.dart';
import '../../../dysregulation/domain/models/dysregulation_record.dart';
import '../../../dysregulation/domain/repositories/dysregulation_repository.dart';
import '../../../feeding/domain/models/feeding_record.dart';
import '../../../feeding/domain/repositories/feeding_repository.dart';
import '../../../routine_status/domain/models/routine_status_record.dart';
import '../../../routine_status/domain/repositories/routine_status_repository.dart';
import '../../../sleep/domain/models/sleep_record.dart';
import '../../../sleep/domain/repositories/sleep_repository.dart';
import '../../../social_interaction/domain/models/social_interaction_record.dart';
import '../../../social_interaction/domain/repositories/social_interaction_repository.dart';
import '../../domain/exceptions/home_overview_failure.dart';
import '../../domain/models/home_activity_area.dart';
import '../../domain/models/home_day_overview.dart';
import '../../domain/repositories/home_overview_repository.dart';

class CompositeHomeOverviewRepository implements HomeOverviewRepository {
  const CompositeHomeOverviewRepository({
    required this._behaviorRepository,
    required this._sleepRepository,
    required this._feedingRepository,
    required this._socialInteractionRepository,
    required this._dysregulationRepository,
    required this._atypicalSituationRepository,
    required this._routineStatusRepository,
  });

  final BehaviorRepository _behaviorRepository;

  final SleepRepository _sleepRepository;

  final FeedingRepository _feedingRepository;

  final SocialInteractionRepository _socialInteractionRepository;

  final DysregulationRepository _dysregulationRepository;

  final AtypicalSituationRepository _atypicalSituationRepository;

  final RoutineStatusRepository _routineStatusRepository;

  @override
  Future<HomeDayOverview> recoverDayOverview({
    required String anonymousId,
    required DateTime localDate,
  }) async {
    final normalizedAnonymousId = anonymousId.trim();

    if (normalizedAnonymousId.isEmpty || normalizedAnonymousId.contains('/')) {
      throw const HomeOverviewFailure(
        'El seguimiento seleccionado no es válido.',
      );
    }

    final normalizedDate = _dateOnly(localDate);

    try {
      final results = await Future.wait<dynamic>([
        _behaviorRepository.recoverBehaviors(
          anonymousId: normalizedAnonymousId,
        ),
        _sleepRepository.recoverSleepRecords(
          anonymousId: normalizedAnonymousId,
        ),
        _feedingRepository.recoverFeedingRecords(
          anonymousId: normalizedAnonymousId,
        ),
        _socialInteractionRepository.recoverSocialInteractions(
          anonymousId: normalizedAnonymousId,
        ),
        _dysregulationRepository.recoverDysregulations(
          anonymousId: normalizedAnonymousId,
        ),
        _atypicalSituationRepository.recoverAtypicalSituations(
          anonymousId: normalizedAnonymousId,
        ),
        _routineStatusRepository.recoverRoutineStatuses(
          anonymousId: normalizedAnonymousId,
        ),
      ]);

      final behaviorRecords = results[0] as List<BehaviorRecord>;

      final sleepRecords = results[1] as List<SleepRecord>;

      final feedingRecords = results[2] as List<FeedingRecord>;

      final socialInteractionRecords =
          results[3] as List<SocialInteractionRecord>;

      final dysregulationRecords = results[4] as List<DysregulationRecord>;

      final atypicalSituationRecords =
          results[5] as List<AtypicalSituationRecord>;

      final routineStatusRecords = results[6] as List<RoutineStatusRecord>;

      final recordCounts = <HomeActivityArea, int>{
        HomeActivityArea.behavior: _countRecordsForDate<BehaviorRecord>(
          behaviorRecords,
          anonymousId: normalizedAnonymousId,
          localDate: normalizedDate,
          dateOf: (record) => record.date,
          anonymousIdOf: (record) => record.anonymousId,
        ),
        HomeActivityArea.sleep: _countRecordsForDate<SleepRecord>(
          sleepRecords,
          anonymousId: normalizedAnonymousId,
          localDate: normalizedDate,
          dateOf: (record) => record.date,
          anonymousIdOf: (record) => record.anonymousId,
        ),
        HomeActivityArea.feeding: _countRecordsForDate<FeedingRecord>(
          feedingRecords,
          anonymousId: normalizedAnonymousId,
          localDate: normalizedDate,
          dateOf: (record) => record.date,
          anonymousIdOf: (record) => record.anonymousId,
        ),
        HomeActivityArea.socialInteraction:
            _countRecordsForDate<SocialInteractionRecord>(
              socialInteractionRecords,
              anonymousId: normalizedAnonymousId,
              localDate: normalizedDate,
              dateOf: (record) => record.date,
              anonymousIdOf: (record) => record.anonymousId,
            ),
        HomeActivityArea.dysregulation:
            _countRecordsForDate<DysregulationRecord>(
              dysregulationRecords,
              anonymousId: normalizedAnonymousId,
              localDate: normalizedDate,
              dateOf: (record) => record.date,
              anonymousIdOf: (record) => record.anonymousId,
            ),
        HomeActivityArea.otherSituation:
            _countRecordsForDate<AtypicalSituationRecord>(
              atypicalSituationRecords,
              anonymousId: normalizedAnonymousId,
              localDate: normalizedDate,
              dateOf: (record) => record.date,
              anonymousIdOf: (record) => record.anonymousId,
            ),
        HomeActivityArea.routines: _countRecordsForDate<RoutineStatusRecord>(
          routineStatusRecords,
          anonymousId: normalizedAnonymousId,
          localDate: normalizedDate,
          dateOf: (record) => record.date,
          anonymousIdOf: (record) => record.anonymousId,
        ),
      };

      return HomeDayOverview(date: normalizedDate, recordCounts: recordCounts);
    } catch (_) {
      throw const HomeOverviewFailure(
        'No fue posible actualizar el panorama de hoy. '
        'Inténtalo nuevamente.',
      );
    }
  }

  int _countRecordsForDate<T>(
    Iterable<T> records, {
    required String anonymousId,
    required DateTime localDate,
    required DateTime Function(T record) dateOf,
    required String Function(T record) anonymousIdOf,
  }) {
    var count = 0;

    for (final record in records) {
      if (anonymousIdOf(record) != anonymousId) {
        continue;
      }

      if (_isSameLocalDate(dateOf(record), localDate)) {
        count += 1;
      }
    }

    return count;
  }

  bool _isSameLocalDate(DateTime value, DateTime expected) {
    final localValue = value.toLocal();

    return localValue.year == expected.year &&
        localValue.month == expected.month &&
        localValue.day == expected.day;
  }

  DateTime _dateOnly(DateTime value) {
    final localValue = value.toLocal();

    return DateTime(localValue.year, localValue.month, localValue.day);
  }
}
