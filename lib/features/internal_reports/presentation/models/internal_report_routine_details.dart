import '../../../routine_status/domain/models/routine_status.dart';
import '../../domain/models/internal_report.dart';
import 'internal_report_display_data.dart';

/// Detalle descriptivo de los estados de rutina de un reporte.
///
/// Reutiliza los datos ya recuperados por InternalReportService.
/// No realiza consultas, escrituras ni nuevas agregaciones persistentes.
class InternalReportRoutineDetails {
  InternalReportRoutineDetails._(List<InternalReportRoutineEntry> entries)
    : entries = List<InternalReportRoutineEntry>.unmodifiable(entries);

  factory InternalReportRoutineDetails.fromReport(InternalReport report) {
    final anonymousId = report.anonymousId.trim();

    if (anonymousId.isEmpty || report.routines.anonymousId != anonymousId) {
      throw StateError('Los estados de rutina pertenecen a otro seguimiento.');
    }

    if (!_sameDay(report.routines.startDate, report.period.startDate) ||
        !_sameDay(report.routines.endDate, report.period.endDate)) {
      throw StateError('Los estados de rutina pertenecen a otro periodo.');
    }

    final source = report.routines.result.entries;

    if (source.length != report.routineStatusCount) {
      throw StateError('El total de estados no coincide con el reporte.');
    }

    final knownNames = <String, String>{
      for (final routine in report.routines.routines)
        routine.routineId: routine.routineName.trim(),
    };

    final details = <InternalReportRoutineEntry>[];

    for (final entry in source) {
      final date = DateTime(entry.date.year, entry.date.month, entry.date.day);

      if (entry.anonymousId != anonymousId ||
          date.isBefore(report.period.startDate) ||
          date.isAfter(report.period.endDate)) {
        throw StateError(
          'Un estado de rutina está fuera del alcance del reporte.',
        );
      }

      final entryName = entry.routineName?.trim() ?? '';
      final knownName = knownNames[entry.routineId] ?? '';

      final name = entryName.isNotEmpty
          ? entryName
          : knownName.isNotEmpty
          ? knownName
          : 'Rutina sin nombre';

      details.add(
        InternalReportRoutineEntry(
          recordId: entry.recordId,
          routineName: name,
          date: date,
          status: entry.status,
        ),
      );
    }

    details.sort((first, second) {
      final byDate = second.date.compareTo(first.date);

      if (byDate != 0) {
        return byDate;
      }

      final byName = first.routineName.toLowerCase().compareTo(
        second.routineName.toLowerCase(),
      );

      if (byName != 0) {
        return byName;
      }

      return first.recordId.compareTo(second.recordId);
    });

    for (final status in RoutineStatus.values) {
      final calculated = details.where((item) => item.status == status).length;

      if (calculated != report.routines.countForStatus(status)) {
        throw StateError('El desglose de estados no coincide con el reporte.');
      }
    }

    return InternalReportRoutineDetails._(details);
  }

  final List<InternalReportRoutineEntry> entries;

  int get total => entries.length;

  bool get isEmpty => entries.isEmpty;

  List<InternalReportRoutineEntry> forStatus(RoutineStatus status) {
    return List<InternalReportRoutineEntry>.unmodifiable(
      entries.where((entry) => entry.status == status),
    );
  }

  static bool _sameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}

class InternalReportRoutineEntry {
  const InternalReportRoutineEntry({
    required this.recordId,
    required this.routineName,
    required this.date,
    required this.status,
  });

  final String recordId;
  final String routineName;
  final DateTime date;
  final RoutineStatus status;

  String get dateLabel => InternalReportDisplayData.formatDate(date);

  String get statusLabel => status.label;
}
