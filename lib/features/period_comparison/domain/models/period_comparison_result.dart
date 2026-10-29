import '../../../duration/domain/models/duration_metric_type.dart';
import '../../../duration/domain/services/duration_overview_service.dart';
import '../../../routine_compliance/domain/services/routine_overview_service.dart';
import 'comparison_period.dart';

class PeriodComparisonSnapshot {
  const PeriodComparisonSnapshot({
    required this.period,
    required this.durations,
    required this.routines,
  });

  final ComparisonPeriod period;
  final DurationOverview durations;
  final RoutineOverview routines;

  double? averageMinutesFor(DurationMetricType type) {
    return durations.resultFor(type).averageMinutes;
  }

  int validDurationsFor(DurationMetricType type) {
    return durations.resultFor(type).validRecordCount;
  }

  double? get routineCompliancePercentage {
    return routines.compliancePercentage;
  }

  int get routineStatusCount {
    return routines.totalRecords;
  }

  int get completedRoutineCount {
    return routines.completedCount;
  }

  bool get hasAnyData {
    return durations.hasAnyData || routines.hasRecords;
  }
}

class PeriodComparisonResult {
  const PeriodComparisonResult({
    required this.anonymousId,
    required this.periodA,
    required this.periodB,
  });

  final String anonymousId;
  final PeriodComparisonSnapshot periodA;
  final PeriodComparisonSnapshot periodB;

  bool get hasAnyData {
    return periodA.hasAnyData || periodB.hasAnyData;
  }
}
