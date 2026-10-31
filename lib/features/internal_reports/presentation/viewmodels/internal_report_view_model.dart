import 'package:flutter/foundation.dart';

import '../../../duration/domain/exceptions/duration_failure.dart';
import '../../../duration/domain/exceptions/duration_query_validation_failure.dart';
import '../../../period_comparison/domain/models/comparison_period.dart';
import '../../../routine_compliance/domain/exceptions/routine_compliance_failure.dart';
import '../../../routine_compliance/domain/exceptions/routine_compliance_query_validation_failure.dart';
import '../../domain/models/internal_report.dart';
import '../../domain/services/internal_report_service.dart';

class InternalReportViewModel extends ChangeNotifier {
  InternalReportViewModel(
    this._service, {
    required String anonymousId,
    DateTime Function()? clock,
  }) : anonymousId = anonymousId.trim() {
    final today = _dateOnly((clock ?? DateTime.now)());

    // Periodo inicial: ultimos 30 dias naturales,
    // incluyendo la fecha actual.
    _period = ComparisonPeriod(
      startDate: today.subtract(const Duration(days: 29)),
      endDate: today,
    );
  }

  final InternalReportService _service;

  // El seguimiento se vincula a esta instancia.
  // La View debe recrearla al cambiar de seguimiento.
  final String anonymousId;

  late ComparisonPeriod _period;

  InternalReport? _report;
  String? _errorMessage;

  bool _isLoading = false;
  bool _disposed = false;

  int _requestVersion = 0;

  ComparisonPeriod get period => _period;

  InternalReport? get report => _report;

  String? get errorMessage => _errorMessage;

  bool get isLoading => _isLoading;

  bool get isDisposed => _disposed;

  bool get hasReport => _report != null;

  bool get hasAnyInformation => _report?.hasAnyInformation ?? false;

  // Sustituye el intervalo completo en una sola operacion.
  void setPeriod(ComparisonPeriod period) {
    if (_disposed || _samePeriod(_period, period)) {
      return;
    }

    _period = period;
    _invalidateReport();
  }

  // Si un extremo produce un intervalo invertido,
  // el otro extremo se ajusta automaticamente.
  void setDate({required bool isStartDate, required DateTime date}) {
    if (_disposed) {
      return;
    }

    final selected = _dateOnly(date);

    late final DateTime startDate;
    late final DateTime endDate;

    if (isStartDate) {
      startDate = selected;
      endDate = _period.endDate.isBefore(selected) ? selected : _period.endDate;
    } else {
      endDate = selected;
      startDate = _period.startDate.isAfter(selected)
          ? selected
          : _period.startDate;
    }

    setPeriod(ComparisonPeriod(startDate: startDate, endDate: endDate));
  }

  // Solo se consulta cuando la interfaz solicita
  // generar un reporte, no al cambiar fechas.
  Future<void> load() async {
    if (_disposed) {
      return;
    }

    final request = ++_requestVersion;
    final expectedId = anonymousId;
    final requestedPeriod = _period;

    _isLoading = true;
    _report = null;
    _errorMessage = null;

    notifyListeners();

    try {
      final result = await _service.generate(
        anonymousId: expectedId,
        period: requestedPeriod,
      );

      if (!_isRequestCurrent(request)) {
        return;
      }

      // Impide presentar reportes vinculados con otro
      // seguimiento o con fechas de una consulta anterior.
      if (result.anonymousId != expectedId ||
          !_samePeriod(result.period, requestedPeriod)) {
        _showError(
          request,
          'No fue posible validar el reporte del '
          'seguimiento actual.',
        );
        return;
      }

      _report = result;
      _errorMessage = null;
      _isLoading = false;

      notifyListeners();
    } on DurationQueryValidationFailure catch (failure) {
      _showError(
        request,
        failure.errorFor('period') ??
            failure.errorFor('anonymousId') ??
            failure.message,
      );
    } on RoutineComplianceQueryValidationFailure catch (failure) {
      _showError(
        request,
        failure.errorFor('period') ??
            failure.errorFor('anonymousId') ??
            failure.message,
      );
    } on DurationFailure catch (failure) {
      _showError(request, failure.message);
    } on RoutineComplianceFailure catch (failure) {
      _showError(request, failure.message);
    } catch (_) {
      _showError(
        request,
        'No fue posible generar el reporte interno. '
        'Comprueba tu conexión e inténtalo nuevamente.',
      );
    }
  }

  // Cualquier cambio de fechas cancela logicamente
  // las consultas anteriores y elimina su resultado.
  void _invalidateReport() {
    _requestVersion++;

    _isLoading = false;
    _report = null;
    _errorMessage = null;

    notifyListeners();
  }

  void _showError(int request, String message) {
    if (!_isRequestCurrent(request)) {
      return;
    }

    _isLoading = false;
    _report = null;
    _errorMessage = message;

    notifyListeners();
  }

  bool _isRequestCurrent(int request) {
    return !_disposed && request == _requestVersion;
  }

  static bool _samePeriod(ComparisonPeriod first, ComparisonPeriod second) {
    return first.startDate.isAtSameMomentAs(second.startDate) &&
        first.endDate.isAtSameMomentAs(second.endDate);
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _requestVersion++;

    _isLoading = false;
    _report = null;
    _errorMessage = null;

    super.dispose();
  }
}
