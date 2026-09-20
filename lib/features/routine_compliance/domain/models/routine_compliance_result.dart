import '../../../routine_status/domain/models/routine_status.dart';
import 'routine_compliance_entry.dart';
import 'routine_compliance_query.dart';

class RoutineComplianceResult {
  RoutineComplianceResult._({
    required this.query,
    required this.entries,
    required this.programmedCount,
    required this.completedCount,
    required this.compliancePercentage,
  });

  factory RoutineComplianceResult({
    required RoutineComplianceQuery query,
    required Iterable<RoutineComplianceEntry> entries,
  }) {
    final normalizedEntries = List<RoutineComplianceEntry>.unmodifiable(
      entries,
    );

    final programmedCount = normalizedEntries.length;

    final completedCount = normalizedEntries
        .where((entry) => entry.status == RoutineStatus.completed)
        .length;

    final compliancePercentage = programmedCount == 0
        ? null
        : completedCount / programmedCount * 100;

    return RoutineComplianceResult._(
      query: query,
      entries: normalizedEntries,
      programmedCount: programmedCount,
      completedCount: completedCount,
      compliancePercentage: compliancePercentage,
    );
  }

  static const String indicatorCode = 'IND-09';

  static const String programmedDataCode = 'DAT-066';

  static const String completedDataCode = 'DAT-067';

  static const String percentageDataCode = 'DAT-068';

  final RoutineComplianceQuery query;

  final List<RoutineComplianceEntry> entries;

  final int programmedCount;

  final int completedCount;

  final double? compliancePercentage;

  bool get hasProgrammedRoutines => programmedCount > 0;

  bool get hasPercentage => compliancePercentage != null;
}
