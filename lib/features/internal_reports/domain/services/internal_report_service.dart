import '../../../duration/domain/services/duration_overview_service.dart';
import '../../../frequency/domain/models/monthly_calendar_record.dart';
import '../../../frequency/domain/services/coverage_calculator.dart';
import '../../../period_comparison/domain/models/comparison_period.dart';
import '../../../routine_compliance/domain/models/routine_compliance_query.dart';
import '../../../routine_compliance/domain/services/routine_overview_service.dart';
import '../models/internal_report.dart';

typedef ReportCalendarLoader = Future<MonthlyCalendarIndex> Function({
  required String anonymousId,
});

/// Consolida informacion existente sin persistir copias.
/// La carga del calendario se inyecta desde la capa superior.
class InternalReportService {
  const InternalReportService({
    required ReportCalendarLoader calendarLoader,
    required DurationOverviewService durationService,
    required RoutineOverviewService routineService,
  }) : this._(calendarLoader, durationService, routineService);

  const InternalReportService._(
    this._calendarLoader,
    this._durationService,
    this._routineService,
  );

  final ReportCalendarLoader _calendarLoader;
  final DurationOverviewService _durationService;
  final RoutineOverviewService _routineService;

  Future<InternalReport> generate({
    required String anonymousId,
    required ComparisonPeriod period,
  }) async {
    // Validacion antes de consultar cualquiera de las fuentes.
    final query = RoutineComplianceQuery.create(
      anonymousId: anonymousId,
      startDate: period.startDate,
      endDate: period.endDate,
    );

    final id = query.anonymousId;

    // Recuperacion concurrente sin fabricar resultados parciales.
    final results = await Future.wait<Object>([
      _calendarLoader(anonymousId: id),
      _durationService.load(
        anonymousId: id,
        startDate: query.startDate,
        endDate: query.endDate,
      ),
      _routineService.load(
        anonymousId: id,
        startDate: query.startDate,
        endDate: query.endDate,
      ),
    ]);

    final index = results[0] as MonthlyCalendarIndex;
    final durations = results[1] as DurationOverview;
    final routines = results[2] as RoutineOverview;

    // Nunca aceptar datos asociados con otro seguimiento.
    if (index.anonymousId != id ||
        durations.anonymousId != id ||
        routines.anonymousId != id) {
      throw StateError('No fue posible validar el seguimiento del reporte.');
    }

    // Comprobar que todos los indicadores corresponden
    // al mismo intervalo solicitado.
    if (!_sameDate(durations.startDate, query.startDate) ||
        !_sameDate(durations.endDate, query.endDate) ||
        !_sameDate(routines.startDate, query.startDate) ||
        !_sameDate(routines.endDate, query.endDate)) {
      throw StateError(
        'Los indicadores no corresponden al periodo solicitado.',
      );
    }

    final periodRecords = index
        .recordsInPeriod(startDate: query.startDate, endDate: query.endDate)
        .toList();

    // Orden: fecha del acontecimiento descendente,
    // fecha de creacion como desempate y orden estable.
    periodRecords.sort((first, second) {
      final eventOrder = second.chronologicalDate.compareTo(
        first.chronologicalDate,
      );

      if (eventOrder != 0) {
        return eventOrder;
      }

      final firstCreated = first.createdAt ?? first.chronologicalDate;
      final secondCreated = second.createdAt ?? second.chronologicalDate;

      final creationOrder = secondCreated.compareTo(firstCreated);

      if (creationOrder != 0) {
        return creationOrder;
      }

      final typeOrder = first.type.index.compareTo(second.type.index);

      if (typeOrder != 0) {
        return typeOrder;
      }

      return first.id.compareTo(second.id);
    });

    final coverage = CoverageCalculator.calculate(
      index: index,
      startDate: query.startDate,
      endDate: query.endDate,
    );

    if (coverage.anonymousId != id ||
        !_sameDate(coverage.startDate, query.startDate) ||
        !_sameDate(coverage.endDate, query.endDate)) {
      throw StateError(
        'La cobertura no corresponde al seguimiento solicitado.',
      );
    }

    return InternalReport(
      anonymousId: id,
      period: ComparisonPeriod(
        startDate: query.startDate,
        endDate: query.endDate,
      ),
      records: periodRecords,
      coverage: coverage,
      durations: durations,
      routines: routines,
    );
  }

  static bool _sameDate(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }
}
