import 'package:flutter/foundation.dart';

import 'biometric_enrollment_coordinator.dart';
import 'biometric_settings_binding_reader.dart';

/// Coordina la activación biométrica y la lectura de su estado.
///
/// No concede acceso privado, no modifica Firebase y
/// no interpreta un resultado nativo como autorización.
///
/// El componente raíz debe usar [onOperationFinished]
/// para reevaluar la seguridad después del enrolamiento.
final class BiometricEnrollmentController extends ChangeNotifier {
  BiometricEnrollmentController({
    required BiometricEnrollmentCoordinator coordinator,
    required void Function(BiometricEnrollmentResult result)
    onOperationFinished,
    BiometricSettingsBindingReader? bindingReader,
  }) : this._(coordinator, onOperationFinished, bindingReader);

  BiometricEnrollmentController._(
    this._coordinator,
    this._onOperationFinished,
    this._bindingReader,
  );

  final BiometricEnrollmentCoordinator _coordinator;

  final void Function(BiometricEnrollmentResult result) _onOperationFinished;

  final BiometricSettingsBindingReader? _bindingReader;

  Future<BiometricEnrollmentResult>? _inFlight;

  BiometricSettingsBindingStatus? _bindingStatus;
  BiometricEnrollmentResult? _lastResult;

  int _bindingReadRevision = 0;

  bool _isBusy = false;
  bool _isReadingBinding = false;
  bool _disposed = false;

  bool get isBusy => _isBusy;

  bool get isReadingBinding => _isReadingBinding;

  BiometricEnrollmentResult? get lastResult => _lastResult;

  /// null indica que el estado todavía no se confirmó.
  BiometricSettingsBindingStatus? get bindingStatus => _bindingStatus;

  /// La interfaz solo puede ofrecer el alta si se confirmó
  /// expresamente la ausencia de una vinculación.
  bool get canConfigureBiometrics =>
      !_disposed &&
      !_isBusy &&
      !_isReadingBinding &&
      _bindingStatus == BiometricSettingsBindingStatus.disabled;

  /// Vuelve a consultar Android sin conceder acceso privado.
  ///
  /// Una respuesta antigua nunca sobrescribe una consulta
  /// posterior ni un enrolamiento que ya haya comenzado.
  Future<BiometricSettingsBindingStatus> refreshBindingStatus() async {
    if (_disposed) {
      return BiometricSettingsBindingStatus.unavailable;
    }

    if (_isBusy) {
      return BiometricSettingsBindingStatus.unavailable;
    }

    final revision = ++_bindingReadRevision;
    final reader = _bindingReader;

    _bindingStatus = null;
    _isReadingBinding = true;

    notifyListeners();

    BiometricSettingsBindingStatus result;

    if (reader == null) {
      result = BiometricSettingsBindingStatus.unavailable;
    } else {
      try {
        result = await reader.read();
      } catch (_) {
        result = BiometricSettingsBindingStatus.unavailable;
      }
    }

    if (_disposed || revision != _bindingReadRevision || _isBusy) {
      return result;
    }

    _bindingStatus = result;
    _isReadingBinding = false;

    notifyListeners();

    return result;
  }

  /// Ejecuta una activación explícitamente solicitada.
  ///
  /// Las llamadas simultáneas comparten la operación.
  ///
  /// Cuando existe un lector configurado, se exige que
  /// haya confirmado previamente el estado desactivado.
  Future<BiometricEnrollmentResult> activate() {
    if (_disposed) {
      return Future<BiometricEnrollmentResult>.value(
        BiometricEnrollmentResult.unavailable,
      );
    }

    final current = _inFlight;

    if (current != null) {
      return current;
    }

    if (_bindingReader != null && !canConfigureBiometrics) {
      return Future<BiometricEnrollmentResult>.value(
        BiometricEnrollmentResult.unavailable,
      );
    }

    final operation = _performActivation();

    _inFlight = operation;

    return operation;
  }

  Future<BiometricEnrollmentResult> _performActivation() async {
    // Invalida cualquier consulta anterior antes de abrir
    // el desafío de Android.
    _bindingReadRevision++;
    _bindingStatus = null;
    _isReadingBinding = false;

    _isBusy = true;
    _lastResult = null;

    notifyListeners();

    BiometricEnrollmentResult result;

    try {
      result = await _coordinator.enroll();
    } catch (_) {
      result = BiometricEnrollmentResult.unavailable;
    }

    if (_disposed) {
      return result;
    }

    _isBusy = false;
    _lastResult = result;

    try {
      // El componente raíz debe revocar y reevaluar
      // incluso cuando la operación se haya cancelado.
      _onOperationFinished(result);
    } finally {
      _inFlight = null;

      if (!_disposed) {
        notifyListeners();
      }
    }

    return result;
  }

  @override
  void dispose() {
    _disposed = true;
    _bindingReadRevision++;

    _inFlight = null;

    super.dispose();
  }
}
