class CoverageResult {
  const CoverageResult({
    required this.anonymousId,
    required this.startDate,
    required this.endDate,
    required this.totalDays,
    required this.daysWithRecords,
  }) : assert(totalDays > 0),
       assert(daysWithRecords >= 0),
       assert(daysWithRecords <= totalDays);

  final String anonymousId;
  final DateTime startDate;
  final DateTime endDate;

  final int totalDays;
  final int daysWithRecords;

  int get daysWithoutRecords => totalDays - daysWithRecords;

  double get percentage => (daysWithRecords / totalDays) * 100;

  bool get hasRecords => daysWithRecords > 0;
}
