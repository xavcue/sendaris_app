import '../models/coverage_result.dart';
import '../models/monthly_calendar_record.dart';

abstract final class CoverageCalculator {
  static CoverageResult calculate({
    required MonthlyCalendarIndex index,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);

    final end = DateTime(endDate.year, endDate.month, endDate.day);

    if (end.isBefore(start)) {
      throw ArgumentError.value(
        endDate,
        'endDate',
        'La fecha final no puede ser anterior a la inicial.',
      );
    }

    // Se utiliza UTC exclusivamente para calcular la cantidad
    // de días naturales, evitando diferencias por cambios
    // de horario de verano.
    final startUtc = DateTime.utc(start.year, start.month, start.day);

    final endUtc = DateTime.utc(end.year, end.month, end.day);

    final totalDays = endUtc.difference(startUtc).inDays + 1;

    final daysWithRecords = index.countDaysWithRecords(
      startDate: start,
      endDate: end,
    );

    return CoverageResult(
      anonymousId: index.anonymousId,
      startDate: start,
      endDate: end,
      totalDays: totalDays,
      daysWithRecords: daysWithRecords,
    );
  }
}
