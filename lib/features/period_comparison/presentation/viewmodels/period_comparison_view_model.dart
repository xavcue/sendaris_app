import 'package:flutter/foundation.dart';

import '../../../duration/domain/exceptions/duration_failure.dart';
import '../../../duration/domain/exceptions/duration_query_validation_failure.dart';
import '../../../routine_compliance/domain/exceptions/routine_compliance_failure.dart';
import '../../../routine_compliance/domain/exceptions/routine_compliance_query_validation_failure.dart';
import '../../domain/models/comparison_period.dart';
import '../../domain/models/period_comparison_result.dart';
import '../../domain/services/period_comparison_service.dart';

enum ComparisonPeriodSlot { a, b }

class PeriodComparisonViewModel extends ChangeNotifier {
  PeriodComparisonViewModel(
    this._service, {
    required String anonymousId,
    DateTime Function()? clock,
  }) : anonymousId = anonymousId.trim() {
    final today = _dateOnly((clock ?? DateTime.now)());

    // A: los siete dias anteriores al periodo B.
    _periodA = ComparisonPeriod(
      startDate: today.subtract(const Duration(days: 13)),
      endDate: today.subtract(const Duration(days: 7)),
    );

    // B: los ultimos siete dias, incluido hoy.
    _periodB = ComparisonPeriod(
      startDate: today.subtract(const Duration(days: 6)),
      endDate: today,
    );
  }

  final PeriodComparisonService _service;

  // La identidad pertenece a esta instancia del ViewModel.
  // Al cambiar de seguimiento, la View creara otra instancia.
  final String anonymousId;

  late ComparisonPeriod _periodA;
  late ComparisonPeriod _periodB;

  PeriodComparisonResult? _result;
  String? _errorMessage;

  bool _isLoading = false;
  bool _disposed = false;

  int _requestVersion = 0;

  ComparisonPeriod get periodA => _periodA;
  ComparisonPeriod get periodB => _periodB;

  PeriodComparisonResult? get result => _result;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _isLoading;
  bool get isDisposed => _disposed;

  bool get hasComparison => _result != null;
  bool get hasData => _result?.hasAnyData ?? false;

  ComparisonPeriod periodFor(ComparisonPeriodSlot slot) {
    return switch (slot) {
      ComparisonPeriodSlot.a => _periodA,
      ComparisonPeriodSlot.b => _periodB,
    };
  }

  // Permite sustituir un intervalo completo en una sola operacion.
  void setPeriod({
    required ComparisonPeriodSlot slot,
    required ComparisonPeriod period,
  }) {
    if (_disposed) {
      return;
    }

    final current = periodFor(slot);

    if (_samePeriod(current, period)) {
      return;
    }

    switch (slot) {
      case ComparisonPeriodSlot.a:
        _periodA = period;

      case ComparisonPeriodSlot.b:
        _periodB = period;
    }

    _invalidateComparison();
  }

  // Ajusta el otro extremo cuando la fecha seleccionada
  // produciria un intervalo invertido.
  void setDate({
    required ComparisonPeriodSlot slot,
    required bool isStartDate,
    required DateTime date,
  }) {
    if (_disposed) {
      return;
    }

    final current = periodFor(slot);
    final selected = _dateOnly(date);

    late final DateTime startDate;
    late final DateTime endDate;

    if (isStartDate) {
      startDate = selected;
      endDate = current.endDate.isBefore(selected) ? selected : current.endDate;
    } else {
      endDate = selected;
      startDate = current.startDate.isAfter(selected)
          ? selected
          : current.startDate;
    }

    setPeriod(
      slot: slot,
      period: ComparisonPeriod(startDate: startDate, endDate: endDate),
    );
  }

  // No se consulta automaticamente en cada cambio de fecha.
  // La View invocara load() al ejecutar "Comparar".
  Future<void> load() async {
    if (_disposed) {
      return;
    }

    final request = ++_requestVersion;
    final expectedId = anonymousId;
    final requestedA = _periodA;
    final requestedB = _periodB;

    _isLoading = true;
    _result = null;
    _errorMessage = null;

    notifyListeners();

    try {
      final comparison = await _service.compare(
        anonymousId: expectedId,
        periodA: requestedA,
        periodB: requestedB,
      );

      if (!_isRequestCurrent(request)) {
        return;
      }

      // Verifica identidad y periodos antes de publicar
      // los resultados a la interfaz.
      if (comparison.anonymousId != expectedId ||
          !_samePeriod(comparison.periodA.period, requestedA) ||
          !_samePeriod(comparison.periodB.period, requestedB)) {
        _showError(
          request,
          'No fue posible validar los resultados del seguimiento actual.',
        );
        return;
      }

      _result = comparison;
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
        'No fue posible comparar los periodos. '
        'Comprueba tu conexión e inténtalo nuevamente.',
      );
    }
  }

  // Cambiar las fechas cancela logicamente cualquier
  // recuperacion anterior y descarta sus resultados.
  void _invalidateComparison() {
    _requestVersion++;
    _isLoading = false;
    _result = null;
    _errorMessage = null;

    notifyListeners();
  }

  void _showError(int request, String message) {
    if (!_isRequestCurrent(request)) {
      return;
    }

    _isLoading = false;
    _result = null;
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

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;
    _requestVersion++;
    _isLoading = false;
    _result = null;
    _errorMessage = null;

    super.dispose();
  }
}
