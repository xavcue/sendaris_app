import '../../../duration/domain/models/duration_metric_type.dart';
import '../../../duration/domain/services/duration_overview_service.dart';
import '../../../frequency/domain/models/coverage_result.dart';
import '../../../frequency/domain/models/monthly_calendar_record.dart';
import '../../../period_comparison/domain/models/comparison_period.dart';
import '../../../routine_compliance/domain/services/routine_overview_service.dart';

/// Reporte transitorio para consulta interna.
/// No representa un documento persistido.
class InternalReport {
  InternalReport({
    required this.anonymousId,
    required this.period,
    required List<MonthlyCalendarRecord> records,
    required this.coverage,
    required this.durations,
    required this.routines,
  }) : records = List<MonthlyCalendarRecord>.unmodifiable(records),
       recordCounts = Map<CalendarRecordType, int>.unmodifiable(
         _countRecords(records),
       );

  final String anonymousId;
  final ComparisonPeriod period;

  /// Referencias transitorias a registros recuperados.
  /// No deben persistirse como copias del historial.
  final List<MonthlyCalendarRecord> records;

  final Map<CalendarRecordType, int> recordCounts;

  final CoverageResult coverage;
  final DurationOverview durations;
  final RoutineOverview routines;

  int get totalRecords => records.length;

  bool get hasRecords => records.isNotEmpty;

  bool get hasAnyInformation =>
      hasRecords || durations.hasAnyData || routines.hasRecords;

  int countFor(CalendarRecordType type) {
    return recordCounts[type] ?? 0;
  }

  double? averageMinutesFor(DurationMetricType type) {
    return durations.resultFor(type).averageMinutes;
  }

  int validDurationsFor(DurationMetricType type) {
    return durations.resultFor(type).validRecordCount;
  }

  double? get routineCompliancePercentage {
    return routines.compliancePercentage;
  }

  int get routineStatusCount => routines.totalRecords;

  int get completedRoutineCount => routines.completedCount;

  int get daysWithRecords => coverage.daysWithRecords;

  int get totalDays => coverage.totalDays;

  double get coveragePercentage => coverage.percentage;

  static Map<CalendarRecordType, int> _countRecords(
    Iterable<MonthlyCalendarRecord> records,
  ) {
    final counts = <CalendarRecordType, int>{
      for (final type in CalendarRecordType.values) type: 0,
    };

    for (final record in records) {
      counts[record.type] = counts[record.type]! + 1;
    }

    return counts;
  }
}
