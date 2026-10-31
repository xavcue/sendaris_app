import '../../../frequency/domain/models/monthly_calendar_record.dart';
import '../../domain/models/internal_report.dart';

/// Proyección de solo lectura compartida por la interfaz y el PDF.
///
/// Los totales y porcentajes proceden de [InternalReport]. Este modelo no
/// consulta Firebase, no modifica registros y no redondea los cálculos fuente.
class InternalReportDisplayData {
  InternalReportDisplayData.fromReport(InternalReport report)
    : totalRecords = report.totalRecords,
      daysWithRecords = report.daysWithRecords,
      totalDays = report.totalDays,
      coveragePercentage = report.coveragePercentage,
      completedRoutineCount = report.completedRoutineCount,
      routineStatusCount = report.routineStatusCount,
      routineCompliancePercentage = report.routineCompliancePercentage,
      periodLabel =
          '${formatDate(report.period.startDate)} - '
          '${formatDate(report.period.endDate)}',
      categories = List<InternalReportCategoryDisplay>.unmodifiable(
        _categories(report),
      ),
      rows = List<InternalReportRecordDisplay>.unmodifiable(
        report.records.map(InternalReportRecordDisplay.fromRecord),
      );

  final int totalRecords;
  final int daysWithRecords;
  final int totalDays;
  final double coveragePercentage;
  final int completedRoutineCount;
  final int routineStatusCount;
  final double? routineCompliancePercentage;
  final String periodLabel;

  /// Solo categorías con registros, ordenadas por cantidad descendente.
  final List<InternalReportCategoryDisplay> categories;

  /// Mantiene el orden cronológico establecido por InternalReportService.
  final List<InternalReportRecordDisplay> rows;

  InternalReportCategoryDisplay? get mostFrequentCategory =>
      categories.isEmpty ? null : categories.first;

  String get coverageText => formatPercentage(coveragePercentage);

  String get complianceText => routineCompliancePercentage == null
      ? 'Sin datos'
      : formatPercentage(routineCompliancePercentage!);

  static List<InternalReportCategoryDisplay> _categories(
    InternalReport report,
  ) {
    final result = <InternalReportCategoryDisplay>[
      for (final type in CalendarRecordType.values)
        if (report.countFor(type) > 0)
          InternalReportCategoryDisplay(
            type: type,
            count: report.countFor(type),
            total: report.totalRecords,
          ),
    ];

    result.sort((first, second) {
      final countOrder = second.count.compareTo(first.count);
      return countOrder != 0
          ? countOrder
          : first.type.index.compareTo(second.type.index);
    });

    return result;
  }

  static String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  static String formatPercentage(double value) =>
      '${value.toStringAsFixed(1)} %';
}

class InternalReportCategoryDisplay {
  const InternalReportCategoryDisplay({
    required this.type,
    required this.count,
    required this.total,
  });

  final CalendarRecordType type;
  final int count;
  final int total;

  String get label => type.label;

  /// Relativo al total del periodo, no a la categoría más frecuente.
  double get fraction => total == 0 ? 0 : count / total;

  String get percentageText =>
      InternalReportDisplayData.formatPercentage(fraction * 100);
}

class InternalReportRecordDisplay {
  const InternalReportRecordDisplay({
    required this.record,
    required this.dateText,
  });

  factory InternalReportRecordDisplay.fromRecord(MonthlyCalendarRecord record) {
    // Igual que la pantalla de registros: fecha cronológica del acontecimiento.
    final date = record.chronologicalDate;
    final formatted = InternalReportDisplayData.formatDate(date);
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');

    return InternalReportRecordDisplay(
      record: record,
      dateText: record.eventDateTime == null
          ? formatted
          : '$formatted · $hour:$minute',
    );
  }

  final MonthlyCalendarRecord record;
  final String dateText;

  String get id => record.id;
  CalendarRecordType get type => record.type;
  String get categoryLabel => record.type.label;
  String get description => record.description;
}
