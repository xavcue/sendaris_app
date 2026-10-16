import '../../../routine_status/domain/models/routine_status.dart';
import '../models/routine_compliance_entry.dart';
import '../models/routine_compliance_query.dart';
import '../models/routine_compliance_result.dart';
import '../repositories/routine_compliance_repository.dart';
import 'routine_compliance_calculator.dart';

class RoutineOverview {
  RoutineOverview({
    required this.result,
    required Map<RoutineStatus, int> statusCounts,
    required Iterable<RoutineOverviewItem> routines,
  }) : statusCounts = Map<RoutineStatus, int>.unmodifiable(statusCounts),
       routines = List<RoutineOverviewItem>.unmodifiable(routines);

  final RoutineComplianceResult result;

  final Map<RoutineStatus, int> statusCounts;

  final List<RoutineOverviewItem> routines;

  String get anonymousId => result.query.anonymousId;

  DateTime get startDate => result.query.startDate;

  DateTime get endDate => result.query.endDate;

  int get totalRecords => result.programmedCount;

  int get completedCount => result.completedCount;

  double? get compliancePercentage => result.compliancePercentage;

  bool get hasRecords => result.hasProgrammedRoutines;

  int countForStatus(RoutineStatus status) {
    return statusCounts[status] ?? 0;
  }
}

class RoutineOverviewItem {
  RoutineOverviewItem({
    required this.routineId,
    required this.routineName,
    required this.result,
    required Map<RoutineStatus, int> statusCounts,
  }) : statusCounts = Map<RoutineStatus, int>.unmodifiable(statusCounts);

  final String routineId;

  final String routineName;

  final RoutineComplianceResult result;

  final Map<RoutineStatus, int> statusCounts;

  int get totalRecords => result.programmedCount;

  int get completedCount => result.completedCount;

  double? get compliancePercentage => result.compliancePercentage;

  int countForStatus(RoutineStatus status) {
    return statusCounts[status] ?? 0;
  }
}

class RoutineOverviewService {
  const RoutineOverviewService(this._repository);

  final RoutineComplianceRepository _repository;

  Future<RoutineOverview> load({
    required String anonymousId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final query = RoutineComplianceQuery.create(
      anonymousId: anonymousId,
      startDate: startDate,
      endDate: endDate,
    );

    final entries = await _repository.recoverEntries(
      anonymousId: query.anonymousId,
    );

    final result = RoutineComplianceCalculator.calculate(
      query: query,
      entries: entries,
    );

    return RoutineOverview(
      result: result,
      statusCounts: _countStatuses(result.entries),
      routines: _groupByRoutine(result),
    );
  }

  static Map<RoutineStatus, int> _countStatuses(
    Iterable<RoutineComplianceEntry> entries,
  ) {
    final counts = <RoutineStatus, int>{
      for (final status in RoutineStatus.values) status: 0,
    };

    for (final entry in entries) {
      counts[entry.status] = counts[entry.status]! + 1;
    }

    return Map<RoutineStatus, int>.unmodifiable(counts);
  }

  static List<RoutineOverviewItem> _groupByRoutine(
    RoutineComplianceResult result,
  ) {
    final grouped = <String, List<RoutineComplianceEntry>>{};

    for (final entry in result.entries) {
      grouped.putIfAbsent(entry.routineId, () => []).add(entry);
    }

    final routines = <RoutineOverviewItem>[];

    for (final group in grouped.entries) {
      final entries = group.value;

      final availableNames = entries
          .map((entry) => entry.routineName?.trim() ?? '')
          .where((name) => name.isNotEmpty);

      final routineName = availableNames.isEmpty
          ? 'Rutina sin nombre'
          : availableNames.first;

      final routineResult = RoutineComplianceResult(
        query: result.query,
        entries: entries,
      );

      routines.add(
        RoutineOverviewItem(
          routineId: group.key,
          routineName: routineName,
          result: routineResult,
          statusCounts: _countStatuses(routineResult.entries),
        ),
      );
    }

    routines.sort((first, second) {
      final byName = first.routineName.toLowerCase().compareTo(
        second.routineName.toLowerCase(),
      );

      if (byName != 0) {
        return byName;
      }

      return first.routineId.compareTo(second.routineId);
    });

    return List<RoutineOverviewItem>.unmodifiable(routines);
  }
}
