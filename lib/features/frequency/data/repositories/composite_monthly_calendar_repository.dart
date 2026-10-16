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
import '../../domain/models/monthly_calendar_record.dart';

abstract interface class MonthlyCalendarRepository {
  Future<MonthlyCalendarIndex> recover({required String anonymousId});
}

class CompositeMonthlyCalendarRepository implements MonthlyCalendarRepository {
  const CompositeMonthlyCalendarRepository({
    required this.behaviorRepository,
    required this.sleepRepository,
    required this.feedingRepository,
    required this.socialInteractionRepository,
    required this.dysregulationRepository,
    required this.atypicalSituationRepository,
    required this.routineStatusRepository,
  });

  final BehaviorRepository behaviorRepository;
  final SleepRepository sleepRepository;
  final FeedingRepository feedingRepository;
  final SocialInteractionRepository socialInteractionRepository;
  final DysregulationRepository dysregulationRepository;
  final AtypicalSituationRepository atypicalSituationRepository;
  final RoutineStatusRepository routineStatusRepository;

  @override
  Future<MonthlyCalendarIndex> recover({required String anonymousId}) async {
    final id = anonymousId.trim();

    if (id.isEmpty || id.contains('/')) {
      throw ArgumentError.value(id, 'anonymousId');
    }

    final results = await Future.wait<dynamic>([
      behaviorRepository.recoverBehaviors(anonymousId: id),
      sleepRepository.recoverSleepRecords(anonymousId: id),
      feedingRepository.recoverFeedingRecords(anonymousId: id),
      socialInteractionRepository.recoverSocialInteractions(anonymousId: id),
      dysregulationRepository.recoverDysregulations(anonymousId: id),
      atypicalSituationRepository.recoverAtypicalSituations(anonymousId: id),
      routineStatusRepository.recoverRoutineStatuses(anonymousId: id),
    ]);

    final records = <MonthlyCalendarRecord>[
      for (final item in results[0] as List<BehaviorRecord>)
        MonthlyCalendarRecord(
          id: item.recordId,
          anonymousId: item.anonymousId,
          date: item.date,
          type: CalendarRecordType.behavior,
          description: item.category.label,
          sourceRecord: item,
        ),
      for (final item in results[1] as List<SleepRecord>)
        MonthlyCalendarRecord(
          id: item.recordId,
          anonymousId: item.anonymousId,
          date: item.date,
          type: CalendarRecordType.sleep,
          description:
              'Duración registrada: '
              '${_formatSleepDuration(item.durationMinutes)}',
          sourceRecord: item,
        ),
      for (final item in results[2] as List<FeedingRecord>)
        MonthlyCalendarRecord(
          id: item.recordId,
          anonymousId: item.anonymousId,
          date: item.date,
          type: CalendarRecordType.feeding,
          description: item.category.label,
          sourceRecord: item,
        ),
      for (final item in results[3] as List<SocialInteractionRecord>)
        MonthlyCalendarRecord(
          id: item.recordId,
          anonymousId: item.anonymousId,
          date: item.date,
          type: CalendarRecordType.socialInteraction,
          description: item.category.label,
          sourceRecord: item,
        ),
      for (final item in results[4] as List<DysregulationRecord>)
        MonthlyCalendarRecord(
          id: item.recordId,
          anonymousId: item.anonymousId,
          date: item.date,
          type: CalendarRecordType.dysregulation,
          description: 'Episodio registrado',
          sourceRecord: item,
        ),
      for (final item in results[5] as List<AtypicalSituationRecord>)
        MonthlyCalendarRecord(
          id: item.recordId,
          anonymousId: item.anonymousId,
          date: item.date,
          type: CalendarRecordType.atypicalSituation,
          description: item.category.label,
          sourceRecord: item,
        ),
      for (final item in results[6] as List<RoutineStatusRecord>)
        MonthlyCalendarRecord(
          id: item.recordId,
          anonymousId: item.anonymousId,
          date: item.date,
          type: CalendarRecordType.routineStatus,
          description: item.status.label,
          sourceRecord: item,
        ),
    ];

    return MonthlyCalendarIndex(anonymousId: id, records: records);
  }

  static String _formatSleepDuration(int minutes) {
    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (hours > 0 && remainingMinutes > 0) {
      return '$hours h $remainingMinutes min';
    }

    if (hours > 0) {
      return '$hours h';
    }

    return '$remainingMinutes min';
  }
}
