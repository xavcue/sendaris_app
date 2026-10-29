import '../../../duration/domain/repositories/duration_repository.dart';
import '../../../duration/domain/services/duration_overview_service.dart';
import '../../../routine_compliance/domain/models/routine_compliance_query.dart';
import '../../../routine_compliance/domain/repositories/routine_compliance_repository.dart';
import '../../../routine_compliance/domain/services/routine_overview_service.dart';
import '../models/comparison_period.dart';
import '../models/period_comparison_result.dart';

class PeriodComparisonService {
  const PeriodComparisonService({
    required DurationRepository durationRepository,
    required RoutineComplianceRepository routineComplianceRepository,
  }) : this._(durationRepository, routineComplianceRepository);

  const PeriodComparisonService._(
    this._durationRepository,
    this._routineComplianceRepository,
  );

  final DurationRepository _durationRepository;
  final RoutineComplianceRepository _routineComplianceRepository;

  Future<PeriodComparisonResult> compare({
    required String anonymousId,
    required ComparisonPeriod periodA,
    required ComparisonPeriod periodB,
  }) async {
    // Ambas consultas se validan antes de acceder
    // a cualquier repositorio.
    final queryA = RoutineComplianceQuery.create(
      anonymousId: anonymousId,
      startDate: periodA.startDate,
      endDate: periodA.endDate,
    );

    final queryB = RoutineComplianceQuery.create(
      anonymousId: anonymousId,
      startDate: periodB.startDate,
      endDate: periodB.endDate,
    );

    final normalizedId = queryA.anonymousId;

    if (queryB.anonymousId != normalizedId) {
      throw StateError('Los periodos no pertenecen al mismo seguimiento.');
    }

    final durationService = DurationOverviewService(_durationRepository);

    final routineService = RoutineOverviewService(_routineComplianceRepository);

    // Se reutilizan los servicios existentes.
    // No se introducen formulas de calculo nuevas.
    //
    // Las cuatro recuperaciones pueden comenzar
    // concurrentemente, sin mezclar sus resultados.
    final results = await Future.wait<Object>([
      durationService.load(
        anonymousId: normalizedId,
        startDate: queryA.startDate,
        endDate: queryA.endDate,
      ),
      durationService.load(
        anonymousId: normalizedId,
        startDate: queryB.startDate,
        endDate: queryB.endDate,
      ),
      routineService.load(
        anonymousId: normalizedId,
        startDate: queryA.startDate,
        endDate: queryA.endDate,
      ),
      routineService.load(
        anonymousId: normalizedId,
        startDate: queryB.startDate,
        endDate: queryB.endDate,
      ),
    ]);

    final durationA = results[0] as DurationOverview;
    final durationB = results[1] as DurationOverview;

    final routineA = results[2] as RoutineOverview;
    final routineB = results[3] as RoutineOverview;

    // Defensa adicional para evitar resultados
    // asociados con otro identificador anonimo.
    if (durationA.anonymousId != normalizedId ||
        durationB.anonymousId != normalizedId ||
        routineA.anonymousId != normalizedId ||
        routineB.anonymousId != normalizedId) {
      throw StateError('No fue posible validar el seguimiento actual.');
    }

    return PeriodComparisonResult(
      anonymousId: normalizedId,
      periodA: PeriodComparisonSnapshot(
        period: periodA,
        durations: durationA,
        routines: routineA,
      ),
      periodB: PeriodComparisonSnapshot(
        period: periodB,
        durations: durationB,
        routines: routineB,
      ),
    );
  }
}
